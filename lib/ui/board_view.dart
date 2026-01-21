import 'package:flutter/material.dart';

class BoardView extends StatelessWidget {
  const BoardView({super.key, required this.fen, this.maxSize = 600});

  final String fen;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final squares = _boardFromFen(fen);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxSize;
        final boardSize = availableSize.clamp(300.0, maxSize);

        return Center(
          child: Container(
            width: boardSize,
            height: boardSize,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
              ),
              itemCount: 64,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final file = index % 8;
                final rank = index ~/ 8;
                final isLight = (file + rank) % 2 == 0;
                final piece = squares[rank][file];
                final squareSize = boardSize / 8;

                return Container(
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF0D9B5)
                        : const Color(0xFFB58863),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.05),
                      width: 0.5,
                    ),
                  ),
                  child: piece == null
                      ? _buildCoordinates(file, rank, isLight)
                      : Stack(
                          children: [
                            if (rank == 7 || file == 0)
                              _buildCoordinates(file, rank, isLight),
                            Center(child: _buildPiece(piece, squareSize)),
                          ],
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPiece(String piece, double squareSize) {
    return Text(
      _unicodePiece(piece),
      style: TextStyle(
        fontSize: (squareSize * 0.7).clamp(30.0, 70.0),
        fontFamily: 'serif',
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(1, 1),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinates(int file, int rank, bool isLight) {
    final textColor = isLight
        ? const Color(0xFFB58863).withOpacity(0.6)
        : const Color(0xFFF0D9B5).withOpacity(0.6);

    return Stack(
      children: [
        if (rank == 7)
          Positioned(
            top: 2,
            right: 2,
            child: Text(
              String.fromCharCode('a'.codeUnitAt(0) + file),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        if (file == 0)
          Positioned(
            bottom: 2,
            left: 2,
            child: Text(
              '${8 - rank}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
      ],
    );
  }
}

List<List<String?>> _boardFromFen(String fen) {
  final rows = List.generate(8, (_) => List<String?>.filled(8, null));
  if (fen.trim().isEmpty) return rows;
  final parts = fen.split(' ');
  if (parts.isEmpty) return rows;

  final ranks = parts[0].split('/');
  if (ranks.length != 8) return rows;

  for (var r = 0; r < 8; r += 1) {
    var file = 0;
    for (final ch in ranks[r].split('')) {
      final digit = int.tryParse(ch);
      if (digit != null) {
        file += digit;
      } else {
        if (file >= 8) break;
        rows[r][file] = ch;
        file += 1;
      }
    }
  }
  return rows;
}

String _unicodePiece(String piece) {
  switch (piece) {
    case 'K':
      return '♔';
    case 'Q':
      return '♕';
    case 'R':
      return '♖';
    case 'B':
      return '♗';
    case 'N':
      return '♘';
    case 'P':
      return '♙';
    case 'k':
      return '♚';
    case 'q':
      return '♛';
    case 'r':
      return '♜';
    case 'b':
      return '♝';
    case 'n':
      return '♞';
    case 'p':
      return '♟';
    default:
      return '';
  }
}
