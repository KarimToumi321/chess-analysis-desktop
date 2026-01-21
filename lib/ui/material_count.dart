import 'package:flutter/material.dart';

class MaterialCount extends StatelessWidget {
  const MaterialCount({super.key, required this.fen});

  final String fen;

  @override
  Widget build(BuildContext context) {
    final material = _calculateMaterial(fen);
    final whiteMaterial = material['white']!;
    final blackMaterial = material['black']!;
    final whiteTotal = material['whiteTotal']!;
    final blackTotal = material['blackTotal']!;
    final advantage = whiteTotal - blackTotal;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.balance,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Material',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMaterialRow(
              context,
              'White',
              whiteMaterial,
              whiteTotal,
              advantage > 0 ? advantage : 0,
              Colors.white,
            ),
            const SizedBox(height: 12),
            _buildMaterialRow(
              context,
              'Black',
              blackMaterial,
              blackTotal,
              advantage < 0 ? -advantage : 0,
              Colors.grey.shade800,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialRow(
    BuildContext context,
    String label,
    Map<String, int> pieces,
    int total,
    int advantage,
    Color pieceColor,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            children: [
              if (pieces['Q']! > 0)
                _buildPieceCount('♕', pieces['Q']!, pieceColor),
              if (pieces['R']! > 0)
                _buildPieceCount('♖', pieces['R']!, pieceColor),
              if (pieces['B']! > 0)
                _buildPieceCount('♗', pieces['B']!, pieceColor),
              if (pieces['N']! > 0)
                _buildPieceCount('♘', pieces['N']!, pieceColor),
              if (pieces['P']! > 0)
                _buildPieceCount('♙', pieces['P']!, pieceColor),
            ],
          ),
        ),
        if (advantage > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$advantage',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPieceCount(String piece, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          piece,
          style: TextStyle(
            fontSize: 20,
            color: color,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0.5, 0.5),
                blurRadius: 1,
              ),
            ],
          ),
        ),
        if (count > 1)
          Text(
            '×$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
      ],
    );
  }

  Map<String, dynamic> _calculateMaterial(String fen) {
    final pieceValues = {'q': 9, 'r': 5, 'b': 3, 'n': 3, 'p': 1};

    final white = {'Q': 0, 'R': 0, 'B': 0, 'N': 0, 'P': 0};
    final black = {'Q': 0, 'R': 0, 'B': 0, 'N': 0, 'P': 0};

    if (fen.trim().isEmpty) {
      return {'white': white, 'black': black, 'whiteTotal': 0, 'blackTotal': 0};
    }

    final parts = fen.split(' ');
    if (parts.isEmpty) {
      return {'white': white, 'black': black, 'whiteTotal': 0, 'blackTotal': 0};
    }

    final position = parts[0];
    var whiteTotal = 0;
    var blackTotal = 0;

    for (final char in position.split('')) {
      final lower = char.toLowerCase();
      if (pieceValues.containsKey(lower)) {
        final value = pieceValues[lower]!;
        if (char == char.toUpperCase()) {
          // White piece
          white[char] = white[char]! + 1;
          whiteTotal += value;
        } else {
          // Black piece
          black[char.toUpperCase()] = black[char.toUpperCase()]! + 1;
          blackTotal += value;
        }
      }
    }

    return {
      'white': white,
      'black': black,
      'whiteTotal': whiteTotal,
      'blackTotal': blackTotal,
    };
  }
}
