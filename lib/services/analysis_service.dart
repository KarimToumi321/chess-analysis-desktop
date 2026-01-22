import 'package:chess/chess.dart' as chess;
import '../models/move_analysis.dart';
import '../services/engine_service.dart';

class _HangingInfo {
  final int attackers;
  final int defenders;
  final Map<String, dynamic>? captureMove;

  const _HangingInfo({
    required this.attackers,
    required this.defenders,
    this.captureMove,
  });
}

class AnalysisService {
  final EngineService _engineService;

  AnalysisService(this._engineService);

  Future<GameAnalysis> analyzeGame({
    required List<String> moves,
    required String startingFen,
    required Function(int current, int total) onProgress,
    Duration timePerMove = const Duration(milliseconds: 500),
  }) async {
    final game = chess.Chess();
    if (startingFen.isNotEmpty && startingFen != chess.Chess.DEFAULT_POSITION) {
      game.load(startingFen);
    }

    final moveAnalyses = <MoveAnalysis>[];

    for (var i = 0; i < moves.length; i++) {
      onProgress(i + 1, moves.length);

      final fenBefore = game.fen;
      final playedSan = moves[i];
      final playerIsWhite = i % 2 == 0;

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
        playerIsWhite,
      );
      final myMaterialBefore = _materialFromFen(fenBefore, playerIsWhite);
      final oppMaterialBefore = _materialFromFen(fenBefore, !playerIsWhite);
      final netMaterialBefore = myMaterialBefore - oppMaterialBefore;

      final tags = <MoveTag>[];
      if (legalMovesCount == 1) {
        tags.add(MoveTag.forced);
      }
      if (legalMovesCount > 1 && secondUci != null && secondUci.isNotEmpty) {
        final bestEval = _evalFromEngineResult(beforePvs[0], playerIsWhite);
        final secondEval = _evalFromEngineResult(beforePvs[1], playerIsWhite);
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
      String? playedToSquare;
      if (undoData is Map) {
        playedUci = _uciFromUndo(undoData);
        final to = undoData['to'];
        if (to is String && to.length == 2) {
          playedToSquare = to;
        }
        final replayOk = _replayFromUndo(game, undoData);
        if (!replayOk) {
          continue;
        }
      } else {
        // If undo didn't yield details, re-apply SAN to keep state.
        game.move(playedSan);
      }

      final fenAfterPlayed = game.fen;
      final afterPlayed = await _engineService.analyzePosition(
        fenAfterPlayed,
        timePerMove,
      );
      final evalAfterPlayedForPlayer = afterPlayed == null
          ? evalBeforeForPlayer
          : _evalFromEngineResult(afterPlayed, playerIsWhite);

      final myMaterialAfter = _materialFromFen(fenAfterPlayed, playerIsWhite);
      final oppMaterialAfter = _materialFromFen(fenAfterPlayed, !playerIsWhite);
      final netMaterialAfter = myMaterialAfter - oppMaterialAfter;
      final netMaterialDelta = netMaterialAfter - netMaterialBefore;

      // 3) Evaluate the position after the engine best move.
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
                playerIsWhite,
              );
            }
          }
        }
      }

      // 4) Centipawn loss: how much worse the played move is vs best move.
      final centipawnLoss = (evalAfterBestForPlayer - evalAfterPlayedForPlayer)
          .clamp(0.0, double.infinity);

      var classification = _classifyLikeChessCom(
        centipawnLoss: centipawnLoss,
        playerEvalBefore: evalBeforeForPlayer,
        playerEvalAfter: evalAfterPlayedForPlayer,
        playerEvalAfterBest: evalAfterBestForPlayer,
        isBestMove: playedUci != null && playedUci == bestUci,
      );

      // Human-like overrides (primary label), tags remain secondary.
      final isBestMove = playedUci != null && playedUci == bestUci;

      // Cache opponent best reply from the analyzed position-after-play.
      final opponentBestUci = (afterPlayed?['bestmove'] as String?) ?? '';

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

    return GameAnalysis.fromMoves(moveAnalyses);
  }

  double _evalFromEngineResult(
    Map<String, dynamic> result,
    bool playerIsWhite,
  ) {
    // Engine scores are always from White's perspective.
    if (result.containsKey('mate')) {
      final mateIn = result['mate'] as int;
      final v = mateIn > 0 ? 10000.0 : -10000.0;
      return playerIsWhite ? v : -v;
    }
    if (result.containsKey('cp')) {
      final v = (result['cp'] as int).toDouble();
      return playerIsWhite ? v : -v;
    }
    return 0.0;
  }

  MoveClassification _classifyLikeChessCom({
    required double centipawnLoss,
    required double playerEvalBefore,
    required double playerEvalAfter,
    required double playerEvalAfterBest,
    required bool isBestMove,
  }) {
    // Mate situations: treat missing mates / allowing mates as severe.
    if (playerEvalAfterBest >= 9500 && playerEvalAfter < 9000) {
      // Best line mates / wins decisively and we didn't.
      return MoveClassification.blunder;
    }
    if (playerEvalAfter <= -9500) {
      // We are getting mated (or lost completely).
      return MoveClassification.blunder;
    }

    // If it's the best move (exact UCI match), label it best.
    if (isBestMove) return MoveClassification.best;

    // Dynamic-ish thresholds: be a bit more forgiving in completely winning/losing positions.
    final alreadyDecided = playerEvalAfterBest.abs() >= 600;
    final scale = alreadyDecided ? 1.35 : 1.0;

    final loss = centipawnLoss;
    // Near-best (but not exact best) gets its own label.
    if (loss < 5 * scale) return MoveClassification.great;
    if (loss < 10 * scale) return MoveClassification.excellent;
    if (loss < 30 * scale) return MoveClassification.good;
    if (loss < 80 * scale) return MoveClassification.inaccuracy;
    if (loss < 200 * scale) return MoveClassification.mistake;
    return MoveClassification.blunder;
  }

  _HangingInfo _hangingInfoForSquare({
    required String fenAfterPlayed,
    required String targetSquare,
    required String preferredOpponentUci,
  }) {
    try {
      final game = chess.Chess.fromFEN(fenAfterPlayed);
      final rawMoves = game.moves({'verbose': true});

      final attackerMoves = <Map>[];
      final attackerFrom = <String>{};
      for (final m in rawMoves) {
        if (m is! Map) continue;
        final to = m['to'];
        final from = m['from'];
        if (to is String && from is String && to == targetSquare) {
          attackerMoves.add(m);
          attackerFrom.add(from);
        }
      }

      final attackers = attackerFrom.length;
      if (attackers == 0) {
        return const _HangingInfo(attackers: 0, defenders: 0);
      }

      // Choose a capture to test:
      // 1) prefer engine best reply if it captures to targetSquare
      // 2) otherwise prefer the least valuable capturing piece.
      Map<String, dynamic>? candidateCapture;
      if (preferredOpponentUci.length >= 4 &&
          preferredOpponentUci.substring(2, 4) == targetSquare) {
        candidateCapture = _captureMoveMapFromUci(
          rawMoves,
          preferredOpponentUci,
        );
      }

      candidateCapture ??= _leastValuableCapture(attackerMoves, fenAfterPlayed);

      var minDefenders = 999;
      for (final attacker in attackerMoves) {
        final from = attacker['from'];
        final to = attacker['to'];
        if (from is! String || to is! String) continue;

        final sim = chess.Chess.fromFEN(fenAfterPlayed);
        final move = <String, dynamic>{'from': from, 'to': to};
        final promotion = attacker['promotion'];
        if (promotion is String && promotion.isNotEmpty) {
          move['promotion'] = promotion.toLowerCase();
        }

        final ok = sim.move(move);
        if (ok == false) continue;

        final replies = sim.moves({'verbose': true});
        final defenderFrom = <String>{};
        for (final r in replies) {
          if (r is! Map) continue;
          final rTo = r['to'];
          final rFrom = r['from'];
          if (rTo is String && rFrom is String && rTo == targetSquare) {
            defenderFrom.add(rFrom);
          }
        }

        if (defenderFrom.length < minDefenders) {
          minDefenders = defenderFrom.length;
        }
      }

      if (minDefenders == 999) minDefenders = 0;
      return _HangingInfo(
        attackers: attackers,
        defenders: minDefenders,
        captureMove: candidateCapture,
      );
    } catch (_) {
      return const _HangingInfo(attackers: 0, defenders: 0);
    }
  }

  Map<String, dynamic>? _captureMoveMapFromUci(List rawMoves, String uci) {
    if (uci.length < 4) return null;
    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length >= 5 ? uci[4].toLowerCase() : null;

    for (final m in rawMoves) {
      if (m is! Map) continue;
      final mFrom = m['from'];
      final mTo = m['to'];
      if (mFrom == from && mTo == to) {
        final move = <String, dynamic>{'from': from, 'to': to};
        if (promotion != null) move['promotion'] = promotion;
        return move;
      }
    }
    return null;
  }

  Map<String, dynamic>? _leastValuableCapture(
    List<Map> captureMoves,
    String fen,
  ) {
    if (captureMoves.isEmpty) return null;

    Map<String, dynamic>? best;
    var bestValue = 999;
    for (final m in captureMoves) {
      final from = m['from'];
      final to = m['to'];
      if (from is! String || to is! String) continue;
      final piece = _pieceCharAtSquareFromFen(fen, from);
      final value = _pieceValue(piece);
      if (value < bestValue) {
        bestValue = value;
        best = <String, dynamic>{'from': from, 'to': to};
        final promotion = m['promotion'];
        if (promotion is String && promotion.isNotEmpty) {
          best['promotion'] = promotion.toLowerCase();
        }
      }
    }
    return best;
  }

  String? _pieceCharAtSquareFromFen(String fen, String square) {
    // square: file a-h, rank 1-8
    if (square.length != 2) return null;
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(square[1]);
    if (file < 0 || file > 7 || rank == null || rank < 1 || rank > 8)
      return null;

    final parts = fen.split(' ');
    if (parts.isEmpty) return null;
    final board = parts[0];

    var currentRank = 8;
    var currentFile = 0;
    for (final ch in board.split('')) {
      if (ch == '/') {
        currentRank--;
        currentFile = 0;
        continue;
      }
      final digit = int.tryParse(ch);
      if (digit != null) {
        currentFile += digit;
        continue;
      }

      if (currentRank == rank && currentFile == file) {
        return ch;
      }
      currentFile++;
    }
    return null;
  }

  int _pieceValue(String? pieceChar) {
    if (pieceChar == null) return 999;
    switch (pieceChar.toLowerCase()) {
      case 'p':
        return 1;
      case 'n':
      case 'b':
        return 3;
      case 'r':
        return 5;
      case 'q':
        return 9;
      case 'k':
        return 100;
      default:
        return 999;
    }
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
    if (from is! String || to is! String) return false;

    final move = <String, dynamic>{'from': from, 'to': to};
    final promotion = undoData['promotion'];
    if (promotion is String && promotion.isNotEmpty) {
      move['promotion'] = promotion.toLowerCase();
    }

    final result = game.move(move);
    return result != false;
  }

  String? _uciFromUndo(Map undoData) {
    final from = undoData['from'];
    final to = undoData['to'];
    if (from is! String || to is! String) return null;
    final promotion = undoData['promotion'];
    if (promotion is String && promotion.isNotEmpty) {
      return '$from$to${promotion.toLowerCase()}';
    }
    return '$from$to';
  }

  int _materialFromFen(String fen, bool forWhite) {
    // Only need the piece placement field.
    final parts = fen.split(' ');
    if (parts.isEmpty) return 0;
    final board = parts[0];

    const values = <String, int>{
      'p': 1,
      'n': 3,
      'b': 3,
      'r': 5,
      'q': 9,
      'k': 0,
    };

    var sum = 0;
    for (final rune in board.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '/' || int.tryParse(ch) != null) continue;
      final isWhitePiece = ch.toUpperCase() == ch;
      if (isWhitePiece != forWhite) continue;
      sum += values[ch.toLowerCase()] ?? 0;
    }
    return sum;
  }

  void dispose() {
    // Cleanup if needed
  }
}
