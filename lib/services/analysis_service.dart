import 'package:chess/chess.dart' as chess;
import '../models/move_analysis.dart';
import '../models/move_labeling.dart';
import '../services/engine_service.dart';

class AnalysisService {
  final EngineService _engineService;

  AnalysisService(this._engineService);

  String _fmt(double v) => v.toStringAsFixed(1);

  bool _sideToMoveIsWhite(String fen) {
    final fenParts = fen.split(' ');
    return fenParts.length > 1 ? fenParts[1] == 'w' : true;
  }

  /// Analyze and classify a single played move from a given starting FEN.
  ///
  /// This is the same logic used in [analyzeGame], but scoped to one move so
  /// it can be applied to side lines and arbitrary positions.
  Future<MoveAnalysis?> analyzeSingleMove({
    required String fenBefore,
    required String playedSan,
    required int moveNumber,
    required Duration timePerMove,
    MoveLabelHarshness harshness = MoveLabelHarshness.normal,
    void Function(String message)? debugLog,
  }) async {
    void log(String message) => debugLog?.call('[analyzeSingleMove] $message');

    final game = chess.Chess.fromFEN(fenBefore);
    final playerIsWhite = _sideToMoveIsWhite(fenBefore);

    final legalMovesCount = game.moves().length;

    log(
      'start moveNumber=$moveNumber playedSan="$playedSan" timePerMoveMs=${timePerMove.inMilliseconds} playerIsWhite=$playerIsWhite legalMoves=$legalMovesCount',
    );
    log('fenBefore="$fenBefore"');

    // 1) Analyze the current position (MultiPV=2) so we can tag Only-move.
    final beforePvs = await _engineService.analyzeMultiPvPosition(
      fenBefore,
      timePerMove,
      multiPv: 2,
    );
    if (beforePvs == null || beforePvs.isEmpty) {
      log('beforePvs empty -> return null');
      return null;
    }

    final bestUci = (beforePvs[0]['uci'] as String?) ?? '';
    final secondUci = beforePvs.length > 1
        ? (beforePvs[1]['uci'] as String?)
        : null;
    final evalBeforeForPlayer = _evalFromEngineResult(
      beforePvs[0],
      playerIsWhite: playerIsWhite,
      sideToMoveIsWhite: _sideToMoveIsWhite(fenBefore),
    );

    log(
      'before: evalBeforeForPlayer=${_fmt(evalBeforeForPlayer)} hasBestMove=${bestUci.isNotEmpty} hasSecondLine=${(secondUci ?? '').isNotEmpty}',
    );

    final tags = <MoveTag>[];
    if (legalMovesCount == 1) {
      tags.add(MoveTag.forced);
      log('tag forced (only legal move)');
    }
    if (legalMovesCount > 1 && secondUci != null && secondUci.isNotEmpty) {
      final bestEval = _evalFromEngineResult(
        beforePvs[0],
        playerIsWhite: playerIsWhite,
        sideToMoveIsWhite: _sideToMoveIsWhite(fenBefore),
      );
      final secondEval = _evalFromEngineResult(
        beforePvs[1],
        playerIsWhite: playerIsWhite,
        sideToMoveIsWhite: _sideToMoveIsWhite(fenBefore),
      );
      final gap = bestEval - secondEval;
      final bestIsMateWin = bestEval >= 9500;
      final secondIsNotMateWin = secondEval < 9000;
      log(
        'onlyMove check: bestEval=${_fmt(bestEval)} secondEval=${_fmt(secondEval)} gap=${_fmt(gap)} bestIsMateWin=$bestIsMateWin secondIsNotMateWin=$secondIsNotMateWin',
      );
      if (gap >= 150 || (bestIsMateWin && secondIsNotMateWin)) {
        tags.add(MoveTag.onlyMove);
        log('tag onlyMove');
      }
    }

    // 2) Play the user's move (SAN) and evaluate the resulting position
    final playedOk = game.move(playedSan);
    if (playedOk == false) {
      log('SAN rejected by chess.dart -> return null');
      return null;
    }

    // chess.dart move() returns bool; use undo() to retrieve move details and UCI.
    final dynamic undoData = game.undo();
    String? playedUci;
    if (undoData is Map) {
      playedUci = _uciFromUndo(undoData);
      final replayOk = _replayFromUndo(game, undoData);
      if (!replayOk) {
        log('undo replay failed (from/to/promotion missing?) -> return null');
        return null;
      }
    } else {
      // If undo didn't yield details, re-apply SAN to keep state.
      game.move(playedSan);
    }

    final isBestMove = playedUci != null && playedUci == bestUci;
    log('played: isBestMove=$isBestMove');

    // 3) Evaluate the resulting position after the played move.
    final fenAfterPlayed = game.fen;
    log('fenAfterPlayed="$fenAfterPlayed"');
    final afterPlayed = await _engineService.analyzePosition(
      fenAfterPlayed,
      timePerMove,
    );
    final evalAfterPlayedForPlayer = afterPlayed == null
        ? evalBeforeForPlayer
        : _evalFromEngineResult(
            afterPlayed,
            playerIsWhite: playerIsWhite,
            sideToMoveIsWhite: _sideToMoveIsWhite(fenAfterPlayed),
          );

    log('afterPlayed evalForPlayer=${_fmt(evalAfterPlayedForPlayer)}');

    // 4) Evaluate the position after the engine best move.
    double evalAfterBestForPlayer = evalBeforeForPlayer;
    if (bestUci.isNotEmpty) {
      if (playedUci != null && playedUci == bestUci && afterPlayed != null) {
        evalAfterBestForPlayer = evalAfterPlayedForPlayer;
      } else {
        final bestGame = chess.Chess.fromFEN(fenBefore);
        final applied = _applyUciMove(bestGame, bestUci);
        if (applied) {
          final afterBest = await _engineService.analyzePosition(
            bestGame.fen,
            timePerMove,
          );
          if (afterBest != null) {
            evalAfterBestForPlayer = _evalFromEngineResult(
              afterBest,
              playerIsWhite: playerIsWhite,
              sideToMoveIsWhite: _sideToMoveIsWhite(bestGame.fen),
            );
          }
        }
      }
    }

    log('afterBest evalForPlayer=${_fmt(evalAfterBestForPlayer)}');

    // 5) Centipawn loss: how much worse the played move is vs best move.
    final centipawnLoss = (evalAfterBestForPlayer - evalAfterPlayedForPlayer)
        .clamp(0.0, double.infinity);

    log('centipawnLoss=${_fmt(centipawnLoss)} (max(0, afterBest-afterPlayed))');

    final thresholds =
        MoveLabelingThresholds.byHarshness[harshness] ??
        MoveLabelingThresholds.normal;

    var classification = _classifyLikeChessCom(
      centipawnLoss: centipawnLoss,
      playerEvalBefore: evalBeforeForPlayer,
      playerEvalAfter: evalAfterPlayedForPlayer,
      playerEvalAfterBest: evalAfterBestForPlayer,
      isBestMove: playedUci != null && playedUci == bestUci,
      thresholds: thresholds,
      debugLog: (m) => log('classify: $m'),
    );

    log('classification initial=$classification');

    // Miss: best line was strong but we failed to find it.
    if (!isBestMove) {
      final bestWasStrong =
          evalAfterBestForPlayer >= 200 || evalAfterBestForPlayer >= 9500;
      final weDidntGetCrushed = evalAfterPlayedForPlayer > -800;
      log(
        'miss check: bestWasStrong=$bestWasStrong weDidntGetCrushed=$weDidntGetCrushed centipawnLoss>=200=${centipawnLoss >= 200}',
      );
      if (bestWasStrong && centipawnLoss >= 200 && weDidntGetCrushed) {
        classification = MoveClassification.miss;
        log('classification override -> miss');
      }
    }

    log('final classification=$classification tags=$tags');

    return MoveAnalysis(
      moveNumber: moveNumber,
      move: playedSan,
      fen: fenBefore,
      evalBefore: evalBeforeForPlayer,
      evalAfter: evalAfterPlayedForPlayer,
      centipawnLoss: centipawnLoss,
      bestMove: bestUci,
      classification: classification,
      tags: tags,
    );
  }

  Future<GameAnalysis> analyzeGame({
    required List<String> moves,
    required String startingFen,
    required Function(int current, int total) onProgress,
    Duration timePerMove = const Duration(milliseconds: 500),
    MoveLabelHarshness harshness = MoveLabelHarshness.normal,
  }) async {
    final game = chess.Chess();
    if (startingFen.isNotEmpty && startingFen != chess.Chess.DEFAULT_POSITION) {
      game.load(startingFen);
    }

    final moveAnalyses = <MoveAnalysis>[];

    for (var i = 0; i < moves.length; i++) {
      print(
        '[AnalysisService] Analyzing move ${i + 1}/${moves.length}: ${moves[i]}',
      );
      onProgress(i + 1, moves.length);

      final fenBefore = game.fen;
      final playedSan = moves[i];
      final playerIsWhite = _sideToMoveIsWhite(fenBefore);

      final legalMovesCount = game.moves().length;

      // 1) Analyze the current position (MultiPV=2) so we can tag Only-move.
      final beforePvs = await _engineService.analyzeMultiPvPosition(
        fenBefore,
        timePerMove,
        multiPv: 2,
      );
      if (beforePvs == null || beforePvs.isEmpty) {
        // Still advance the game if possible
        game.move(playedSan);
        continue;
      }

      final bestUci = (beforePvs[0]['uci'] as String?) ?? '';
      final secondUci = beforePvs.length > 1
          ? (beforePvs[1]['uci'] as String?)
          : null;
      final evalBeforeForPlayer = _evalFromEngineResult(
        beforePvs[0],
        playerIsWhite: playerIsWhite,
        sideToMoveIsWhite: _sideToMoveIsWhite(fenBefore),
      );

      final tags = <MoveTag>[];
      if (legalMovesCount == 1) {
        tags.add(MoveTag.forced);
      }
      if (legalMovesCount > 1 && secondUci != null && secondUci.isNotEmpty) {
        final bestEval = _evalFromEngineResult(
          beforePvs[0],
          playerIsWhite: playerIsWhite,
          sideToMoveIsWhite: _sideToMoveIsWhite(fenBefore),
        );
        final secondEval = _evalFromEngineResult(
          beforePvs[1],
          playerIsWhite: playerIsWhite,
          sideToMoveIsWhite: _sideToMoveIsWhite(fenBefore),
        );
        final gap = bestEval - secondEval;
        final bestIsMateWin = bestEval >= 9500;
        final secondIsNotMateWin = secondEval < 9000;
        if (gap >= 150 || (bestIsMateWin && secondIsNotMateWin)) {
          tags.add(MoveTag.onlyMove);
        }
      }

      // 2) Play the user's move (SAN) and evaluate the resulting position
      final playedOk = game.move(playedSan);
      if (playedOk == false) {
        continue;
      }

      // chess.dart move() returns bool; use undo() to retrieve move details and UCI.
      final dynamic undoData = game.undo();
      String? playedUci;
      if (undoData is Map) {
        playedUci = _uciFromUndo(undoData);
        final replayOk = _replayFromUndo(game, undoData);
        if (!replayOk) {
          // Fallback: re-apply the SAN move to keep game state consistent
          final sanReapply = game.move(playedSan);
          if (sanReapply == false) {
            print(
              '[AnalysisService] Move ${i + 1} SAN re-apply also failed - skipping',
            );
            continue;
          }
        }
      } else {
        // If undo didn't yield details, re-apply SAN to keep state.
        final sanApply = game.move(playedSan);
        if (sanApply == false) {
          continue;
        }
      }

      final fenAfterPlayed = game.fen;
      final afterPlayed = await _engineService.analyzePosition(
        fenAfterPlayed,
        timePerMove,
      );
      final evalAfterPlayedForPlayer = afterPlayed == null
          ? evalBeforeForPlayer
          : _evalFromEngineResult(
              afterPlayed,
              playerIsWhite: playerIsWhite,
              sideToMoveIsWhite: _sideToMoveIsWhite(fenAfterPlayed),
            );

      // Evaluate the position after the engine best move.
      // This is what chess.com-style analysis compares against.
      double evalAfterBestForPlayer = evalBeforeForPlayer;
      if (bestUci.isNotEmpty) {
        if (playedUci != null && playedUci == bestUci && afterPlayed != null) {
          // If the played move is the engine best move, reuse the eval.
          evalAfterBestForPlayer = evalAfterPlayedForPlayer;
        } else {
          final bestGame = chess.Chess.fromFEN(fenBefore);
          final applied = _applyUciMove(bestGame, bestUci);
          if (applied) {
            final fenAfterBest = bestGame.fen;
            final afterBest = await _engineService.analyzePosition(
              fenAfterBest,
              timePerMove,
            );
            if (afterBest != null) {
              evalAfterBestForPlayer = _evalFromEngineResult(
                afterBest,
                playerIsWhite: playerIsWhite,
                sideToMoveIsWhite: _sideToMoveIsWhite(fenAfterBest),
              );
            }
          }
        }
      }

      // Centipawn loss: how much worse the played move is vs best move.
      final centipawnLoss = (evalAfterBestForPlayer - evalAfterPlayedForPlayer)
          .clamp(0.0, double.infinity);

      // Debug-only: print black centipawn deltas in a readable format.
      if ((i + 1) % 2 == 0) {
        final moveNo = (i ~/ 2) + 1;
        // Values are player-perspective (here: black). Positive = good for black.
        print(
          '[BLACK m$moveNo] best=${evalAfterBestForPlayer.toStringAsFixed(1)} '
          'played=${evalAfterPlayedForPlayer.toStringAsFixed(1)} '
          'loss=${centipawnLoss.toStringAsFixed(1)} '
          'fen=$fenBefore',
        );
      }

      final thresholds =
          MoveLabelingThresholds.byHarshness[harshness] ??
          MoveLabelingThresholds.normal;
      var classification = _classifyLikeChessCom(
        centipawnLoss: centipawnLoss,
        playerEvalBefore: evalBeforeForPlayer,
        playerEvalAfter: evalAfterPlayedForPlayer,
        playerEvalAfterBest: evalAfterBestForPlayer,
        isBestMove: playedUci != null && playedUci == bestUci,
        thresholds: thresholds,
      );

      // Human-like overrides (primary label), tags remain secondary.
      final isBestMove = playedUci != null && playedUci == bestUci;

      // Miss: best line was strong but we failed to find it.
      // Keep it distinct from pure blunders (tunable).
      if (!isBestMove) {
        final bestWasStrong =
            evalAfterBestForPlayer >= 200 || evalAfterBestForPlayer >= 9500;
        final weDidntGetCrushed = evalAfterPlayedForPlayer > -800;
        if (bestWasStrong && centipawnLoss >= 200 && weDidntGetCrushed) {
          classification = MoveClassification.miss;
        }
      }

      moveAnalyses.add(
        MoveAnalysis(
          moveNumber: i + 1,
          move: playedSan,
          fen: fenBefore,
          evalBefore: evalBeforeForPlayer,
          evalAfter: evalAfterPlayedForPlayer,
          centipawnLoss: centipawnLoss,
          bestMove: bestUci,
          classification: classification,
          tags: tags,
        ),
      );
    }

    print(
      '[AnalysisService] Analysis complete: ${moveAnalyses.length} moves analyzed',
    );
    return GameAnalysis.fromMoves(moveAnalyses);
  }

  double _evalFromEngineResult(
    Map<String, dynamic> result, {
    required bool playerIsWhite,
    required bool sideToMoveIsWhite,
  }) {
    // Stockfish `score cp/mate` is from the SIDE-TO-MOVE perspective.
    // Convert it to a White-perspective score, then to the player's perspective.
    double scoreFromSideToMove;
    if (result.containsKey('mate')) {
      final mateIn = result['mate'] as int;
      scoreFromSideToMove = mateIn > 0 ? 10000.0 : -10000.0;
    } else if (result.containsKey('cp')) {
      scoreFromSideToMove = (result['cp'] as int).toDouble();
    } else {
      return 0.0;
    }

    final whitePerspective = sideToMoveIsWhite
        ? scoreFromSideToMove
        : -scoreFromSideToMove;
    return playerIsWhite ? whitePerspective : -whitePerspective;
  }

  MoveClassification _classifyLikeChessCom({
    required double centipawnLoss,
    required double playerEvalBefore,
    required double playerEvalAfter,
    required double playerEvalAfterBest,
    required bool isBestMove,
    required MoveLabelingThresholds thresholds,
    void Function(String message)? debugLog,
  }) {
    // Mate situations: treat missing mates / allowing mates as severe.
    if (playerEvalAfterBest >= 9500 && playerEvalAfter < 9000) {
      // Best line mates / wins decisively and we didn't.
      debugLog?.call(
        'mate-missed: playerEvalAfterBest=${_fmt(playerEvalAfterBest)} playerEvalAfter=${_fmt(playerEvalAfter)} -> blunder',
      );
      return MoveClassification.blunder;
    }
    if (playerEvalAfter <= -9500) {
      // We are getting mated (or lost completely).
      debugLog?.call(
        'mate-against: playerEvalAfter=${_fmt(playerEvalAfter)} -> blunder',
      );
      return MoveClassification.blunder;
    }

    // If it's the best move (exact UCI match), label it best.
    if (isBestMove) return MoveClassification.best;

    // Mild scaling: slightly more forgiving in clearly winning/losing positions,
    // but keep it close to raw cp-loss thresholds.
    final alreadyDecided =
        playerEvalAfterBest.abs() >= thresholds.decidedAbsEvalThreshold;
    final scale = alreadyDecided ? thresholds.decidedScale : 1.0;

    debugLog?.call(
      'thresholds: alreadyDecided=$alreadyDecided scale=$scale loss=${_fmt(centipawnLoss)} '
      '(great<${_fmt(thresholds.greatMax * scale)}, exc<${_fmt(thresholds.excellentMax * scale)}, '
      'good<${_fmt(thresholds.goodMax * scale)}, inacc<${_fmt(thresholds.inaccuracyMax * scale)}, '
      'mistake<${_fmt(thresholds.mistakeMax * scale)}, blunder>=${_fmt(thresholds.mistakeMax * scale)})',
    );

    final loss = centipawnLoss;
    // Near-best (but not exact best) gets its own label.
    // Target ranges (approx):
    // Great: 0–10, Excellent: 10–30, Good: 30–80,
    // Inaccuracy: 80–200, Mistake: 200–500, Blunder: 500+
    if (loss < thresholds.greatMax * scale) return MoveClassification.great;
    if (loss < thresholds.excellentMax * scale) {
      return MoveClassification.excellent;
    }
    if (loss < thresholds.goodMax * scale) return MoveClassification.good;
    if (loss < thresholds.inaccuracyMax * scale) {
      return MoveClassification.inaccuracy;
    }
    if (loss < thresholds.mistakeMax * scale) return MoveClassification.mistake;
    return MoveClassification.blunder;
  }

  bool _applyUciMove(chess.Chess game, String uci) {
    if (uci.length < 4) return false;
    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length >= 5 ? uci[4].toLowerCase() : null;
    final move = <String, dynamic>{'from': from, 'to': to};
    if (promotion != null) {
      move['promotion'] = promotion;
    }
    final result = game.move(move);
    return result != false;
  }

  bool _replayFromUndo(chess.Chess game, Map undoData) {
    final from = undoData['from'];
    final to = undoData['to'];
    if (from is! String || to is! String) {
      return false;
    }

    final move = <String, dynamic>{'from': from, 'to': to};
    final promotion = undoData['promotion'];
    if (promotion != null) {
      // Handle promotion - could be String, int, or PieceType enum
      String? promoPiece;
      if (promotion is String && promotion.isNotEmpty) {
        promoPiece = promotion.toLowerCase();
      } else {
        // Try to convert to string and extract piece letter
        final promoStr = promotion.toString().toLowerCase();
        if (promoStr.contains('queen') || promoStr.contains('q')) {
          promoPiece = 'q';
        } else if (promoStr.contains('rook') || promoStr.contains('r')) {
          promoPiece = 'r';
        } else if (promoStr.contains('bishop') || promoStr.contains('b')) {
          promoPiece = 'b';
        } else if (promoStr.contains('knight') || promoStr.contains('n')) {
          promoPiece = 'n';
        } else {
          promoPiece = 'q'; // Default to queen
        }
      }
      if (promoPiece != null) {
        move['promotion'] = promoPiece;
      }
    }

    print('[_replayFromUndo] Attempting move: $move');
    final result = game.move(move);
    final success = result != false;
    if (!success) {
      print('[_replayFromUndo] Move FAILED with result: $result');
      print('[_replayFromUndo] Current FEN: ${game.fen}');
    } else {
      print(
        '[_replayFromUndo] Move result: success=$success, new FEN: ${game.fen}',
      );
    }
    return success;
  }

  String? _uciFromUndo(Map undoData) {
    final from = undoData['from'];
    final to = undoData['to'];
    if (from is! String || to is! String) return null;
    final promotion = undoData['promotion'];
    if (promotion != null) {
      String? promoPiece;
      if (promotion is String && promotion.isNotEmpty) {
        promoPiece = promotion.toLowerCase();
      } else {
        // Try to extract piece from toString
        final promoStr = promotion.toString().toLowerCase();
        if (promoStr.contains('queen') || promoStr.contains('q')) {
          promoPiece = 'q';
        } else if (promoStr.contains('rook') || promoStr.contains('r')) {
          promoPiece = 'r';
        } else if (promoStr.contains('bishop') || promoStr.contains('b')) {
          promoPiece = 'b';
        } else if (promoStr.contains('knight') || promoStr.contains('n')) {
          promoPiece = 'n';
        } else {
          promoPiece = 'q';
        }
      }
      if (promoPiece != null) {
        return '$from$to$promoPiece';
      }
    }
    return '$from$to';
  }

  void dispose() {
    // Cleanup if needed
  }
}
