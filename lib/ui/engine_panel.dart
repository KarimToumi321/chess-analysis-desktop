import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../state/engine_controller.dart';
import '../state/chess_controller.dart';
import '../services/analysis_service.dart';
import '../models/move_analysis.dart';

class EnginePanel extends StatefulWidget {
  const EnginePanel({super.key});

  @override
  State<EnginePanel> createState() => _EnginePanelState();
}

class _EnginePanelState extends State<EnginePanel> {
  final TextEditingController _enginePath = TextEditingController();
  bool _showLogs = false;

  Future<void> _analyzeAndLabel(
    ChessController chess,
    EngineController engine,
  ) async {
    // Keep existing behavior (position evaluation) and add a move label.
    // Stop any running analysis to avoid interleaving UCI commands.
    if (engine.isAnalyzing) {
      engine.stopAnalysis();
    }

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

      if (ma != null) {
        chess.upsertMoveAnalysis(ma);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Move labeled: ${_labelFor(ma.classification)}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
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
    } finally {
      // Start the live analysis after labeling (sequential).
      if (!engine.isBusy) {
        engine.analyzePosition(chess.fen);
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
  void dispose() {
    _enginePath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<EngineController>();
    final chess = context.watch<ChessController>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _enginePath,
              decoration: const InputDecoration(
                labelText: 'Stockfish path',
                hintText: 'Select Stockfish executable',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickEngine(engine),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Select engine'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: engine.isBusy
                        ? null
                        : () => engine.useCustomEngine(_enginePath.text.trim()),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Use path'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: engine.isBusy
                      ? null
                      : () => engine.useBundledEngine(),
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Use bundled Stockfish'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: engine.isBusy
                        ? null
                        : () => _analyzeAndLabel(chess, engine),
                    icon: engine.isAnalyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics_outlined),
                    label: Text(
                      engine.isAnalyzing ? 'Analyzing...' : 'Analyze Position',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                if (engine.isAnalyzing) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => engine.stopAnalysis(),
                    icon: const Icon(Icons.stop_circle_outlined),
                    tooltip: 'Stop analysis',
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: engine.errorMessage != null
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    engine.errorMessage != null
                        ? Icons.error_outline
                        : Icons.info_outline,
                    size: 16,
                    color: engine.errorMessage != null
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      engine.status,
                      style: TextStyle(
                        fontSize: 12,
                        color: engine.errorMessage != null
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (engine.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bug_report,
                          size: 16,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Error Details:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      engine.errorMessage!,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (engine.lastBestMove != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Best move: ${engine.lastBestMove}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            if (engine.lastInfo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  engine.lastInfo!,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _showLogs = !_showLogs),
                  icon: Icon(_showLogs ? Icons.expand_less : Icons.expand_more),
                  label: Text(_showLogs ? 'Hide Logs' : 'Show Engine Logs'),
                ),
                if (engine.engineLogs.isNotEmpty)
                  Text(
                    ' (${engine.engineLogs.length})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
            if (_showLogs && engine.engineLogs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                height: 200,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: engine.engineLogs.length,
                  itemBuilder: (context, index) {
                    final log = engine.engineLogs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: log.contains('❌')
                              ? Colors.red.shade300
                              : log.contains('✓') || log.contains('✅')
                              ? Colors.green.shade300
                              : log.contains('⚠️')
                              ? Colors.orange.shade300
                              : Colors.white70,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickEngine(EngineController engine) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    _enginePath.text = file.path!;
    engine.useCustomEngine(file.path!);
  }
}
