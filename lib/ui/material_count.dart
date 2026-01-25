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
      elevation: 0,
      color: Colors.blueGrey.shade200,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.balance, color: Colors.grey.shade700, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Material',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMaterialRow(
              context,
              'White',
              whiteMaterial,
              whiteTotal,
              advantage > 0 ? advantage : 0,
              Colors.white,
              true,
            ),
            const SizedBox(height: 6),
            _buildMaterialRow(
              context,
              'Black',
              blackMaterial,
              blackTotal,
              advantage < 0 ? -advantage : 0,
              Colors.black,
              false,
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
    bool isWhite,
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
                _buildPieceCount('queen', pieces['Q']!, isWhite),
              if (pieces['R']! > 0)
                _buildPieceCount('rook', pieces['R']!, isWhite),
              if (pieces['B']! > 0)
                _buildPieceCount('bishop', pieces['B']!, isWhite),
              if (pieces['N']! > 0)
                _buildPieceCount('knight', pieces['N']!, isWhite),
              if (pieces['P']! > 0)
                _buildPieceCount('pawn', pieces['P']!, isWhite),
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

  Widget _buildPieceCount(String pieceName, int count, bool isWhite) {
    final color = isWhite ? 'white' : 'black';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Image.asset(
            'assets/pieces/$color-$pieceName.png',
            fit: BoxFit.contain,
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

    // Starting material for each side
    final startingMaterial = {'Q': 1, 'R': 2, 'B': 2, 'N': 2, 'P': 8};

    final whiteOnBoard = {'Q': 0, 'R': 0, 'B': 0, 'N': 0, 'P': 0};
    final blackOnBoard = {'Q': 0, 'R': 0, 'B': 0, 'N': 0, 'P': 0};

    if (fen.trim().isEmpty) {
      return {
        'white': {'Q': 0, 'R': 0, 'B': 0, 'N': 0, 'P': 0},
        'black': {'Q': 0, 'R': 0, 'B': 0, 'N': 0, 'P': 0},
        'whiteTotal': 0,
        'blackTotal': 0,
      };
    }

    final parts = fen.split(' ');
    if (parts.isEmpty) {
      return {
        'white': {'Q': 0, 'R': 0, 'B': 0, 'N': 0, 'P': 0},
        'black': {'Q': 0, 'R': 0, 'B': 0, 'N': 0, 'P': 0},
        'whiteTotal': 0,
        'blackTotal': 0,
      };
    }

    final position = parts[0];

    // Count pieces currently on the board
    for (final char in position.split('')) {
      final lower = char.toLowerCase();
      if (pieceValues.containsKey(lower)) {
        if (char == char.toUpperCase()) {
          // White piece on board
          whiteOnBoard[char] = whiteOnBoard[char]! + 1;
        } else {
          // Black piece on board
          blackOnBoard[char.toUpperCase()] =
              blackOnBoard[char.toUpperCase()]! + 1;
        }
      }
    }

    // Calculate captured pieces (starting - on board)
    // White captured = black pieces missing from board
    final whiteCaptured = <String, int>{};
    // Black captured = white pieces missing from board
    final blackCaptured = <String, int>{};

    var whiteCapturedTotal = 0;
    var blackCapturedTotal = 0;

    for (final piece in ['Q', 'R', 'B', 'N', 'P']) {
      // Pieces captured by white (black pieces missing)
      whiteCaptured[piece] = startingMaterial[piece]! - blackOnBoard[piece]!;
      whiteCapturedTotal +=
          whiteCaptured[piece]! * pieceValues[piece.toLowerCase()]!;

      // Pieces captured by black (white pieces missing)
      blackCaptured[piece] = startingMaterial[piece]! - whiteOnBoard[piece]!;
      blackCapturedTotal +=
          blackCaptured[piece]! * pieceValues[piece.toLowerCase()]!;
    }

    return {
      'white': whiteCaptured,
      'black': blackCaptured,
      'whiteTotal': whiteCapturedTotal,
      'blackTotal': blackCapturedTotal,
    };
  }
}
