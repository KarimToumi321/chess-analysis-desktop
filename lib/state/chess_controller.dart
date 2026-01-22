import 'package:flutter/foundation.dart';
import 'package:chess/chess.dart' as chess;

import '../utils/pgn_parser.dart';
import '../models/variation.dart';
import '../models/move_analysis.dart';
import '../models/move_labeling.dart';
import '../ui/interactive_board_view.dart';

class ChessController extends ChangeNotifier {
  chess.Chess _game = chess.Chess();
  List<String> _moves = <String>[];
  int _currentIndex = 0;
  String _pgnText = '';
  String? _error;

  // Analysis support
  GameAnalysis? _gameAnalysis;

  // Engine analysis settings (mirrors PGN selection UI)
  bool _analyzeWithEngine = false;
  Duration _analysisTimePerMove = const Duration(milliseconds: 500);
  MoveLabelHarshness _moveLabelHarshness = MoveLabelHarshness.normal;

  // Move analysis cache keyed by (fenBefore|san) so side lines can be labeled.
  final Map<String, MoveAnalysis> _moveAnalysisByKey = {};

  // Variation support
  GameTree _gameTree = GameTree(
    variations: {
      'main': Variation(
        id: 'main',
        name: 'Main Line',
        moves: [],
        startPosition: 0,
      ),
    },
    currentVariationId: 'main',
  );
  int _variationCounter = 0;
  int _mainLineLastPosition = 0; // Track last position reached in main line

  // Arrow storage per FEN position
  final Map<String, List<Arrow>> _arrowsByFen = {};

  List<String> get moves => List.unmodifiable(_moves);
  int get currentIndex => _currentIndex;
  String get pgnText => _pgnText;
  String? get error => _error;
  GameTree get gameTree => _gameTree;
  Variation get currentVariation => _gameTree.currentVariation;
  GameAnalysis? get gameAnalysis => _gameAnalysis;

  bool get analyzeWithEngine => _analyzeWithEngine;
  Duration get analysisTimePerMove => _analysisTimePerMove;
  MoveLabelHarshness get moveLabelHarshness => _moveLabelHarshness;

  String get fen => _readFen();

  List<Arrow> getArrowsForCurrentPosition() {
    return _arrowsByFen[fen] ?? [];
  }

  void setArrowsForCurrentPosition(List<Arrow> arrows) {
    if (arrows.isEmpty) {
      _arrowsByFen.remove(fen);
    } else {
      _arrowsByFen[fen] = arrows;
    }
    notifyListeners();
  }

  void loadPgn(String pgn) {
    _pgnText = pgn.trim();
    _error = null;

    // If empty PGN, start with empty position
    if (_pgnText.isEmpty) {
      _moves = <String>[];
      _currentIndex = 0;
      _game = chess.Chess();
      _gameAnalysis = null;
      _moveAnalysisByKey.clear();
      _gameTree = GameTree(
        variations: {
          'main': Variation(
            id: 'main',
            name: 'Main Line',
            moves: [],
            startPosition: 0,
          ),
        },
        currentVariationId: 'main',
      );
      _variationCounter = 0;
      notifyListeners();
      return;
    }

    _moves = parseSanMovesFromPgn(_pgnText);
    _currentIndex = 0;

    // Initialize main line with loaded moves
    _gameTree = GameTree(
      variations: {
        'main': Variation(
          id: 'main',
          name: 'Main Line',
          moves: List.from(_moves),
          startPosition: 0,
        ),
      },
      currentVariationId: 'main',
    );
    _variationCounter = 0;

    // Reset analysis state when loading a new PGN
    _gameAnalysis = null;
    _moveAnalysisByKey.clear();

    _rebuildGame();
  }

  void loadFen(String fen) {
    _error = null;
    _moves = <String>[];
    _pgnText = '';
    _currentIndex = 0;
    _game = chess.Chess();
    _gameAnalysis = null;
    _moveAnalysisByKey.clear();
    _gameTree = GameTree(
      variations: {
        'main': Variation(
          id: 'main',
          name: 'Main Line',
          moves: [],
          startPosition: 0,
        ),
      },
      currentVariationId: 'main',
    );
    _variationCounter = 0;
    final ok = _tryLoadFen(fen);
    if (!ok) {
      _error = 'Invalid FEN.';
    }
    notifyListeners();
  }

  void setAnalysisSettings({
    required bool analyzeWithEngine,
    required Duration timePerMove,
    MoveLabelHarshness moveLabelHarshness = MoveLabelHarshness.normal,
  }) {
    _analyzeWithEngine = analyzeWithEngine;
    _analysisTimePerMove = timePerMove;
    _moveLabelHarshness = moveLabelHarshness;
    notifyListeners();
  }

  void upsertMoveAnalysis(MoveAnalysis analysis) {
    final key = _analysisKey(fenBefore: analysis.fen, san: analysis.move);
    _moveAnalysisByKey[key] = analysis;
    notifyListeners();
  }

  MoveAnalysis? getMoveAnalysisForMoveIndex(int moveIndex) {
    if (moveIndex < 0 || moveIndex >= _moves.length) return null;

    final fenBefore = _fenAtPly(moveIndex);
    final san = _moves[moveIndex];
    final key = _analysisKey(fenBefore: fenBefore, san: san);
    final cached = _moveAnalysisByKey[key];
    if (cached != null) return cached;

    final ga = _gameAnalysis;
    if (ga == null) return null;
    final fromGa = ga.getMoveAnalysis(moveIndex);
    if (fromGa == null) return null;
    // Only use GameAnalysis result if it matches this exact position+move
    if (fromGa.fen == fenBefore && fromGa.move == san) return fromGa;
    return null;
  }

  String getFenBeforeMoveIndex(int moveIndex) {
    return _fenAtPly(moveIndex);
  }

  String _analysisKey({required String fenBefore, required String san}) {
    return '$fenBefore|$san';
  }

  String _fenAtPly(int plyCount) {
    final g = chess.Chess();
    final limit = plyCount.clamp(0, _moves.length);
    for (var i = 0; i < limit; i += 1) {
      final ok = g.move(_moves[i]);
      if (ok == false) break;
    }
    return g.fen;
  }

  void goToStart() {
    if (_currentIndex == 0) return;
    _currentIndex = 0;
    _rebuildGame();
  }

  void goToEnd() {
    if (_currentIndex == _moves.length) return;
    _currentIndex = _moves.length;
    _rebuildGame();
  }

  void next() {
    if (_currentIndex >= _moves.length) return;
    _currentIndex += 1;

    // Track main line position
    if (_gameTree.currentVariationId == 'main') {
      _mainLineLastPosition = _currentIndex;
    }

    _rebuildGame();
  }

  void previous() {
    if (_currentIndex <= 0) return;
    _currentIndex -= 1;

    // Track main line position
    if (_gameTree.currentVariationId == 'main') {
      _mainLineLastPosition = _currentIndex;
    }

    _rebuildGame();
  }

  void setIndex(int index) {
    if (index < 0 || index > _moves.length) return;
    _currentIndex = index;

    // Track main line position
    if (_gameTree.currentVariationId == 'main') {
      _mainLineLastPosition = index;
    }

    _rebuildGame();
  }

  // Create a new variation from current position
  void createVariation(String firstMove) {
    _variationCounter++;
    final variationId = 'variation_$_variationCounter';

    // Determine the actual parent - if we're in a variation, use its parent
    // This ensures all variations at the same position are siblings
    final currentVariation =
        _gameTree.variations[_gameTree.currentVariationId]!;
    final parentId = currentVariation.parentId ?? _gameTree.currentVariationId;

    // Count existing variations at this position to get proper numbering
    final siblingsCount = _gameTree.variations.values
        .where(
          (v) => v.parentId == parentId && v.startPosition == _currentIndex,
        )
        .length;

    final variationName = 'Side Line ${siblingsCount + 1}';

    final newVariation = Variation(
      id: variationId,
      name: variationName,
      moves: [firstMove],
      startPosition: _currentIndex,
      parentId: parentId,
    );

    final updatedVariations = Map<String, Variation>.from(_gameTree.variations);
    updatedVariations[variationId] = newVariation;

    _gameTree = GameTree(
      variations: updatedVariations,
      currentVariationId: variationId,
    );

    // Switch to this variation and apply the move
    _switchToVariation(variationId);
  }

  // Switch to a different variation
  void switchToVariation(String variationId) {
    if (!_gameTree.variations.containsKey(variationId)) return;
    _switchToVariation(variationId);
  }

  void _switchToVariation(String variationId) {
    final variation = _gameTree.variations[variationId]!;

    // Update game tree
    _gameTree = _gameTree.copyWith(currentVariationId: variationId);

    // Update moves list to reflect current variation
    _moves = _buildFullMovePath(variation);

    // Navigate to appropriate position
    if (variation.parentId == null) {
      // Main line - go to last saved position
      _currentIndex = _mainLineLastPosition;
    } else {
      // Side line - go to first move of the variation
      _currentIndex = variation.startPosition + 1;
    }

    _rebuildGame();
  }

  // Build full move path for a variation
  List<String> _buildFullMovePath(Variation variation) {
    if (variation.parentId == null) {
      // Main line
      return List.from(variation.moves);
    }

    // Side line - need to include moves from parent up to branch point
    final parent = _gameTree.variations[variation.parentId];
    if (parent == null) return List.from(variation.moves);

    final parentMoves = _buildFullMovePath(parent);
    final movesUpToBranch = parentMoves.take(variation.startPosition).toList();

    return [...movesUpToBranch, ...variation.moves];
  }

  bool _isValidSan(String san) {
    // Basic check if the string looks like a valid SAN move
    if (san.isEmpty) return false;
    // Should not be just numbers (like the index)
    if (RegExp(r'^\d+$').hasMatch(san)) return false;
    // Should contain letters and/or numbers in a chess-like pattern
    return RegExp(r'^[NBRQK]?[a-h]?[1-8]?[x]?[a-h][1-8]').hasMatch(san) ||
        san == 'O-O' ||
        san == 'O-O-O';
  }

  // Add a move to current variation
  void addMoveToCurrentVariation(String move) {
    final currentVar = _gameTree.currentVariation;
    final updatedMoves = List<String>.from(currentVar.moves)..add(move);

    final updatedVariation = currentVar.copyWith(moves: updatedMoves);
    final updatedVariations = Map<String, Variation>.from(_gameTree.variations);
    updatedVariations[currentVar.id] = updatedVariation;

    _gameTree = GameTree(
      variations: updatedVariations,
      currentVariationId: _gameTree.currentVariationId,
    );

    // Update moves and advance position
    _moves = _buildFullMovePath(updatedVariation);
    _currentIndex++;

    // Track main line position
    if (_gameTree.currentVariationId == 'main') {
      _mainLineLastPosition = _currentIndex;
    }

    _rebuildGame();
  }

  // Undo the last move in the current variation
  // Returns true if successful, false if no moves to undo
  bool undoMove() {
    final currentVar = _gameTree.currentVariation;

    // Can't undo if we're at the start of the variation
    if (currentVar.moves.isEmpty) {
      return false;
    }

    // Remove the last move
    final updatedMoves = List<String>.from(currentVar.moves)..removeLast();
    final updatedVariation = currentVar.copyWith(moves: updatedMoves);
    final updatedVariations = Map<String, Variation>.from(_gameTree.variations);
    updatedVariations[currentVar.id] = updatedVariation;

    _gameTree = GameTree(
      variations: updatedVariations,
      currentVariationId: _gameTree.currentVariationId,
    );

    // Update moves and move back one position
    _moves = _buildFullMovePath(updatedVariation);
    if (_currentIndex > 0) {
      _currentIndex--;
    }

    // Track main line position
    if (_gameTree.currentVariationId == 'main') {
      _mainLineLastPosition = _currentIndex;
    }

    _rebuildGame();
    return true;
  }

  // Delete a variation (cannot delete main line)
  // Returns true if successful, false if variation doesn't exist or is main line
  bool deleteVariation(String variationId) {
    // Can't delete main line
    if (variationId == 'main') {
      return false;
    }

    // Check if variation exists
    if (!_gameTree.variations.containsKey(variationId)) {
      return false;
    }

    final variationToDelete = _gameTree.variations[variationId]!;
    final updatedVariations = Map<String, Variation>.from(_gameTree.variations);

    // Remove the variation
    updatedVariations.remove(variationId);

    // Also remove any child variations recursively
    final childVariations = updatedVariations.values
        .where((v) => v.parentId == variationId)
        .map((v) => v.id)
        .toList();

    for (final childId in childVariations) {
      updatedVariations.remove(childId);
    }

    // If we're currently in the deleted variation, switch to its parent or main line
    String newCurrentId = _gameTree.currentVariationId;
    if (variationId == _gameTree.currentVariationId ||
        childVariations.contains(_gameTree.currentVariationId)) {
      newCurrentId = variationToDelete.parentId ?? 'main';
    }

    _gameTree = GameTree(
      variations: updatedVariations,
      currentVariationId: newCurrentId,
    );

    // Switch to the new variation
    _switchToVariation(newCurrentId);
    return true;
  }

  // Make a move interactively
  // Returns true if successful, false if invalid
  bool makeMove({String? from, String? to, String? promotion}) {
    try {
      if (from == null || to == null) {
        return false;
      }

      print('=== Making move: $from -> $to ===');
      print('FEN before move: ${fen}');
      print('Current index: $_currentIndex / ${_moves.length}');

      // Try making the move to validate it
      final result = _game.move({
        'from': from,
        'to': to,
        'promotion': promotion ?? 'q',
      });

      if (result == false) {
        print('Move validation failed');
        return false;
      }

      print('Move successfully applied, FEN: ${fen}');

      // Undo and get the pretty move object which contains the SAN
      final dynamic undoResult = _game.undo();
      if (undoResult == null) {
        print('Failed to undo move');
        return false;
      }

      // The undo() method returns a Map with 'san' key
      final String? san = undoResult['san'];
      print('Move SAN from undo: $san');

      if (san == null || san.isEmpty || !_isValidSan(san)) {
        print('Could not get valid SAN notation: $san');
        return false;
      }

      print('FEN after undo: ${fen}');

      // Check if we're at the end of current line or in the middle
      if (_currentIndex < _moves.length) {
        // We're in the middle - check if move matches next move in line
        final nextMove = _moves[_currentIndex];
        print('Next move in line: $nextMove');
        if (san == nextMove) {
          // Move matches - just advance
          print('Move matches - advancing');
          _currentIndex++;

          // Track main line position
          if (_gameTree.currentVariationId == 'main') {
            _mainLineLastPosition = _currentIndex;
          }

          _rebuildGame();
          print('FEN after rebuild: ${fen}');
          return true;
        } else {
          // Move doesn't match - check if this exact variation already exists
          final currentVariation =
              _gameTree.variations[_gameTree.currentVariationId]!;
          final parentId =
              currentVariation.parentId ?? _gameTree.currentVariationId;

          // Find if there's an existing variation at this position with this move
          Variation? existingVariation;
          for (var variation in _gameTree.variations.values) {
            if (variation.parentId == parentId &&
                variation.startPosition == _currentIndex &&
                variation.moves.isNotEmpty &&
                variation.moves[0] == san) {
              existingVariation = variation;
              break;
            }
          }

          if (existingVariation != null) {
            // This variation already exists, switch to it
            print(
              'Variation already exists, switching to: ${existingVariation.name}',
            );
            switchToVariation(existingVariation.id);
            _currentIndex++;
            _rebuildGame();
            print('FEN after switching: ${fen}');
            return true;
          } else {
            // Move doesn't match and variation doesn't exist - create a new variation
            print('Creating new variation with move: $san');
            createVariation(san);
            print('FEN after variation created: ${fen}');
            return true;
          }
        }
      } else {
        // At the end of line - add move to current variation
        print('Adding move to current variation: $san');
        addMoveToCurrentVariation(san);
        print('FEN after move added: ${fen}');
        return true;
      }
    } catch (e) {
      print('Move error: $e');
      return false;
    }
  }

  void _rebuildGame() {
    print('=== Rebuilding game ===');
    print('Current index: $_currentIndex');
    print('Total moves: ${_moves.length}');
    print('Moves: $_moves');
    _error = null;
    _game = chess.Chess();
    for (var i = 0; i < _currentIndex; i += 1) {
      final move = _moves[i];
      print('Applying move $i: $move');
      final applied = _tryMove(move);
      if (!applied) {
        _error = 'Failed to apply move: $move';
        _currentIndex = i;
        print('Failed to apply move: $move');
        break;
      }
    }
    print('FEN after rebuild: ${fen}');
    notifyListeners();
  }

  bool _tryMove(String san) {
    try {
      final result = _game.move(san);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  bool _tryLoadFen(String fen) {
    try {
      final dynamic game = _game;
      final ok = game.load(fen);
      return ok == true;
    } catch (_) {
      // fall through
    }

    try {
      final dynamic game = _game;
      final ok = game.load_fen(fen);
      return ok == true;
    } catch (_) {
      // fall through
    }

    try {
      final dynamic game = _game;
      final ok = game.loadFen(fen);
      return ok == true;
    } catch (_) {
      // fall through
    }

    try {
      _game = chess.Chess.fromFEN(fen);
      return true;
    } catch (_) {
      return false;
    }
  }

  void setGameAnalysis(GameAnalysis? analysis) {
    _gameAnalysis = analysis;

    // Seed cache for quick lookup (and for validation against variations).
    _moveAnalysisByKey.clear();
    if (analysis != null) {
      for (final ma in analysis.moves) {
        _moveAnalysisByKey[_analysisKey(fenBefore: ma.fen, san: ma.move)] = ma;
      }
    }
    notifyListeners();
  }

  String _readFen() {
    try {
      final dynamic game = _game;
      final value = game.fen();
      if (value is String) return value;
    } catch (_) {
      // fall through
    }
    try {
      final dynamic game = _game;
      final value = game.fen;
      if (value is String) return value;
    } catch (_) {
      // fall through
    }
    return '';
  }
}
