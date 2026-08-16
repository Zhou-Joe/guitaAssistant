import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:guitar_assistant/data/models/recording.dart';
import 'package:guitar_assistant/data/repositories/recording_repository.dart';
import 'package:guitar_assistant/services/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

class RecordingProvider extends ChangeNotifier {
  final RecordingRepository _repository = RecordingRepository();
  final AudioService _audioService = AudioService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Recording> _recordings = [];
  bool _isRecording = false;
  bool _isLoading = false;
  RecordingMode _mode = RecordingMode.audio;
  int _recordingDuration = 0;
  Timer? _timer;

  // Playback state
  String? _currentlyPlayingId;
  bool _isPlaying = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  List<Recording> get recordings => _recordings;
  bool get isRecording => _isRecording;
  bool get isLoading => _isLoading;
  RecordingMode get mode => _mode;
  int get recordingDuration => _recordingDuration;
  String? get currentlyPlayingId => _currentlyPlayingId;
  bool get isPlaying => _isPlaying;
  Duration get playbackPosition => _playbackPosition;
  Duration get playbackDuration => _playbackDuration;

  RecordingProvider() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _playbackPosition = position;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      _playbackDuration = duration;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _currentlyPlayingId = null;
      _playbackPosition = Duration.zero;
      notifyListeners();
    });
  }

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

  Future<void> deleteRecording(String id, String filePath) async {
    // Delete from repository
    await _repository.delete(id);

    // Delete the file from filesystem
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }

    // Stop playback if this recording was playing
    if (_currentlyPlayingId == id) {
      await stopPlayback();
    }

    // Reload recordings list
    await loadRecordings();
  }

  Future<void> playRecording(String id, String filePath) async {
    // If something else is playing, stop it first
    if (_currentlyPlayingId != null && _currentlyPlayingId != id) {
      await _audioPlayer.stop();
    }

    // If this recording is already playing, pause it
    if (_currentlyPlayingId == id && _isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    // If this recording is paused, resume it
    if (_currentlyPlayingId == id && !_isPlaying) {
      await _audioPlayer.resume();
      return;
    }

    // Play new recording
    _currentlyPlayingId = id;
    _playbackPosition = Duration.zero;
    await _audioPlayer.play(DeviceFileSource(filePath));
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
    _currentlyPlayingId = null;
    _isPlaying = false;
    _playbackPosition = Duration.zero;
    notifyListeners();
  }

  Future<void> seekPlayback(Duration position) async {
    await _audioPlayer.seek(position);
    _playbackPosition = position;
    notifyListeners();
  }

  bool isRecordingPlaying(String id) {
    return _currentlyPlayingId == id && _isPlaying;
  }

  double getPlaybackProgress(String id) {
    if (_currentlyPlayingId != id || _playbackDuration.inMilliseconds == 0) {
      return 0.0;
    }
    return _playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
