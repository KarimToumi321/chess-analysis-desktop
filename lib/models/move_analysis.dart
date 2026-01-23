import 'dart:math' as math;

enum MoveClassification {
  best,
  great,
  excellent,
  good,
  inaccuracy,
  mistake,
  miss,
  blunder,
}

enum MoveTag { forced, onlyMove }

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
    double whiteLabelScore = 0;
    double blackLabelScore = 0;
    int whiteMoves = 0;
    int blackMoves = 0;

    for (final move in moves) {
      final score = _classificationScore(move.classification);
      // Odd move numbers are white, even are black
      if (move.moveNumber % 2 == 1) {
        whiteLoss += move.centipawnLoss;
        whiteLabelScore += score;
        whiteMoves++;
      } else {
        blackLoss += move.centipawnLoss;
        blackLabelScore += score;
        blackMoves++;
      }
    }

    // Accuracy formula combining label scores and ACPL
    // Accuracy = 100 × L × e^(-ACPL/λ)
    // where λ = 250 + ACPL × 0.5 (adaptive: strict at low ACPL, forgiving at high)

    final whiteAcpl = whiteMoves > 0 ? whiteLoss / whiteMoves : 0.0;
    final blackAcpl = blackMoves > 0 ? blackLoss / blackMoves : 0.0;

    final whiteL = whiteMoves > 0 ? (whiteLabelScore / whiteMoves) / 10.0 : 1.0;
    final blackL = blackMoves > 0 ? (blackLabelScore / blackMoves) / 10.0 : 1.0;

    // Adaptive L: at low ACPL, L→1.0 (labels matter less), at high ACPL, L matters fully
    // L_effective = 1 - α + α × L, where α = min(1, ACPL/400)
    final whiteAlpha = (whiteAcpl / 100.0).clamp(0.0, 1.0);
    final blackAlpha = (blackAcpl / 100.0).clamp(0.0, 1.0);
    final whiteLEffective = 1.0 - whiteAlpha + whiteAlpha * whiteL;
    final blackLEffective = 1.0 - blackAlpha + blackAlpha * blackL;

    // Adaptive lambda based on ACPL
    final whiteLambda = 250.0 + whiteAcpl * 0.7;
    final blackLambda = 250.0 + blackAcpl * 0.7;

    final whiteAccuracy =
        (100 * whiteLEffective * math.exp(-whiteAcpl / whiteLambda))
            .clamp(0, 100)
            .toDouble();
    final blackAccuracy =
        (100 * blackLEffective * math.exp(-blackAcpl / blackLambda))
            .clamp(0, 100)
            .toDouble();

    print(
      '[ACCURACY] white=${whiteAccuracy.toStringAsFixed(1)}% '
      '(moves=$whiteMoves loss=${whiteLoss.toStringAsFixed(1)}cp acpl=${whiteAcpl.toStringAsFixed(1)}cp) | '
      'black=${blackAccuracy.toStringAsFixed(1)}% '
      '(moves=$blackMoves loss=${blackLoss.toStringAsFixed(1)}cp acpl=${blackAcpl.toStringAsFixed(1)}cp)',
    );

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

  static double _classificationScore(MoveClassification classification) {
    switch (classification) {
      case MoveClassification.best:
        return 10.0;
      case MoveClassification.great:
        return 9.0;
      case MoveClassification.excellent:
        return 8.5;
      case MoveClassification.good:
        return 8.0;
      case MoveClassification.inaccuracy:
        return 6.0;
      case MoveClassification.miss:
        return 5.0;
      case MoveClassification.mistake:
        return 3.0;
      case MoveClassification.blunder:
        return 0.0;
    }
  }
}
