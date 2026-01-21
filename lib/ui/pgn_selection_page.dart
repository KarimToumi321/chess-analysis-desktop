import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../state/chess_controller.dart';
import 'analysis_page.dart';

class PgnSelectionPage extends StatefulWidget {
  const PgnSelectionPage({super.key});

  @override
  State<PgnSelectionPage> createState() => _PgnSelectionPageState();
}

class _PgnSelectionPageState extends State<PgnSelectionPage> {
  final TextEditingController _pgnController = TextEditingController();
  String _fileName = '';

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

  void _startAnalysis() {
    final chess = context.read<ChessController>();
    chess.loadPgn(_pgnController.text.trim());
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AnalysisPage()),
    );
  }

  void _startWithEmptyPosition() {
    final chess = context.read<ChessController>();
    chess.loadPgn('');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AnalysisPage()),
    );
  }
}
