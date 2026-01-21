import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/chess_controller.dart';
import '../state/engine_controller.dart';
import 'interactive_board_view.dart';
import 'move_list.dart';
import 'engine_panel.dart';
import 'material_count.dart';
import 'evaluation_bar.dart';
import 'variations_panel.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final FocusNode _focusNode = FocusNode();
  bool _boardFlipped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chess = context.watch<ChessController>();
    final engine = context.watch<EngineController>();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            chess.previous();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            chess.next();
          } else if (event.logicalKey == LogicalKeyboardKey.home) {
            chess.goToStart();
          } else if (event.logicalKey == LogicalKeyboardKey.end) {
            chess.goToEnd();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Chess Analysis'),
              if (engine.currentDepth != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.layers,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Depth ${engine.currentDepth}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (engine.currentEvaluation != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatEvalDisplay(engine.currentEvaluation!),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          centerTitle: false,
          actions: [
            if (engine.isAnalyzing)
              IconButton(
                tooltip: 'Stop analysis',
                onPressed: () => engine.stopAnalysis(),
                icon: const Icon(Icons.stop_circle_outlined),
              )
            else
              IconButton(
                tooltip: 'Analyze position',
                onPressed: engine.isBusy
                    ? null
                    : () => engine.analyzePosition(chess.fen),
                icon: const Icon(Icons.analytics_outlined),
              ),
            IconButton(
              tooltip: 'New analysis',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home_outlined),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1000;

            if (isWide) {
              return _buildWideLayout(context, chess, engine);
            } else {
              return _buildNarrowLayout(context, chess, engine);
            }
          },
        ),
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    ChessController chess,
    EngineController engine,
  ) {
    return Row(
      children: [
        // Evaluation bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: EvaluationBar(evaluation: engine.currentEvaluation),
        ),
        // Left side - Board and controls
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      InteractiveBoardView(
                        fen: chess.fen,
                        maxSize: 600,
                        flipped: _boardFlipped,
                        arrows: chess.getArrowsForCurrentPosition(),
                        onArrowsChanged: (arrows) {
                          chess.setArrowsForCurrentPosition(arrows);
                        },
                        onMoveMade: ({required from, required to, promotion}) {
                          return chess.makeMove(
                            from: from,
                            to: to,
                            promotion: promotion,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildNavigation(chess),
                      const SizedBox(height: 20),
                      MaterialCount(fen: chess.fen),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right side - Moves and Engine
        SizedBox(
          width: 380,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMovesSection(chess),
                        const SizedBox(height: 20),
                        _buildEngineSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    ChessController chess,
    EngineController engine,
  ) {
    return Row(
      children: [
        // Evaluation bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: EvaluationBar(evaluation: engine.currentEvaluation),
        ),
        // Main content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      InteractiveBoardView(
                        fen: chess.fen,
                        maxSize: 500,
                        flipped: _boardFlipped,
                        arrows: chess.getArrowsForCurrentPosition(),
                        onArrowsChanged: (arrows) {
                          chess.setArrowsForCurrentPosition(arrows);
                        },
                        onMoveMade: ({required from, required to, promotion}) {
                          return chess.makeMove(
                            from: from,
                            to: to,
                            promotion: promotion,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildNavigation(chess),
                      const SizedBox(height: 16),
                      MaterialCount(fen: chess.fen),
                      const SizedBox(height: 20),
                      _buildMovesSection(chess),
                      const SizedBox(height: 20),
                      _buildEngineSection(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigation(ChessController chess) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filled(
              tooltip: 'Start',
              onPressed: chess.goToStart,
              icon: const Icon(Icons.first_page_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Previous',
              onPressed: chess.previous,
              icon: const Icon(Icons.chevron_left_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${chess.currentIndex} / ${chess.moves.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              tooltip: 'Next',
              onPressed: chess.next,
              icon: const Icon(Icons.chevron_right_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'End',
              onPressed: chess.goToEnd,
              icon: const Icon(Icons.last_page_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            IconButton.filled(
              tooltip: 'Undo Move',
              onPressed: () {
                final success = chess.undoMove();
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No moves to undo'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.undo),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.tertiaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Flip Board',
              onPressed: () {
                setState(() {
                  _boardFlipped = !_boardFlipped;
                });
              },
              icon: Icon(
                _boardFlipped ? Icons.flip_to_front : Icons.flip_to_back,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovesSection(ChessController chess) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Variations header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Variations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Variations panel
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: VariationsPanel(
                gameTree: chess.gameTree,
                onVariationSelected: chess.switchToVariation,
              ),
            ),
          ),
          const Divider(height: 1),
          // Move list header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.list_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Move List',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 300,
            child: MoveList(
              moves: chess.moves,
              currentIndex: chess.currentIndex,
              onSelect: chess.setIndex,
              onCreateVariation: () =>
                  _showCreateVariationDialog(context, chess),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineSection() {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.memory,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Engine Analysis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const Padding(padding: EdgeInsets.all(16), child: EnginePanel()),
        ],
      ),
    );
  }

  void _showCreateVariationDialog(BuildContext context, ChessController chess) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Variation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the first move of the new variation:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Move (e.g., Nf3, e4)',
                hintText: 'Enter move in algebraic notation',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  chess.createVariation(value.trim());
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                chess.createVariation(controller.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  String _formatEvalDisplay(double pawns) {
    // Evaluation is already in pawns
    if (pawns.abs() > 900) {
      return pawns > 0 ? 'Mate soon' : 'Mated soon';
    }
    if (pawns >= 0) {
      return '+${pawns.toStringAsFixed(2)}';
    }
    return pawns.toStringAsFixed(2);
  }
}
