import 'package:flutter/foundation.dart';
import 'package:metronome/metronome.dart';
import 'package:guitar_assistant/config/constants.dart';

enum TempoMode { manual, gradual, step, interval }

class MetronomeProvider extends ChangeNotifier {
  int _bpm = AppConstants.defaultBPM;
  String _timeSignature = AppConstants.defaultTimeSignature;
  TempoMode _tempoMode = TempoMode.manual;
  bool _isPlaying = false;
  bool _isInitialized = false;

  final Metronome _metronome = Metronome();

  int get bpm => _bpm;
  String get timeSignature => _timeSignature;
  TempoMode get tempoMode => _tempoMode;
  bool get isPlaying => _isPlaying;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _metronome.init('assets/audio/metronome_click.wav');
    _isInitialized = true;
  }

  void setBpm(int bpm) {
    _bpm = bpm.clamp(AppConstants.minBPM, AppConstants.maxBPM);
    notifyListeners();
  }

  void setTimeSignature(String signature) {
    _timeSignature = signature;
    notifyListeners();
  }

  void setTempoMode(TempoMode mode) {
    _tempoMode = mode;
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      _metronome.pause();
    } else {
      await initialize();
      _metronome.play();
    }
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  Future<void> stop() async {
    await _metronome.stop();
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _metronome.destroy();
    super.dispose();
  }
}