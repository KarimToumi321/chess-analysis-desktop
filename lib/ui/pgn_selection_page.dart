import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../state/chess_controller.dart';
import '../state/engine_controller.dart';
import '../services/analysis_service.dart';
import '../models/move_labeling.dart';
import 'analysis_page.dart';

class PgnSelectionPage extends StatefulWidget {
  const PgnSelectionPage({super.key});

  @override
  State<PgnSelectionPage> createState() => _PgnSelectionPageState();
}

class _PgnSelectionPageState extends State<PgnSelectionPage> {
  final TextEditingController _pgnController = TextEditingController();
  String _fileName = '';
  bool _analyzeWithEngine = false;
  int _analysisTimeMs = 500;
  int _engineDepth = 20;
  int _engineMultiPv = 2;
  MoveLabelHarshness _moveLabelHarshness = MoveLabelHarshness.harsh;

  @override
  void initState() {
    super.initState();
    _pgnController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pgnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select PGN'), centerTitle: false),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Load PGN for Analysis',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: _loadPgnFromFile,
                      icon: const Icon(Icons.upload_file_rounded, size: 24),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Choose PGN File',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (_fileName.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Loaded: $_fileName',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    Text(
                      'Or paste PGN text:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pgnController,
                      maxLines: 12,
                      decoration: InputDecoration(
                        hintText:
                            '[Event "..."]\n[Site "..."]\n[Date "..."]\n\n1. e4 e5 2. Nf3 ...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      value: _analyzeWithEngine,
                      onChanged: (value) {
                        setState(() => _analyzeWithEngine = value ?? false);
                      },
                      title: const Text('Analyze with Stockfish'),
                      subtitle: Text(
                        'Evaluate moves and calculate accuracy (${(_analysisTimeMs / 1000).toStringAsFixed(2)}s per move)',
                      ),
                      secondary: const Icon(Icons.speed),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_analyzeWithEngine) ...[
                      const SizedBox(height: 8),
                      DropdownMenu<int>(
                        initialSelection: _analysisTimeMs,
                        label: const Text('Engine time per move'),
                        onSelected: (value) {
                          if (value == null) return;
                          setState(() => _analysisTimeMs = value);
                        },
                        dropdownMenuEntries: const [
                          DropdownMenuEntry(value: 250, label: '0.25s (Fast)'),
                          DropdownMenuEntry(
                            value: 500,
                            label: '0.50s (Accurate)',
                          ),
                          DropdownMenuEntry(
                            value: 1000,
                            label: '1.00s (Very accurate)',
                          ),
                          DropdownMenuEntry(value: 3000, label: '3.00s (Deep)'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownMenu<int>(
                        initialSelection: _engineDepth,
                        label: const Text('Engine search depth'),
                        onSelected: (value) {
                          if (value == null) return;
                          setState(() => _engineDepth = value);
                        },
                        dropdownMenuEntries: const [
                          DropdownMenuEntry(
                            value: 15,
                            label: 'Depth 15 (Fast)',
                          ),
                          DropdownMenuEntry(
                            value: 20,
                            label: 'Depth 20 (Balanced)',
                          ),
                          DropdownMenuEntry(
                            value: 25,
                            label: 'Depth 25 (Accurate)',
                          ),
                          DropdownMenuEntry(
                            value: 30,
                            label: 'Depth 30 (Very Deep)',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownMenu<int>(
                        initialSelection: _engineMultiPv,
                        label: const Text('MultiPV lines'),
                        onSelected: (value) {
                          if (value == null) return;
                          setState(() => _engineMultiPv = value);
                        },
                        dropdownMenuEntries: const [
                          DropdownMenuEntry(value: 1, label: '1 line'),
                          DropdownMenuEntry(
                            value: 2,
                            label: '2 lines (Default)',
                          ),
                          DropdownMenuEntry(value: 3, label: '3 lines'),
                          DropdownMenuEntry(value: 5, label: '5 lines'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownMenu<MoveLabelHarshness>(
                        initialSelection: _moveLabelHarshness,
                        label: const Text('Move labeling harshness'),
                        onSelected: (value) {
                          if (value == null) return;
                          setState(() => _moveLabelHarshness = value);
                        },
                        dropdownMenuEntries: const [
                          DropdownMenuEntry(
                            value: MoveLabelHarshness.harsh,
                            label: 'Harsh',
                          ),
                          DropdownMenuEntry(
                            value: MoveLabelHarshness.extreme,
                            label: 'Extreme',
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _pgnController.clear();
                              setState(() => _fileName = '');
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text('Clear'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _pgnController.text.trim().isEmpty
                                ? null
                                : _startAnalysis,
                            icon: const Icon(Icons.analytics_outlined),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Start Analysis',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _startWithEmptyPosition,
                      icon: const Icon(Icons.add),
                      label: const Text('Start with empty position'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadPgnFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pgn'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final content = String.fromCharCodes(bytes);
    setState(() {
      _pgnController.text = content;
      _fileName = file.name;
    });
  }

  void _startAnalysis() async {
    final chess = context.read<ChessController>();
    chess.setAnalysisSettings(
      analyzeWithEngine: _analyzeWithEngine,
      timePerMove: Duration(milliseconds: _analysisTimeMs),
      moveLabelHarshness: _moveLabelHarshness,
    );
    chess.loadPgn(_pgnController.text.trim());

    // Start analysis if requested
    if (_analyzeWithEngine && chess.moves.isNotEmpty) {
      final analysisCompleted = await _runAnalysis(chess);
      if (!analysisCompleted) return; // Don't navigate if analysis failed
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AnalysisPage()),
      );
    }
  }

  Future<bool> _runAnalysis(ChessController chess) async {
    final engineController = context.read<EngineController>();

    // Ensure engine is loaded and ready
    try {
      await engineController.ensureEngineReady();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start engine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    final analysisService = AnalysisService(engineController.engineService);

    // Show progress dialog
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AnalysisProgressDialog(
        analysisService: analysisService,
        moves: chess.moves,
        timePerMove: Duration(milliseconds: _analysisTimeMs),
        harshness: _moveLabelHarshness,
        onComplete: (analysis) {
          chess.setGameAnalysis(analysis);
        },
      ),
    );

    return result ?? false;
  }

  void _startWithEmptyPosition() {
    final chess = context.read<ChessController>();
    chess.setAnalysisSettings(
      analyzeWithEngine: false,
      timePerMove: const Duration(milliseconds: 500),
      moveLabelHarshness: MoveLabelHarshness.harsh,
    );
    chess.loadPgn('');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AnalysisPage()),
    );
  }
}

class _AnalysisProgressDialog extends StatefulWidget {
  final AnalysisService analysisService;
  final List<String> moves;
  final Duration timePerMove;
  final MoveLabelHarshness harshness;
  final Function(dynamic) onComplete;

  const _AnalysisProgressDialog({
    required this.analysisService,
    required this.moves,
    required this.timePerMove,
    required this.harshness,
    required this.onComplete,
  });

  @override
  State<_AnalysisProgressDialog> createState() =>
      _AnalysisProgressDialogState();
}

class _AnalysisProgressDialogState extends State<_AnalysisProgressDialog> {
  int _current = 0;
  int _total = 0;
  String _status = 'Starting analysis...';

  @override
  void initState() {
    super.initState();
    _total = widget.moves.length;
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      final analysis = await widget.analysisService.analyzeGame(
        moves: widget.moves,
        startingFen: '',
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

      widget.onComplete(analysis);

      if (mounted) {
        setState(() => _status = 'Analysis complete!');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total > 0 ? _current / _total : 0.0;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.analytics),
          SizedBox(width: 12),
          Text('Analyzing Game'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              '${(_current / _total * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
