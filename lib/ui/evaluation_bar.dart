import 'package:flutter/material.dart';

class EvaluationBar extends StatelessWidget {
  const EvaluationBar({super.key, this.evaluation});

  final double? evaluation;

  @override
  Widget build(BuildContext context) {
    final eval = evaluation ?? 0.0;
    // Evaluation is already in pawns (e.g., 0.5 = half pawn advantage)
    // Clamp between -10 and +10 pawns for display
    final clampedEval = eval.clamp(-10.0, 10.0);
    // Convert to 0-1 range where 0.5 is equal, 0 is black winning, 1 is white winning
    final whiteAdvantage = (clampedEval / 10.0 + 1) / 2;

    return Container(
      width: 32,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.3), width: 2),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Column(
          children: [
            Expanded(
              flex: ((1 - whiteAdvantage) * 100).round().clamp(1, 100),
              child: Container(
                color: Colors.grey.shade900,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: whiteAdvantage < 0.5
                    ? RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          _formatEval(eval),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              flex: (whiteAdvantage * 100).round().clamp(1, 100),
              child: Container(
                color: Colors.white,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: whiteAdvantage >= 0.5
                    ? RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          _formatEval(eval),
                          style: TextStyle(
                            color: Colors.grey.shade900,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEval(double pawns) {
    // Evaluation is already in pawns
    if (pawns.abs() > 9) {
      return pawns > 0 ? 'M+' : 'M-';
    }
    if (pawns >= 0) {
      return '+${pawns.toStringAsFixed(1)}';
    }
    return pawns.toStringAsFixed(1);
  }
}
