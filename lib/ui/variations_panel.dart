import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../models/variation.dart';
import '../models/move_labeling.dart';
import '../state/chess_controller.dart';
import '../state/engine_controller.dart';
import '../services/analysis_service.dart';

class VariationsPanel extends StatelessWidget {
  const VariationsPanel({
    super.key,
    required this.gameTree,
    required this.onVariationSelected,
  });

  final GameTree gameTree;
  final ValueChanged<String> onVariationSelected;

  @override
  Widget build(BuildContext context) {
    final mainLine = gameTree.getMainLine();
    final sideLines = gameTree.getSideLines();

    if (mainLine == null && sideLines.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No variations yet.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mainLine != null)
          _buildVariationTile(
            context,
            mainLine,
            isMainLine: true,
            isSelected: gameTree.currentVariationId == mainLine.id,
          ),
        if (sideLines.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Side Lines',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          ...sideLines.map(
            (variation) => _buildVariationTile(
              context,
              variation,
              isMainLine: false,
              isSelected: gameTree.currentVariationId == variation.id,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVariationTile(
    BuildContext context,
    Variation variation, {
    required bool isMainLine,
    required bool isSelected,
  }) {
    final icon = isMainLine ? Icons.timeline : Icons.call_split;
    final subtitle = isMainLine
        ? '${variation.moves.length} moves'
        : 'From move ${variation.startPosition + 1} • ${variation.moves.length} moves';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: isSelected ? 3 : 1,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        title: Text(
          variation.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer.withOpacity(0.7)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        trailing: isMainLine
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined, size: 20),
                    tooltip: 'Analyze main line',
                    onPressed: () => _analyzeVariation(context, variation),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined, size: 20),
                    tooltip: 'Analyze variation',
                    onPressed: () => _analyzeVariation(context, variation),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Delete variation',
                    onPressed: () {
                      _showDeleteConfirmation(context, variation);
                    },
                  ),
                ],
              ),
        onTap: () => onVariationSelected(variation.id),
      ),
    );
  }

  Future<void> _analyzeVariation(
    BuildContext context,
    Variation variation,
  ) async {
    final chess = context.read<ChessController>();
    final engine = context.read<EngineController>();

    // Ensure engine is ready
    try {
      await engine.ensureEngineReady();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start engine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (variation.moves.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No moves to analyze in this variation'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Show confirmation dialog with analysis settings
    if (context.mounted) {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => _AnalyzeVariationDialog(
          variationName: variation.name,
          moveCount: variation.moves.length,
        ),
      );

      if (result != true) return;
    }

    // Get the FEN before the variation starts
    final startFen = chess.getFenBeforeMoveIndex(variation.startPosition);

    // Show progress dialog
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _VariationAnalysisProgressDialog(
        analysisService: AnalysisService(engine.engineService),
        variation: variation,
        startFen: startFen,
        timePerMove: chess.analysisTimePerMove,
        harshness: chess.moveLabelHarshness,
        onComplete: (moveAnalyses) {
          // Store all move analyses and evaluations in the cache
          for (var ma in moveAnalyses) {
            chess.upsertMoveAnalysis(ma);
            // Store evalBefore and evalAfter for the evaluation bar
            final isWhite = chess.sideToMoveIsWhite(ma.fen);
            chess.storeEvaluation(ma.fen, ma.evalBefore, forWhite: isWhite);
            // Also need to get the FEN after the move to store evalAfter
            // We'll reconstruct it by replaying the move
            try {
              final pos = chess_lib.Chess.fromFEN(ma.fen);
              pos.move(ma.move);
              final fenAfter = pos.fen;
              chess.storeEvaluation(fenAfter, ma.evalAfter, forWhite: !isWhite);
            } catch (e) {
              // If move replay fails, skip storing evalAfter
            }
          }
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Variation variation) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Variation'),
          content: Text(
            'Are you sure you want to delete "${variation.name}"?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final chess = context.read<ChessController>();
                final success = chess.deleteVariation(variation.id);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${variation.name} deleted'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

class _AnalyzeVariationDialog extends StatelessWidget {
  final String variationName;
  final int moveCount;

  const _AnalyzeVariationDialog({
    required this.variationName,
    required this.moveCount,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Analyze Variation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analyze all $moveCount moves in "$variationName"?'),
          const SizedBox(height: 16),
          Text(
            'This will use the engine to classify each move.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Analyze'),
        ),
      ],
    );
  }
}

class _VariationAnalysisProgressDialog extends StatefulWidget {
  final AnalysisService analysisService;
  final Variation variation;
  final String startFen;
  final Duration timePerMove;
  final MoveLabelHarshness harshness;
  final Function(List) onComplete;

  const _VariationAnalysisProgressDialog({
    required this.analysisService,
    required this.variation,
    required this.startFen,
    required this.timePerMove,
    required this.harshness,
    required this.onComplete,
  });

  @override
  State<_VariationAnalysisProgressDialog> createState() =>
      _VariationAnalysisProgressDialogState();
}

class _VariationAnalysisProgressDialogState
    extends State<_VariationAnalysisProgressDialog> {
  int _current = 0;
  int _total = 0;
  String _status = 'Starting analysis...';

  @override
  void initState() {
    super.initState();
    _total = widget.variation.moves.length;
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      final analysis = await widget.analysisService.analyzeGame(
        moves: widget.variation.moves,
        startingFen: widget.startFen,
        timePerMove: widget.timePerMove,
        harshness: widget.harshness,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _current = current;
              _total = total;
              _status =
                  'Analyzing move $current of $total (${widget.timePerMove.inMilliseconds}ms/move)...';
            });
          }
        },
      );

      widget.onComplete(analysis.moves);

      if (mounted) {
        setState(() => _status = 'Analysis complete!');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (kDebugMode) print('Error analyzing variation: $e');
      if (mounted) {
        setState(() => _status = 'Analysis failed: $e');
        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Analyzing "${widget.variation.name}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _total > 0 ? _current / _total : 0),
          const SizedBox(height: 16),
          Text(_status),
          const SizedBox(height: 8),
          if (_total > 0)
            Text(
              '${(_current / _total * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
        ],
      ),
    );
  }
}
