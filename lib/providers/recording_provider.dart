import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:guitar_assistant/data/models/recording.dart';
import 'package:guitar_assistant/data/repositories/recording_repository.dart';
import 'package:guitar_assistant/services/audio_service.dart';

class RecordingProvider extends ChangeNotifier {
  final RecordingRepository _repository = RecordingRepository();
  final AudioService _audioService = AudioService();

  List<Recording> _recordings = [];
  bool _isRecording = false;
  bool _isLoading = false;
  RecordingMode _mode = RecordingMode.audio;
  int _recordingDuration = 0;
  Timer? _timer;

  List<Recording> get recordings => _recordings;
  bool get isRecording => _isRecording;
  bool get isLoading => _isLoading;
  RecordingMode get mode => _mode;
  int get recordingDuration => _recordingDuration;

  Future<void> initialize() async {
    await _repository.initialize();
    await loadRecordings();
  }

  Future<void> loadRecordings() async {
    _isLoading = true;
    notifyListeners();
    _recordings = await _repository.getAll();
    _isLoading = false;
    notifyListeners();
  }

  void setMode(RecordingMode mode) {
    _mode = mode;
    notifyListeners();
  }

  Future<void> startRecording() async {
    await _audioService.startRecording();
    _isRecording = true;
    _recordingDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration++;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> stopRecording() async {
    _timer?.cancel();
    await _audioService.stopRecording();
    _isRecording = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
