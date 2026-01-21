import 'dart:async';
import 'dart:convert';
import 'dart:io';

class EngineService {
  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  final StreamController<String> _lines = StreamController.broadcast();
  final List<String> _logs = [];

  Stream<String> get lines => _lines.stream;
  bool get isRunning => _process != null;
  List<String> get logs => List.unmodifiable(_logs);

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    _logs.add(logMessage);
    print(logMessage); // Also print to console
  }

  Future<void> start(String enginePath) async {
    if (_process != null) {
      _log('⚠️ Engine already running');
      return;
    }

    _log('🚀 Starting engine: $enginePath');

    // Check if file exists
    final file = File(enginePath);
    if (!file.existsSync()) {
      _log('❌ Engine file not found: $enginePath');
      throw Exception('Engine file not found: $enginePath');
    }

    _log('✓ Engine file exists');

    try {
      _process = await Process.start(enginePath, []);
      _log('✓ Process started (PID: ${_process!.pid})');

      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              _log('STDOUT: $line');
              _lines.add(line);
            },
            onError: (error) {
              _log('❌ STDOUT error: $error');
            },
          );

      _stderrSub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              _log('STDERR: $line');
              _lines.add(line);
            },
            onError: (error) {
              _log('❌ STDERR error: $error');
            },
          );

      _log('📤 Sending: uci');
      _send('uci');

      _log('⏳ Waiting for uciok...');
      await _waitFor('uciok', timeout: const Duration(seconds: 5));
      _log('✓ Received uciok');

      _log('📤 Sending: isready');
      _send('isready');

      _log('⏳ Waiting for readyok...');
      await _waitFor('readyok', timeout: const Duration(seconds: 5));
      _log('✓ Received readyok - Engine initialized successfully');
    } catch (e) {
      _log('❌ Failed to start engine: $e');
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    _log('🛑 Stopping engine...');
    _send('quit');
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _process?.kill();
    _process = null;
    _log('✓ Engine stopped');
  }

  Future<String?> bestMove(String fen, {int depth = 15}) async {
    if (_process == null) {
      _log('❌ Cannot get best move: Engine not running');
      return null;
    }

    _log('🎯 Getting best move for position (depth: $depth)');
    _log('📤 Sending: ucinewgame');
    _send('ucinewgame');

    _log('📤 Sending: position fen $fen');
    _send('position fen $fen');

    _log('📤 Sending: go depth $depth');
    _send('go depth $depth');

    try {
      _log('⏳ Waiting for bestmove...');
      final line = await _waitFor(
        'bestmove',
        timeout: const Duration(seconds: 30),
      );
      _log('✓ Received: $line');

      final parts = line.split(' ');
      final index = parts.indexOf('bestmove');
      if (index >= 0 && index + 1 < parts.length) {
        final move = parts[index + 1];
        _log('✓ Best move: $move');
        return move;
      }
    } catch (e) {
      _log('❌ Error getting best move: $e');
      return null;
    }
    return null;
  }

  void startContinuousAnalysis(String fen) {
    if (_process == null) {
      _log('❌ Cannot start analysis: Engine not running');
      return;
    }

    _log('🔄 Starting continuous analysis');
    _log('📤 Sending: ucinewgame');
    _send('ucinewgame');

    _log('📤 Sending: position fen $fen');
    _send('position fen $fen');

    _log('📤 Sending: go infinite');
    _send('go infinite');
  }

  void stopAnalysis() {
    if (_process == null) return;
    _log('⏸️ Stopping analysis');
    _log('📤 Sending: stop');
    _send('stop');
  }

  void analyzeForTime(String fen, int milliseconds) {
    if (_process == null) {
      _log('❌ Cannot analyze: Engine not running');
      return;
    }

    _log('⏱️ Analyzing for $milliseconds ms');
    _log('📤 Sending: ucinewgame');
    _send('ucinewgame');

    _log('📤 Sending: position fen $fen');
    _send('position fen $fen');

    _log('📤 Sending: go movetime $milliseconds');
    _send('go movetime $milliseconds');
  }

  void _send(String command) {
    try {
      _process?.stdin.writeln(command);
    } catch (e) {
      _log('❌ Error sending command: $e');
    }
  }

  Future<String> _waitFor(String token, {required Duration timeout}) async {
    final completer = Completer<String>();
    late StreamSubscription<String> sub;
    sub = lines.listen((line) {
      if (line.contains(token)) {
        completer.complete(line);
        sub.cancel();
      }
    });

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        sub.cancel();
        throw TimeoutException('Engine timeout waiting for $token');
      },
    );
  }
}
