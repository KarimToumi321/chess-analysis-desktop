import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:file_picker/file_picker.dart';

import '../state/chess_controller.dart';
import '../state/engine_controller.dart';
import '../models/move_analysis.dart';
import '../models/move_labeling.dart';
import '../models/saved_analysis.dart';
import '../services/analysis_service.dart';
import 'interactive_board_view.dart';
import 'move_list.dart';
import 'engine_panel.dart';
import 'material_count.dart';
import 'evaluation_bar.dart';
import 'variations_panel.dart';
import 'move_label_selector.dart';
import '../models/move_label.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final FocusNode _focusNode = FocusNode();
  bool _boardFlipped = false;
  TextEditingController? _commentController;
  String? _lastCommentFen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _saveCurrentComment();
    _commentController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveCurrentComment() {
    if (_commentController != null && _lastCommentFen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chess = context.read<ChessController>();
        chess.setCommentForFen(_lastCommentFen!, _commentController!.text);
      });
    }
  }

  void _updateCommentController(ChessController chess) {
    final currentFen = chess.fen;
    if (_lastCommentFen != currentFen) {
      if (_lastCommentFen != null && _commentController != null) {
        // Save previous position's comment after build completes
        final previousFen = _lastCommentFen!;
        final textToSave = _commentController!.text;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          chess.setCommentForFen(previousFen, textToSave);
        });
      }
      _lastCommentFen = currentFen;
      _commentController?.text = chess.getCommentForCurrentPosition();
    }
  }

  Future<void> _analyzeAndLabel(
    ChessController chess,
    EngineController engine,
  ) async {
    final moveIndex = chess.currentIndex - 1;
    if (moveIndex < 0 || moveIndex >= chess.moves.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No move to classify at start position.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    try {
      // Ensure we are not interleaving UCI commands from multiple analyses.
      if (engine.isAnalyzing) {
        engine.stopAnalysis();
      }
      await engine.ensureEngineReady();
      final analysisService = AnalysisService(engine.engineService);

      final fenBefore = chess.getFenBeforeMoveIndex(moveIndex);
      final playedSan = chess.moves[moveIndex];
      final ma = await analysisService.analyzeSingleMove(
        fenBefore: fenBefore,
        playedSan: playedSan,
        moveNumber: moveIndex + 1,
        timePerMove: chess.analysisTimePerMove,
        harshness: chess.moveLabelHarshness,
        debugLog: (m) {
          if (kDebugMode) debugPrint(m);
        },
      );

      if (ma == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not classify this move.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      chess.upsertMoveAnalysis(ma);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Move labeled: ${_labelFor(ma.classification)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Start/update the live evaluation for the current position afterwards.
      // This keeps labeling consistent and avoids interleaving engine commands.
      if (!engine.isBusy) {
        // Do not await (long-running UI feature).
        engine.analyzePosition(chess.fen);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Engine classification failed: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _labelFor(MoveClassification c) {
    switch (c) {
      case MoveClassification.best:
        return 'Best';
      case MoveClassification.great:
        return 'Great';
      case MoveClassification.excellent:
        return 'Excellent';
      case MoveClassification.good:
        return 'Good';
      case MoveClassification.inaccuracy:
        return 'Inaccuracy';
      case MoveClassification.mistake:
        return 'Mistake';
      case MoveClassification.miss:
        return 'Miss';
      case MoveClassification.blunder:
        return 'Blunder';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chess = context.watch<ChessController>();
    final engine = context.watch<EngineController>();
    final positionEvaluation = _resolveEvaluation(chess, engine);

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
              if (positionEvaluation != null) ...[
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
                    _formatEvalDisplay(positionEvaluation),
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
                    : () => _analyzeAndLabel(chess, engine),
                icon: const Icon(Icons.analytics_outlined),
              ),
            IconButton(
              tooltip: 'Save analysis',
              onPressed: () => _showSaveDialog(chess),
              icon: const Icon(Icons.save_outlined),
            ),
            IconButton(
              tooltip: 'Load analysis',
              onPressed: () => _showLoadDialog(chess),
              icon: const Icon(Icons.folder_open_outlined),
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
              return _buildWideLayout(
                context,
                chess,
                engine,
                positionEvaluation,
              );
            } else {
              return _buildNarrowLayout(
                context,
                chess,
                engine,
                positionEvaluation,
              );
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
    double? positionEvaluation,
  ) {
    return Row(
      children: [
        // Evaluation bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: EvaluationBar(evaluation: positionEvaluation),
        ),
        // Commentary section
        SizedBox(
          width: 250,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            child: _buildCommentarySection(chess),
          ),
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
                      MaterialCount(fen: chess.fen),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final moveAnalysis = chess.currentIndex > 0
                              ? chess.getMoveAnalysisForMoveIndex(
                                  chess.currentIndex - 1,
                                )
                              : null;
                          final lastMoveTo = chess.getLastMoveToSquare();
                          print(
                            '[ANALYSIS PAGE] Passing to board - moveAnalysis: ${moveAnalysis?.classification}, lastMoveTo: $lastMoveTo, currentIndex: ${chess.currentIndex}',
                          );
                          return InteractiveBoardView(
                            fen: chess.fen,
                            maxSize: 500,
                            flipped: _boardFlipped,
                            arrows: chess.getArrowsForCurrentPosition(),
                            onArrowsChanged: (arrows) {
                              chess.setArrowsForCurrentPosition(arrows);
                            },
                            highlights: chess.getHighlightsForCurrentPosition(),
                            onHighlightsChanged: (highlights) {
                              chess.setHighlightsForCurrentPosition(highlights);
                            },
                            moveAnalysis: moveAnalysis,
                            lastMoveTo: lastMoveTo,
                            onMoveMade:
                                ({required from, required to, promotion}) {
                                  return chess.makeMove(
                                    from: from,
                                    to: to,
                                    promotion: promotion,
                                  );
                                },
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildNavigation(chess),
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
    double? positionEvaluation,
  ) {
    return Row(
      children: [
        // Evaluation bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: EvaluationBar(evaluation: positionEvaluation),
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
                      MaterialCount(fen: chess.fen),
                      const SizedBox(height: 12),
                      InteractiveBoardView(
                        fen: chess.fen,
                        maxSize: 450,
                        flipped: _boardFlipped,
                        arrows: chess.getArrowsForCurrentPosition(),
                        onArrowsChanged: (arrows) {
                          chess.setArrowsForCurrentPosition(arrows);
                        },
                        highlights: chess.getHighlightsForCurrentPosition(),
                        onHighlightsChanged: (highlights) {
                          chess.setHighlightsForCurrentPosition(highlights);
                        },
                        moveAnalysis: chess.currentIndex > 0
                            ? chess.getMoveAnalysisForMoveIndex(
                                chess.currentIndex - 1,
                              )
                            : null,
                        lastMoveTo: chess.getLastMoveToSquare(),
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
    final engine = context.watch<EngineController>();

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
            constraints: const BoxConstraints(maxHeight: 150),
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
            height: 250,
            child: MoveList(
              moves: chess.moves,
              currentIndex: chess.currentIndex,
              onSelect: chess.setIndex,
              gameAnalysis: chess.gameAnalysis,
              moveAnalysisProvider: chess.getMoveAnalysisForMoveIndex,
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

  Future<void> _analyzeMainLine(
    BuildContext context,
    ChessController chess,
    EngineController engine,
  ) async {
    // Ensure engine is ready
    try {
      await engine.ensureEngineReady();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start engine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (chess.moves.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No moves to analyze in main line'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Show confirmation dialog
    if (mounted) {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Analyze Main Line'),
          content: Text(
            'Analyze all ${chess.moves.length} moves in the main line?\n\n'
            'This will use the current analysis settings:\n'
            '• Time per move: ${chess.analysisTimePerMove}ms\n'
            '• Harshness: ${chess.moveLabelHarshness.name}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Analyze'),
            ),
          ],
        ),
      );

      if (result != true) return;
    }

    // Get starting FEN (typically standard start position)
    final startFen = chess.getFenBeforeMoveIndex(0);

    // Show progress dialog
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MainLineAnalysisProgressDialog(
        analysisService: AnalysisService(engine.engineService),
        moves: chess.moves,
        startFen: startFen,
        timePerMove: chess.analysisTimePerMove.inMilliseconds,
        harshness: chess.moveLabelHarshness,
        onComplete: (moveAnalyses) {
          // Store all move analyses and evaluations
          for (var ma in moveAnalyses) {
            chess.upsertMoveAnalysis(ma);
            final isWhite = chess.sideToMoveIsWhite(ma.fen);
            chess.storeEvaluation(ma.fen, ma.evalBefore, forWhite: isWhite);
            // Store evalAfter
            try {
              final pos = chess_lib.Chess.fromFEN(ma.fen);
              pos.move(ma.move);
              final fenAfter = pos.fen;
              chess.storeEvaluation(fenAfter, ma.evalAfter, forWhite: !isWhite);
            } catch (e) {
              // Skip if move replay fails
            }
          }
        },
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

  Widget _buildCommentarySection(ChessController chess) {
    _commentController ??= TextEditingController();
    _updateCommentController(chess);

    final moveIndex = chess.currentIndex - 1;
    final userLabels = moveIndex >= 0
        ? chess.getUserLabelsForMove(moveIndex)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Icon(
                Icons.comment_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Commentary',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // User labels section
        if (moveIndex >= 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.label_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Move Labels',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          _showMoveLabelDialog(context, chess, moveIndex),
                      icon: const Icon(Icons.edit, size: 14),
                      label: Text(
                        userLabels != null && userLabels.labelIds.isNotEmpty
                            ? 'Edit'
                            : 'Add',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (userLabels != null && userLabels.labelIds.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: userLabels.labels.map((label) {
                      final color = _getCategoryColor(label.category);
                      return Chip(
                        avatar: Icon(
                          _getCategoryIcon(label.category),
                          size: 14,
                          color: color,
                        ),
                        label: Text(
                          label.name,
                          style: const TextStyle(fontSize: 11),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          chess.removeUserLabelFromMove(moveIndex, label.id);
                        },
                        backgroundColor: color.withOpacity(0.15),
                        side: BorderSide(color: color, width: 1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  )
                else
                  Text(
                    'No labels added',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextFormField(
                controller: _commentController,
                maxLines: null,
                expands: true,
                textAlign: TextAlign.left,
                textAlignVertical: TextAlignVertical.top,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Add your notes for this position...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(UserLabelCategory category) {
    switch (category) {
      case UserLabelCategory.tactical:
        return Colors.red.shade700;
      case UserLabelCategory.strategic:
        return Colors.blue.shade700;
      case UserLabelCategory.pieceActivity:
        return Colors.green.shade700;
      case UserLabelCategory.positional:
        return Colors.purple.shade700;
      case UserLabelCategory.gamePhase:
        return Colors.orange.shade700;
      case UserLabelCategory.riskProfile:
        return Colors.teal.shade700;
    }
  }

  IconData _getCategoryIcon(UserLabelCategory category) {
    switch (category) {
      case UserLabelCategory.tactical:
        return Icons.flash_on;
      case UserLabelCategory.strategic:
        return Icons.psychology;
      case UserLabelCategory.pieceActivity:
        return Icons.trending_up;
      case UserLabelCategory.positional:
        return Icons.grid_on;
      case UserLabelCategory.gamePhase:
        return Icons.timeline;
      case UserLabelCategory.riskProfile:
        return Icons.warning_amber;
    }
  }

  void _showMoveLabelDialog(
    BuildContext context,
    ChessController chess,
    int moveIndex,
  ) {
    final currentLabels = chess.getUserLabelsForMove(moveIndex);
    final selectedIds = currentLabels?.labelIds ?? [];

    showDialog(
      context: context,
      builder: (context) => MoveLabelSelector(
        selectedLabelIds: selectedIds,
        maxLabels: chess.maxUserLabelsPerMove,
        onLabelsChanged: (newLabels) {
          chess.setUserLabelsForMove(moveIndex, newLabels);
        },
      ),
    );
  }

  double? _resolveEvaluation(ChessController chess, EngineController engine) {
    if (engine.isAnalyzing && engine.currentEvaluation != null) {
      return engine.currentEvaluation;
    }
    return chess.evaluationForCurrentPosition ?? engine.currentEvaluation;
  }

  Future<void> _showSaveDialog(ChessController chess) async {
    final titleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Analysis'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Enter a title for this analysis',
            ),
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _saveAnalysisToFile(chess, titleController.text.trim());
    }

    titleController.dispose();
  }

  Future<void> _saveAnalysisToFile(ChessController chess, String title) async {
    try {
      // Export analysis
      final savedAnalysis = chess.exportAnalysis(title);

      // Convert to JSON
      final jsonString = jsonEncode(savedAnalysis.toJson());

      // Ask user where to save
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Analysis',
        fileName: '${title.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonString);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Analysis saved to ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showLoadDialog(ChessController chess) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Load Analysis',
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty && mounted) {
      await _loadAnalysisFromFile(chess, result.files.first.path!);
    }
  }

  Future<void> _loadAnalysisFromFile(
    ChessController chess,
    String filePath,
  ) async {
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final savedAnalysis = SavedAnalysis.fromJson(json);

      // Import the analysis
      chess.importAnalysis(savedAnalysis);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis "${savedAnalysis.title}" loaded'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

class _MainLineAnalysisProgressDialog extends StatefulWidget {
  final AnalysisService analysisService;
  final List<String> moves;
  final String startFen;
  final int timePerMove;
  final MoveLabelHarshness harshness;
  final void Function(List<MoveAnalysis>) onComplete;

  const _MainLineAnalysisProgressDialog({
    required this.analysisService,
    required this.moves,
    required this.startFen,
    required this.timePerMove,
    required this.harshness,
    required this.onComplete,
  });

  @override
  State<_MainLineAnalysisProgressDialog> createState() =>
      _MainLineAnalysisProgressDialogState();
}

class _MainLineAnalysisProgressDialogState
    extends State<_MainLineAnalysisProgressDialog> {
  int _currentMoveIndex = 0;
  final List<MoveAnalysis> _analyses = [];
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    try {
      String currentFen = widget.startFen;
      final game = chess_lib.Chess.fromFEN(currentFen);

      for (int i = 0; i < widget.moves.length; i++) {
        if (!mounted) break;

        setState(() {
          _currentMoveIndex = i;
        });

        final move = widget.moves[i];
        final fenBefore = game.fen;

        final ma = await widget.analysisService.analyzeSingleMove(
          fenBefore: fenBefore,
          playedSan: move,
          moveNumber: i + 1,
          timePerMove: Duration(milliseconds: widget.timePerMove),
          harshness: widget.harshness,
          debugLog: (m) {
            if (kDebugMode) debugPrint(m);
          },
        );

        if (ma != null) {
          _analyses.add(ma);
        }

        // Make the move to advance position
        game.move(move);
      }

      setState(() {
        _isComplete = true;
      });

      widget.onComplete(_analyses);

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.moves.isEmpty
        ? 0.0
        : (_currentMoveIndex + 1) / widget.moves.length;

    return AlertDialog(
      title: const Text('Analyzing Main Line'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 16),
          Text(
            _isComplete
                ? 'Complete!'
                : 'Move ${_currentMoveIndex + 1} of ${widget.moves.length}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
