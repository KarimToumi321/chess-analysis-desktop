import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../state/chess_controller.dart';
import '../state/engine_controller.dart';
import 'board_view.dart';
import 'move_list.dart';
import 'engine_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _pgnController = TextEditingController();
  final TextEditingController _fenController = TextEditingController();
  final FocusNode _fenFocus = FocusNode();
  String _lastFen = '';

  @override
  void dispose() {
    _pgnController.dispose();
    _fenController.dispose();
    _fenFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chess = context.watch<ChessController>();
    final engine = context.watch<EngineController>();

    _syncFenText(chess.fen);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Desktop'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Analyze current position',
            onPressed: engine.isBusy
                ? null
                : () => engine.analyzePosition(chess.fen),
            icon: const Icon(Icons.analytics_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          final children = <Widget>[
            _buildLeftPane(context, chess),
            _buildRightPane(context, chess),
          ];

          return Padding(
            padding: const EdgeInsets.all(20),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: children[0]),
                      const SizedBox(width: 20),
                      SizedBox(width: 420, child: children[1]),
                    ],
                  )
                : ListView(
                    children: [
                      children[0],
                      const SizedBox(height: 16),
                      children[1],
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildLeftPane(BuildContext context, ChessController chess) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Board',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                BoardView(fen: chess.fen),
                const SizedBox(height: 16),
                _buildNavigation(chess),
                const SizedBox(height: 12),
                _buildFenSection(chess),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildPgnSection(chess),
      ],
    );
  }

  Widget _buildRightPane(BuildContext context, ChessController chess) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Moves',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: SizedBox(
            height: 380,
            child: MoveList(
              moves: chess.moves,
              currentIndex: chess.currentIndex,
              onSelect: chess.setIndex,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Engine',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const EnginePanel(),
      ],
    );
  }

  Widget _buildNavigation(ChessController chess) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Start',
          onPressed: chess.goToStart,
          icon: const Icon(Icons.first_page_rounded),
        ),
        IconButton(
          tooltip: 'Previous',
          onPressed: chess.previous,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text('${chess.currentIndex} / ${chess.moves.length}'),
        IconButton(
          tooltip: 'Next',
          onPressed: chess.next,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        IconButton(
          tooltip: 'End',
          onPressed: chess.goToEnd,
          icon: const Icon(Icons.last_page_rounded),
        ),
        const Spacer(),
        if (chess.error != null)
          Text(chess.error!, style: const TextStyle(color: Colors.redAccent)),
      ],
    );
  }

  Widget _buildFenSection(ChessController chess) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FEN sync', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _fenController,
          focusNode: _fenFocus,
          minLines: 1,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Paste a FEN to sync the board',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => chess.loadFen(_fenController.text.trim()),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Apply FEN'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {
                final fen = chess.fen;
                _fenController.text = fen;
                _fenController.selection = TextSelection.collapsed(
                  offset: fen.length,
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy FEN'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPgnSection(ChessController chess) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'PGN loader',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _loadPgnFromFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Open PGN file'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pgnController,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(hintText: 'Paste PGN here'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => chess.loadPgn(_pgnController.text),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Load PGN'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    _pgnController.clear();
                    chess.loadPgn('');
                  },
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
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
    if (!mounted) return;
    setState(() => _pgnController.text = content);
  }

  void _syncFenText(String fen) {
    if (_fenFocus.hasFocus) return;
    if (fen == _lastFen) return;
    _lastFen = fen;
    _fenController.text = fen;
    _fenController.selection = TextSelection.collapsed(offset: fen.length);
  }
}
