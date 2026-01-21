import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

class EngineService {
  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  final StreamController<String> _lines = StreamController.broadcast();
  final List<String> _logs = [];

  final bool _logToConsole;
  final bool _traceUciTraffic;

  EngineService({bool logToConsole = false, bool traceUciTraffic = false})
    : _logToConsole = logToConsole,
      _traceUciTraffic = traceUciTraffic;

  Stream<String> get lines => _lines.stream;
  bool get isRunning => _process != null;
  List<String> get logs => List.unmodifiable(_logs);

  void _log(String message, {bool isUciTraffic = false}) {
    if (isUciTraffic && !_traceUciTraffic) return;
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    _logs.add(logMessage);
    if (_logToConsole) {
      developer.log(logMessage, name: 'EngineService');
    }
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
              _log('STDOUT: $line', isUciTraffic: true);
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
              _log('STDERR: $line', isUciTraffic: true);
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

  Future<Map<String, dynamic>?> analyzePosition(
    String fen,
    Duration timePerMove,
  ) async {
    if (_process == null) {
      _log('❌ Cannot analyze: Engine not running');
      return null;
    }

    _log('🔍 Analyzing position (time: ${timePerMove.inMilliseconds}ms)');
    _send('ucinewgame');
    _send('position fen $fen');
    _send('go movetime ${timePerMove.inMilliseconds}');

    try {
      String? lastInfoWithScore;
      String? bestMove;

      final completer = Completer<void>();
      late StreamSubscription<String> subscription;

      subscription = lines.listen((line) {
        if (line.startsWith('info') && line.contains('score')) {
          lastInfoWithScore = line;
        } else if (line.startsWith('bestmove')) {
          final parts = line.split(' ');
          final index = parts.indexOf('bestmove');
          if (index >= 0 && index + 1 < parts.length) {
            bestMove = parts[index + 1];
          }
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      });

      // Wait for bestmove with timeout
      await completer.future.timeout(
        timePerMove + const Duration(seconds: 2),
        onTimeout: () {
          _log('⏱️ Timeout waiting for analysis');
        },
      );

      await subscription.cancel();

      // Combine results
      final result = <String, dynamic>{};
      if (bestMove != null) {
        result['bestmove'] = bestMove;
      }
      if (lastInfoWithScore != null) {
        final score = _parseScore(lastInfoWithScore!);
        if (score != null) {
          result.addAll(score);
        }
      }

      return result.isNotEmpty ? result : null;
    } catch (e) {
      _log('❌ Error analyzing position: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBestMove(
    String fen,
    Duration timePerMove,
  ) async {
    // Use the combined analysis method for efficiency
    final result = await analyzePosition(fen, timePerMove);
    if (result == null) return null;
    return {'bestmove': result['bestmove']};
  }

  Future<Map<String, dynamic>?> getEvaluation(
    String fen,
    Duration timePerMove,
  ) async {
    // Use the combined analysis method for efficiency
    final result = await analyzePosition(fen, timePerMove);
    if (result == null) return null;

    final evaluation = <String, dynamic>{};
    if (result.containsKey('cp')) {
      evaluation['cp'] = result['cp'];
    }
    if (result.containsKey('mate')) {
      evaluation['mate'] = result['mate'];
    }
    return evaluation.isNotEmpty ? evaluation : null;
  }

  Map<String, dynamic>? _parseScore(String infoLine) {
    // Parse: info depth 20 score cp 25 nodes 1234 ...
    // or: info depth 20 score mate 3 nodes 1234 ...
    final parts = infoLine.split(' ');

    for (var i = 0; i < parts.length; i++) {
      if (parts[i] == 'score' && i + 2 < parts.length) {
        final scoreType = parts[i + 1];
        final scoreValue = int.tryParse(parts[i + 2]);

        if (scoreValue != null) {
          if (scoreType == 'cp') {
            return {'cp': scoreValue};
          } else if (scoreType == 'mate') {
            return {'mate': scoreValue};
          }
        }
      }
    }
    return null;
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
