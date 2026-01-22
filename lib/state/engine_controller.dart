import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/engine_service.dart';

class EngineController extends ChangeNotifier {
  final EngineService _engine = EngineService();

  String? _enginePath;
  String _status = 'No engine loaded';
  String? _errorMessage;
  String? _lastBestMove;
  String? _lastInfo;
  bool _isBusy = false;
  bool _isAnalyzing = false;

  // Real-time evaluation fields
  double? _currentEvaluation;
  int? _currentDepth;
  Timer? _evaluationTimer;
  StreamSubscription<String>? _lineSub;
  String? _currentFen; // Store FEN to check whose turn it is

  String get status => _status;
  String? get errorMessage => _errorMessage;
  String? get lastBestMove => _lastBestMove;
  String? get lastInfo => _lastInfo;
  bool get isBusy => _isBusy;
  bool get isAnalyzing => _isAnalyzing;
  double? get currentEvaluation => _currentEvaluation;
  int? get currentDepth => _currentDepth;
  List<String> get engineLogs => _engine.logs;
  EngineService get engineService => _engine;

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  Future<void> useCustomEngine(String path) async {
    _setBusy(true);
    try {
      _enginePath = path;
      _status = 'Engine loaded: $path';
      _errorMessage = null;
      await _testEngine();
    } catch (e) {
      _errorMessage = e.toString();
      _status = 'Failed to load engine';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> useBundledEngine() async {
    print('🎮 Loading bundled Stockfish...');
    _setBusy(true);
    try {
      // Look for bundled Stockfish - use path directly from assets folder
      // When running locally, this points to assets/stockfish/stockfish.exe
      final exePath = 'assets/stockfish/stockfish.exe';
      print('📁 Looking for engine at: $exePath');

      _enginePath = exePath;
      _status = 'Starting bundled engine...';
      _errorMessage = null;
      notifyListeners();

      // Start the engine directly without stopping it
      await _engine.start(_enginePath!);
      print('✅ Bundled Stockfish started successfully');

      _status = 'Bundled Stockfish ready';
      _errorMessage = null;
    } catch (e) {
      print('❌ Failed to load bundled engine: $e');
      _errorMessage = e.toString();
      _status = 'Failed to load bundled engine';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> ensureEngineReady() async {
    if (_engine.isRunning) {
      print('✓ Engine already running');
      return;
    }

    if (_enginePath == null || _enginePath!.isEmpty) {
      print('🚀 No engine loaded, loading bundled Stockfish...');
      await useBundledEngine();
    } else {
      print('🚀 Starting engine at: $_enginePath');
      await _engine.start(_enginePath!);
      _status = 'Engine ready';
      notifyListeners();
    }
  }

  Future<void> _testEngine() async {
    if (_enginePath == null || _enginePath!.isEmpty) {
      throw Exception('No engine path specified');
    }

    try {
      print('🧪 Testing engine at: $_enginePath');
      _status = 'Testing engine...';
      notifyListeners();

      await _engine.start(_enginePath!);
      print('✅ Engine test successful');

      _status = 'Engine ready';
      _errorMessage = null;

      await _engine.stop();
    } catch (e) {
      print('❌ Engine test failed: $e');
      _status = 'Engine test failed';
      _errorMessage = 'Engine failed to start: $e';
    }
  }

  Future<void> analyzePosition(String fen) async {
    if (_enginePath == null || _enginePath!.isEmpty) {
      print('❌ No engine path set');
      _status = 'No engine loaded. Click "Use bundled Stockfish" first.';
      _errorMessage = 'Engine path not set';
      notifyListeners();
      return;
    }

    // Stop any existing analysis first
    if (_isAnalyzing) {
      print('⏹️ Stopping previous analysis...');
      _isAnalyzing = false;
      _engine.stopAnalysis();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Cancel any existing stream subscription
    _lineSub?.cancel();
    _lineSub = null;

    print('🚀 Starting real-time position analysis...');
    print('📁 Engine path: $_enginePath');
    print('♟️  FEN: $fen');

    // Store the FEN to check whose turn it is
    _currentFen = fen;

    _setBusy(true);
    _isAnalyzing = true;
    _status = 'Starting analysis...';
    _lastBestMove = null;
    _lastInfo = null;
    _errorMessage = null;
    _currentEvaluation = null;
    _currentDepth = null;
    notifyListeners();

    try {
      print('🚀 Starting engine...');
      await _engine.start(_enginePath!);
      print('✓ Engine started');

      _listenToEngine();

      // Start with quick evaluation (200ms)
      print('⚡ Quick analysis (200ms)...');
      _status = 'Quick analysis...';
      notifyListeners();
      _engine.analyzeForTime(fen, 200);

      // Schedule deeper analysis after 250ms
      await Future.delayed(const Duration(milliseconds: 250));
      if (!_isAnalyzing) return;

      print('🔍 Medium analysis (1s)...');
      _status = 'Analyzing...';
      notifyListeners();
      _engine.analyzeForTime(fen, 1000);

      // Schedule even deeper analysis after 1.1s more
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!_isAnalyzing) return;

      print('🎯 Deep analysis (3s)...');
      _status = 'Deep analysis...';
      notifyListeners();
      _engine.analyzeForTime(fen, 3000);

      // Wait for deep analysis to complete
      await Future.delayed(const Duration(milliseconds: 3200));
      if (!_isAnalyzing) return;

      _status = 'Analysis complete';
      print('✅ Analysis complete');
    } catch (e, stackTrace) {
      print('❌ Analysis error: $e');
      print('Stack trace: $stackTrace');
      _status = 'Analysis failed';
      _errorMessage = 'Error: $e';
    } finally {
      _isAnalyzing = false;
      _setBusy(false);
      // Stop the engine after analysis
      await _engine.stop();
      _lineSub?.cancel();
      _lineSub = null;
    }
  }

  void stopAnalysis() {
    print('⏹️ Stopping analysis...');
    _isAnalyzing = false;
    _evaluationTimer?.cancel();
    _engine.stopAnalysis();
    _status = 'Analysis stopped';
    _setBusy(false);
    notifyListeners();
  }

  void _listenToEngine() {
    _lineSub?.cancel();
    _lineSub = _engine.lines.listen((line) {
      if (line.startsWith('info ')) {
        _parseDepth(line);
        _parseEvaluation(line);
        notifyListeners();
      } else if (line.startsWith('bestmove ')) {
        _parseBestMove(line);
        notifyListeners();
      }
    });
  }

  void _parseDepth(String infoLine) {
    final depthMatch = RegExp(r'depth (\d+)').firstMatch(infoLine);
    if (depthMatch != null) {
      _currentDepth = int.tryParse(depthMatch.group(1) ?? '0');
    }
  }

  void _parseEvaluation(String infoLine) {
    // Parse centipawn evaluation
    final cpMatch = RegExp(r'score cp (-?\d+)').firstMatch(infoLine);
    if (cpMatch != null) {
      final centipawns = int.tryParse(cpMatch.group(1) ?? '0') ?? 0;
      var evaluation = centipawns / 100.0;

      // Check whose turn it is from the FEN
      // If it's Black to move (White just moved), flip the sign
      if (_currentFen != null && !_isWhiteToMove(_currentFen!)) {
        evaluation = -evaluation;
      }

      _currentEvaluation = evaluation;
      return;
    }

    // Parse mate score
    final mateMatch = RegExp(r'score mate (-?\d+)').firstMatch(infoLine);
    if (mateMatch != null) {
      final mateIn = int.tryParse(mateMatch.group(1) ?? '0') ?? 0;
      var evaluation = mateIn > 0 ? 10000.0 : -10000.0;

      // Flip if Black to move
      if (_currentFen != null && !_isWhiteToMove(_currentFen!)) {
        evaluation = -evaluation;
      }

      _currentEvaluation = evaluation;
    }
  }

  bool _isWhiteToMove(String fen) {
    // FEN format: position w/b ...
    final parts = fen.split(' ');
    if (parts.length < 2) return true; // Default to white
    return parts[1] == 'w';
  }

  void _parseBestMove(String line) {
    // Parse: bestmove e2e4 ponder e7e5
    final parts = line.split(' ');
    final index = parts.indexOf('bestmove');
    if (index >= 0 && index + 1 < parts.length) {
      final move = parts[index + 1];
      if (move != '(none)') {
        _lastBestMove = move;
      }
    }
  }

  @override
  void dispose() {
    _evaluationTimer?.cancel();
    _lineSub?.cancel();
    super.dispose();
  }
}
