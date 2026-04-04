import 'package:flutter/foundation.dart';
import 'package:metronome/metronome.dart';
import 'package:guitar_assistant/config/constants.dart';

enum TempoMode { manual, gradual, step, interval }

class MetronomeProvider extends ChangeNotifier {
  int _bpm = AppConstants.defaultBPM;
  String _timeSignature = AppConstants.defaultTimeSignature;
  TempoMode _tempoMode = TempoMode.manual;
  bool _isPlaying = false;
  int _targetGradualBpm = 0;
  int _gradualIncrement = 5;

  final Metronome _metronome = Metronome();

  int get bpm => _bpm;
  String get timeSignature => _timeSignature;
  TempoMode get tempoMode => _tempoMode;
  bool get isPlaying => _isPlaying;

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

  void togglePlay() {
    if (_isPlaying) {
      _metronome.stop();
    } else {
      _metronome.start(_bpm);
    }
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void stop() {
    _metronome.stop();
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _metronome.dispose();
    super.dispose();
  }
}