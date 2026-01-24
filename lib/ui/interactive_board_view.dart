import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:chess/chess.dart' as chess;
import '../models/move_analysis.dart';
import 'move_label_icon.dart';

class Arrow {
  final String from;
  final String to;
  final Color color;
  final String? piece;

  Arrow({
    required this.from,
    required this.to,
    this.color = Colors.red,
    this.piece,
  });

  bool get isKnightArrow => piece != null && (piece!.toLowerCase() == 'n');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Arrow &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}

typedef OnMoveMade =
    bool Function({
      required String from,
      required String to,
      String? promotion,
    });

class InteractiveBoardView extends StatefulWidget {
  const InteractiveBoardView({
    super.key,
    required this.fen,
    required this.onMoveMade,
    this.maxSize = 600,
    this.flipped = false,
    this.arrows = const [],
    this.onArrowsChanged,
    this.moveAnalysis,
    this.lastMoveTo,
  });

  final String fen;
  final OnMoveMade onMoveMade;
  final double maxSize;
  final bool flipped;
  final List<Arrow> arrows;
  final void Function(List<Arrow>)? onArrowsChanged;
  final MoveAnalysis? moveAnalysis;
  final String? lastMoveTo;

  @override
  State<InteractiveBoardView> createState() => _InteractiveBoardViewState();
}

class _InteractiveBoardViewState extends State<InteractiveBoardView>
    with SingleTickerProviderStateMixin {
  String? _selectedSquare;
  List<String> _legalMoves = [];
  String? _arrowStart;
  Offset? _arrowDragPosition;
  late chess.Chess _chessEngine;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final Map<String, String> _animatingPieces =
      {}; // destination -> source square
  final Set<String> _animatingFromSquares =
      {}; // squares that pieces are leaving
  final Map<String, String> _animatingPieceTypes =
      {}; // destination -> piece type

  @override
  void initState() {
    super.initState();
    _chessEngine = chess.Chess();
    _updateChessEngine();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(InteractiveBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fen != widget.fen) {
      _startPositionAnimation(oldWidget.fen, widget.fen);
      _updateChessEngine();
      setState(() {
        _selectedSquare = null;
        _legalMoves = [];
      });
    }
  }

  void _startPositionAnimation(String oldFen, String newFen) {
    final oldBoard = _boardFromFen(oldFen);
    final newBoard = _boardFromFen(newFen);

    _animatingPieces.clear();
    _animatingFromSquares.clear();
    _animatingPieceTypes.clear();

    // Count total pieces to detect backward navigation
    // If piece count increases, a captured piece is returning (backward nav)
    int oldPieceCount = 0;
    int newPieceCount = 0;

    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        if (oldBoard[rank][file] != null) oldPieceCount++;
        if (newBoard[rank][file] != null) newPieceCount++;
      }
    }

    // Skip animation on backward navigation (piece count increases)
    if (newPieceCount > oldPieceCount) {
      return;
    }

    // Find pieces that moved
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final square = _getSquareName(file, rank);
        final oldPiece = oldBoard[rank][file];
        final newPiece = newBoard[rank][file];

        if (newPiece != null && newPiece != oldPiece) {
          // This square has a new piece, find where it came from
          for (var r = 0; r < 8; r++) {
            for (var f = 0; f < 8; f++) {
              final fromSquare = _getSquareName(f, r);
              if (oldBoard[r][f] == newPiece && newBoard[r][f] != newPiece) {
                // Found the piece's previous position
                _animatingPieces[square] = fromSquare;
                _animatingFromSquares.add(fromSquare);
                _animatingPieceTypes[square] = newPiece;
                break;
              }
            }
          }
        }
      }
    }

    if (_animatingPieces.isNotEmpty) {
      _animationController.forward(from: 0.0);
    }
  }

  void _updateChessEngine() {
    try {
      _chessEngine.load(widget.fen);
    } catch (e) {
      // Invalid FEN, reset to default
      _chessEngine = chess.Chess();
    }
  }

  List<String> _getLegalMoves(String square) {
    final moves = _chessEngine.moves({'square': square, 'verbose': true});
    return moves.map((move) => move['to'] as String).toList();
  }

  String? _getKingInCheckSquare() {
    if (_chessEngine.in_check) {
      // Find the king of the side to move
      final sideToMove = _chessEngine.turn;
      final kingPiece = sideToMove == chess.Color.WHITE ? 'K' : 'k';

      // Search for the king on the board
      for (var rank = 0; rank < 8; rank++) {
        for (var file = 0; file < 8; file++) {
          final square = _getSquareName(file, rank);
          final piece = _getPieceAt(square);
          if (piece == kingPiece) {
            return square;
          }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final squares = _boardFromFen(widget.fen);

    print(
      '[DISPLAY ICON] InteractiveBoardView.build - moveAnalysis: ${widget.moveAnalysis?.classification}, lastMoveTo: ${widget.lastMoveTo}',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : widget.maxSize;
        final boardSize = availableSize.clamp(300.0, widget.maxSize);
        final squareSize = boardSize / 8;

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
            child: ClipRect(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  if (event.buttons == kSecondaryMouseButton) {
                    final box = context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(event.position);
                    final square = _getSquareFromPosition(
                      localPosition,
                      boardSize,
                    );
                    setState(() {
                      _arrowStart = square;
                      _arrowDragPosition = localPosition;
                    });
                  }
                },
                onPointerMove: (event) {
                  if (event.buttons == kSecondaryMouseButton &&
                      _arrowStart != null) {
                    final box = context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(event.position);
                    setState(() {
                      _arrowDragPosition = localPosition;
                    });
                  }
                },
                onPointerUp: (event) {
                  if (_arrowStart != null) {
                    final box = context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(event.position);
                    final square = _getSquareFromPosition(
                      localPosition,
                      boardSize,
                    );
                    if (square != null && square != _arrowStart) {
                      _addArrow(_arrowStart!, square);
                    }
                    setState(() {
                      _arrowStart = null;
                      _arrowDragPosition = null;
                    });
                  }
                },
                child: Stack(
                  children: [
                    GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                          ),
                      itemCount: 64,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final file = index % 8;
                        final rank = index ~/ 8;

                        // Flip board if needed
                        final displayFile = widget.flipped ? 7 - file : file;
                        final displayRank = widget.flipped ? 7 - rank : rank;

                        final isLight = (file + rank) % 2 == 0;
                        final piece = squares[displayRank][displayFile];
                        final square = _getSquareName(displayFile, displayRank);
                        final isSelected = _selectedSquare == square;
                        final isLegalMove = _legalMoves.contains(square);
                        final kingInCheckSquare = _getKingInCheckSquare();
                        final isKingInCheck = square == kingInCheckSquare;

                        return DragTarget<_DragData>(
                          onWillAcceptWithDetails: (details) {
                            print(
                              'Will accept: ${details.data.from} -> $square',
                            );
                            return true;
                          },
                          onAcceptWithDetails: (details) {
                            print('Accepted: ${details.data.from} -> $square');
                            _handleDrop(details.data.from, square);
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isHovered = candidateData.isNotEmpty;

                            // Base board color
                            final baseColor = isLight
                                ? const Color(0xFFF0D9B5)
                                : const Color(0xFFB58863);

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _handleSquareTap(square, piece),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: baseColor,
                                  border: Border.all(
                                    color: Colors.black.withOpacity(0.05),
                                    width: 0.5,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // King in check overlay
                                    if (isKingInCheck)
                                      Container(
                                        color: Colors.red.withOpacity(0.4),
                                      ),
                                    // Selected square overlay
                                    if (isSelected)
                                      Container(
                                        color: Colors.yellow.withOpacity(0.5),
                                      ),
                                    // Legal move overlay
                                    if (isLegalMove)
                                      Container(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    // Hover overlay
                                    if (isHovered)
                                      Container(
                                        color: Colors.blue.withOpacity(0.3),
                                      ),
                                    if (rank == 7 || file == 0)
                                      _buildCoordinates(file, rank, isLight),
                                    if (piece != null &&
                                        !(_animationController.isAnimating &&
                                            (_animatingFromSquares.contains(
                                                  square,
                                                ) ||
                                                _animatingPieceTypes[square] ==
                                                    piece)))
                                      _buildStaticPiece(
                                        piece,
                                        square,
                                        squareSize,
                                      ),
                                    if (isLegalMove && piece == null)
                                      Center(
                                        child: Container(
                                          width: squareSize * 0.3,
                                          height: squareSize * 0.3,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    // Overlay animating pieces on top
                    if (_animationController.isAnimating)
                      ..._buildAnimatingPiecesOverlay(boardSize, squareSize),
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(boardSize, boardSize),
                        painter: ArrowPainter(
                          arrows: widget.arrows,
                          arrowStart: _arrowStart,
                          arrowDragPosition: _arrowDragPosition,
                          squareSize: squareSize,
                          flipped: widget.flipped,
                        ),
                      ),
                    ),
                    // Move label icon overlay - absolute positioned on top
                    if (widget.moveAnalysis != null &&
                        widget.lastMoveTo != null)
                      ..._buildMoveLabelIconOverlayWithLogging(
                        boardSize,
                        squareSize,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaticPiece(String piece, String square, double squareSize) {
    return Center(
      child: Draggable<_DragData>(
        data: _DragData(from: square, piece: piece),
        dragAnchorStrategy: (draggable, context, position) {
          return Offset(squareSize / 2, squareSize / 2);
        },
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: squareSize,
            height: squareSize,
            child: _buildPiece(piece, squareSize, isDragging: true),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _buildPiece(piece, squareSize),
        ),
        child: _buildPiece(piece, squareSize),
      ),
    );
  }

  List<Widget> _buildAnimatingPiecesOverlay(
    double boardSize,
    double squareSize,
  ) {
    final squares = _boardFromFen(widget.fen);
    final widgets = <Widget>[];

    _animatingPieces.forEach((toSquare, fromSquare) {
      final toFile = toSquare.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final toRank = 8 - int.parse(toSquare[1]);
      final fromFile = fromSquare.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final fromRank = 8 - int.parse(fromSquare[1]);

      final toDisplayFile = widget.flipped ? 7 - toFile : toFile;
      final toDisplayRank = widget.flipped ? 7 - toRank : toRank;
      final fromDisplayFile = widget.flipped ? 7 - fromFile : fromFile;
      final fromDisplayRank = widget.flipped ? 7 - fromRank : fromRank;

      // Get the piece from new position
      final piece = squares[toRank][toFile];
      if (piece == null) return;

      widgets.add(
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final currentFile =
                fromDisplayFile +
                (toDisplayFile - fromDisplayFile) * _animation.value;
            final currentRank =
                fromDisplayRank +
                (toDisplayRank - fromDisplayRank) * _animation.value;

            return Positioned(
              left: currentFile * squareSize,
              top: currentRank * squareSize,
              width: squareSize,
              height: squareSize,
              child: _buildPiece(piece, squareSize),
            );
          },
        ),
      );
    });

    return widgets;
  }

  List<Widget> _buildMoveLabelIconOverlayWithLogging(
    double boardSize,
    double squareSize,
  ) {
    print(
      '[DISPLAY ICON] Condition met - moveAnalysis: ${widget.moveAnalysis?.classification}, lastMoveTo: ${widget.lastMoveTo}',
    );
    return [_buildMoveLabelIconOverlay(boardSize, squareSize)];
  }

  Widget _buildMoveLabelIconOverlay(double boardSize, double squareSize) {
    final square = widget.lastMoveTo!;
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = 8 - int.parse(square[1]);

    final displayFile = widget.flipped ? 7 - file : file;
    final displayRank = widget.flipped ? 7 - rank : rank;

    // Position centered on top-right corner point, but clamp to board boundaries
    const iconSize = 36.0;
    var left = (displayFile + 1) * squareSize - (iconSize / 2);
    var top = displayRank * squareSize - (iconSize / 2);

    // Prevent cutoff on right edge
    if (left + iconSize > boardSize) {
      left = boardSize - iconSize;
    }

    // Prevent cutoff on top edge
    if (top < 0) {
      top = 0;
    }

    print(
      '[DISPLAY ICON] Positioning icon at left=$left, top=$top for square=$square (file=$displayFile, rank=$displayRank, squareSize=$squareSize)',
    );

    return Positioned(
      left: left,
      top: top,
      child: MoveLabelIcon(classification: widget.moveAnalysis!.classification),
    );
  }

  String? _getSquareFromPosition(Offset position, double boardSize) {
    final squareSize = boardSize / 8;
    final file = (position.dx / squareSize).floor();
    final rank = (position.dy / squareSize).floor();

    if (file < 0 || file > 7 || rank < 0 || rank > 7) return null;

    final displayFile = widget.flipped ? 7 - file : file;
    final displayRank = widget.flipped ? 7 - rank : rank;

    return _getSquareName(displayFile, displayRank);
  }

  void _addArrow(String from, String to) {
    final piece = _getPieceAt(from);
    final newArrow = Arrow(from: from, to: to, piece: piece);
    final currentArrows = List<Arrow>.from(widget.arrows);

    // Toggle arrow if it already exists
    if (currentArrows.contains(newArrow)) {
      currentArrows.remove(newArrow);
    } else {
      currentArrows.add(newArrow);
    }

    widget.onArrowsChanged?.call(currentArrows);
  }

  void _handleSquareTap(String square, String? piece) {
    setState(() {
      if (_selectedSquare == null) {
        // Select a piece
        if (piece != null) {
          _selectedSquare = square;
          _legalMoves = _getLegalMoves(square);
        }
      } else {
        // Try to move to this square
        if (_selectedSquare != square) {
          _makeMove(_selectedSquare!, square);
        }
        _selectedSquare = null;
        _legalMoves = [];
      }
    });
  }

  void _handleDrop(String from, String to) {
    if (from != to) {
      _makeMove(from, to);
    }
    setState(() {
      _selectedSquare = null;
      _legalMoves = [];
    });
  }

  void _makeMove(String from, String to) {
    // Check if it's a pawn promotion
    final toRank = int.parse(to[1]);
    final piece = _getPieceAt(from);

    bool needsPromotion = false;
    if (piece != null && piece.toLowerCase() == 'p') {
      if ((piece == 'P' && toRank == 8) || (piece == 'p' && toRank == 1)) {
        needsPromotion = true;
      }
    }

    if (needsPromotion) {
      _showPromotionDialog(from, to);
    } else {
      widget.onMoveMade(from: from, to: to);
    }
  }

  void _showPromotionDialog(String from, String to) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Promotion'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _promotionOption('Q', 'q', from, to),
            _promotionOption('R', 'r', from, to),
            _promotionOption('B', 'b', from, to),
            _promotionOption('N', 'n', from, to),
          ],
        ),
      ),
    );
  }

  Widget _promotionOption(
    String displayPiece,
    String promotion,
    String from,
    String to,
  ) {
    final imagePath = _getPieceImagePath(displayPiece);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        widget.onMoveMade(from: from, to: to, promotion: promotion);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        width: 60,
        height: 60,
        child: Image.asset(imagePath, fit: BoxFit.contain),
      ),
    );
  }

  String? _getPieceAt(String square) {
    final squares = _boardFromFen(widget.fen);
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = 8 - int.parse(square[1]);
    return squares[rank][file];
  }

  String _getSquareName(int file, int rank) {
    final fileName = String.fromCharCode('a'.codeUnitAt(0) + file);
    final rankName = (8 - rank).toString();
    return '$fileName$rankName';
  }

  Widget _buildPiece(
    String piece,
    double squareSize, {
    bool isDragging = false,
  }) {
    final imagePath = _getPieceImagePath(piece);
    return Container(
      padding: EdgeInsets.all(squareSize * 0.05),
      child: Image.asset(
        imagePath,
        width: squareSize * 0.9,
        height: squareSize * 0.9,
        fit: BoxFit.contain,
        opacity: isDragging ? const AlwaysStoppedAnimation(0.7) : null,
      ),
    );
  }

  String _getPieceImagePath(String piece) {
    final color = piece == piece.toUpperCase() ? 'white' : 'black';
    final type = piece.toLowerCase();

    final typeMap = {
      'k': 'king',
      'q': 'queen',
      'r': 'rook',
      'b': 'bishop',
      'n': 'knight',
      'p': 'pawn',
    };

    final pieceName = typeMap[type] ?? 'pawn';
    return 'assets/pieces/$color-$pieceName.png';
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

class _DragData {
  final String from;
  final String piece;

  _DragData({required this.from, required this.piece});
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

class ArrowPainter extends CustomPainter {
  final List<Arrow> arrows;
  final String? arrowStart;
  final Offset? arrowDragPosition;
  final double squareSize;
  final bool flipped;

  ArrowPainter({
    required this.arrows,
    required this.arrowStart,
    required this.arrowDragPosition,
    required this.squareSize,
    required this.flipped,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw saved arrows
    for (final arrow in arrows) {
      _drawArrow(
        canvas,
        arrow.from,
        arrow.to,
        arrow.color,
        arrow.isKnightArrow,
      );
    }

    // Draw current dragging arrow
    if (arrowStart != null && arrowDragPosition != null) {
      _drawDraggingArrow(canvas, arrowStart!, arrowDragPosition!);
    }
  }

  void _drawArrow(
    Canvas canvas,
    String from,
    String to,
    Color color,
    bool isKnightArrow,
  ) {
    final fromOffset = _getSquareCenter(from);
    final toOffset = _getSquareCenter(to);

    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (isKnightArrow) {
      _drawKnightArrow(canvas, fromOffset, toOffset, paint);
    } else {
      // Calculate shortened line to avoid overlap with arrowhead
      final direction = toOffset - fromOffset;
      final length = direction.distance;
      if (length > 0.01) {
        final unitDir = direction / length;
        final arrowSize = squareSize * 0.4;
        // Stop the line before the arrowhead
        final lineEnd = toOffset - unitDir * arrowSize;

        // Draw straight line
        canvas.drawLine(fromOffset, lineEnd, paint);
        // Draw arrowhead
        _drawArrowhead(canvas, fromOffset, toOffset, paint, arrowSize);
      }
    }
  }

  void _drawDraggingArrow(Canvas canvas, String from, Offset to) {
    final fromOffset = _getSquareCenter(from);

    final paint = Paint()
      ..color = Colors.red.withOpacity(0.6)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final direction = to - fromOffset;
    final length = direction.distance;
    if (length > 0.01) {
      final unitDir = direction / length;
      final arrowSize = squareSize * 0.4;
      final lineEnd = to - unitDir * arrowSize;

      canvas.drawLine(fromOffset, lineEnd, paint);
      _drawArrowhead(canvas, fromOffset, to, paint, arrowSize);
    }
  }

  void _drawKnightArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    // Calculate the L-shaped path for knight moves
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;

    // Determine if it's a 2-1 or 1-2 knight move
    final absX = dx.abs();
    final absY = dy.abs();

    Offset midPoint;
    if (absX > absY) {
      // Horizontal then vertical (2-1 move)
      midPoint = Offset(to.dx, from.dy);
    } else {
      // Vertical then horizontal (1-2 move)
      midPoint = Offset(from.dx, to.dy);
    }

    final arrowSize = squareSize * 0.4;
    final direction = to - midPoint;
    final length = direction.distance;

    if (length > 0.01) {
      final unitDir = direction / length;
      final lineEnd = to - unitDir * arrowSize;

      // Draw the L-shaped path
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(midPoint.dx, midPoint.dy)
        ..lineTo(lineEnd.dx, lineEnd.dy);

      canvas.drawPath(path, paint);

      // Draw arrowhead at the end
      _drawArrowhead(canvas, midPoint, to, paint, arrowSize);
    }
  }

  void _drawArrowhead(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    double arrowSize,
  ) {
    final direction = to - from;
    final length = direction.distance;
    if (length < 0.01) return;

    final unitDir = direction / length;
    final perpendicular = Offset(-unitDir.dy, unitDir.dx);

    final arrowBack = to - unitDir * arrowSize;
    final arrowLeft = arrowBack + perpendicular * (arrowSize * 0.5);
    final arrowRight = arrowBack - perpendicular * (arrowSize * 0.5);

    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(arrowLeft.dx, arrowLeft.dy)
      ..lineTo(arrowRight.dx, arrowRight.dy)
      ..close();

    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  Offset _getSquareCenter(String square) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = 8 - int.parse(square[1]);

    final displayFile = flipped ? 7 - file : file;
    final displayRank = flipped ? 7 - rank : rank;

    return Offset(
      (displayFile + 0.5) * squareSize,
      (displayRank + 0.5) * squareSize,
    );
  }

  Offset _getSquareTopRight(String square, double squareSize, bool flipped) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = 8 - int.parse(square[1]);

    final displayFile = flipped ? 7 - file : file;
    final displayRank = flipped ? 7 - rank : rank;

    return Offset((displayFile + 1) * squareSize, displayRank * squareSize);
  }

  @override
  bool shouldRepaint(ArrowPainter oldDelegate) {
    return oldDelegate.arrows != arrows ||
        oldDelegate.arrowStart != arrowStart ||
        oldDelegate.arrowDragPosition != arrowDragPosition ||
        oldDelegate.flipped != flipped;
  }
}
