import 'package:flutter/material.dart';
import '../models/move_analysis.dart';

/// Visual icon for move labels displayed on the chess board
class MoveLabelIcon extends StatelessWidget {
  const MoveLabelIcon({
    super.key,
    required this.classification,
    this.size = 24.0,
  });

  final MoveClassification classification;
  final double size;

  @override
  Widget build(BuildContext context) {
    final config = _getLabelConfig(classification);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: config.useIcon
            ? Icon(config.icon, color: config.iconColor, size: size * 0.6)
            : Text(
                config.symbol,
                style: TextStyle(
                  color: config.iconColor,
                  fontSize: size * 0.55,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }

  static _LabelConfig _getLabelConfig(MoveClassification classification) {
    switch (classification) {
      case MoveClassification.best:
        return const _LabelConfig(
          backgroundColor: Color(0xFF4CAF50), // Green
          icon: Icons.star,
          iconColor: Colors.white,
          useIcon: true,
        );
      case MoveClassification.great:
        return const _LabelConfig(
          backgroundColor: Color(0xFF66BB6A), // Light green
          icon: Icons.check_circle,
          iconColor: Colors.white,
          useIcon: true,
        );
      case MoveClassification.excellent:
        return const _LabelConfig(
          backgroundColor: Color(0xFF8BC34A), // Lime green
          icon: Icons.check,
          iconColor: Colors.white,
          useIcon: true,
        );
      case MoveClassification.good:
        return const _LabelConfig(
          backgroundColor: Color(0xFF03A9F4), // Light blue
          symbol: '✓',
          iconColor: Colors.white,
          useIcon: false,
        );
      case MoveClassification.inaccuracy:
        return const _LabelConfig(
          backgroundColor: Color(0xFFFFA726), // Orange
          symbol: '?!',
          iconColor: Colors.white,
          useIcon: false,
        );
      case MoveClassification.miss:
        return const _LabelConfig(
          backgroundColor: Color(0xFFFF9800), // Dark orange
          symbol: '?',
          iconColor: Colors.white,
          useIcon: false,
        );
      case MoveClassification.mistake:
        return const _LabelConfig(
          backgroundColor: Color(0xFFFF7043), // Deep orange
          symbol: '??',
          iconColor: Colors.white,
          useIcon: false,
        );
      case MoveClassification.blunder:
        return const _LabelConfig(
          backgroundColor: Color(0xFFF44336), // Red
          icon: Icons.close,
          iconColor: Colors.white,
          useIcon: true,
        );
    }
  }
}

class _LabelConfig {
  final Color backgroundColor;
  final IconData? icon;
  final String symbol;
  final Color iconColor;
  final bool useIcon;

  const _LabelConfig({
    required this.backgroundColor,
    this.icon,
    this.symbol = '',
    required this.iconColor,
    required this.useIcon,
  });
}
