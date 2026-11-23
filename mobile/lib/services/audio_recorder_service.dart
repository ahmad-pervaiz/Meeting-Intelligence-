import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService extends ChangeNotifier {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDurationSeconds = 0;
  Timer? _timer;
  String? _currentFilePath;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  int get recordDurationSeconds => _recordDurationSeconds;
  String? get currentFilePath => _currentFilePath;

  String get formattedDuration {
    final minutes = (_recordDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordDurationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        throw Exception("Microphone permission not granted");
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentFilePath = path;

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _audioRecorder.start(config, path: path);

      _isRecording = true;
      _isPaused = false;
      _recordDurationSeconds = 0;
      _startTimer();
      notifyListeners();
    } catch (e) {
      debugPrint("Error starting recording: $e");
      rethrow;
    }
  }

  Future<void> pauseRecording() async {
    if (_isRecording && !_isPaused) {
      await _audioRecorder.pause();
      _isPaused = true;
      _timer?.cancel();
      notifyListeners();
    }
  }

  Future<void> resumeRecording() async {
    if (_isRecording && _isPaused) {
      await _audioRecorder.resume();
      _isPaused = false;
      _startTimer();
      notifyListeners();
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _timer?.cancel();
    final path = await _audioRecorder.stop();
    _isRecording = false;
    _isPaused = false;
    notifyListeners();

    return path ?? _currentFilePath;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordDurationSeconds++;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}
