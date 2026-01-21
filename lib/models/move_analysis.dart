enum MoveClassification {
  best,
  great,
  excellent,
  good,
  inaccuracy,
  mistake,
  miss,
  blunder,
  brilliant,
}

enum MoveTag {
  forced,
  onlyMove,
}

class MoveAnalysis {
  final int moveNumber;
  final String move;
  final String fen;
  final double evalBefore;
  final double evalAfter;
  final double centipawnLoss;
  final String bestMove;
  final MoveClassification classification;
  final List<MoveTag> tags;
  final List<String>? engineLine;

  MoveAnalysis({
    required this.moveNumber,
    required this.move,
    required this.fen,
    required this.evalBefore,
    required this.evalAfter,
    required this.centipawnLoss,
    required this.bestMove,
    required this.classification,
    this.tags = const [],
    this.engineLine,
  });
}

class GameAnalysis {
  final List<MoveAnalysis> moves;
  final double whiteAccuracy;
  final double blackAccuracy;
  final DateTime analyzedAt;

  GameAnalysis({
    required this.moves,
    required this.whiteAccuracy,
    required this.blackAccuracy,
    required this.analyzedAt,
  });

  static GameAnalysis fromMoves(List<MoveAnalysis> moves) {
    if (moves.isEmpty) {
      return GameAnalysis(
        moves: [],
        whiteAccuracy: 100.0,
        blackAccuracy: 100.0,
        analyzedAt: DateTime.now(),
      );
    }

    // Calculate accuracy for white and black
    double whiteLoss = 0;
    double blackLoss = 0;
    int whiteMoves = 0;
    int blackMoves = 0;

    for (final move in moves) {
      // Even move numbers are white, odd are black
      if (move.moveNumber % 2 == 1) {
        whiteLoss += move.centipawnLoss;
        whiteMoves++;
      } else {
        blackLoss += move.centipawnLoss;
        blackMoves++;
      }
    }

    // Calculate accuracy: 100 - (avgLoss / 10)
    final whiteAccuracy = whiteMoves > 0
        ? (100 - ((whiteLoss / whiteMoves) / 10)).clamp(0, 100).toDouble()
        : 100.0;
    final blackAccuracy = blackMoves > 0
        ? (100 - ((blackLoss / blackMoves) / 10)).clamp(0, 100).toDouble()
        : 100.0;

    return GameAnalysis(
      moves: moves,
      whiteAccuracy: whiteAccuracy,
      blackAccuracy: blackAccuracy,
      analyzedAt: DateTime.now(),
    );
  }

  MoveAnalysis? getMoveAnalysis(int index) {
    if (index < 0 || index >= moves.length) return null;
    return moves[index];
  }
}
