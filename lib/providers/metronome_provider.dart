import 'dart:async';
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

  // Gradual BPM change settings
  int _targetGradualBpm = 120;
  int _gradualIncrement = 1;
  int _beatsAtCurrentBpm = 0;
  int _beatsPerIncrement = 4; // Change BPM every 4 beats

  final Metronome _metronome = Metronome();
  Timer? _tempoChangeTimer;

  int get bpm => _bpm;
  String get timeSignature => _timeSignature;
  TempoMode get tempoMode => _tempoMode;
  bool get isPlaying => _isPlaying;
  int get targetGradualBpm => _targetGradualBpm;

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
    _beatsAtCurrentBpm = 0;
    notifyListeners();
  }

  void setTargetGradualBpm(int bpm) {
    _targetGradualBpm = bpm.clamp(AppConstants.minBPM, AppConstants.maxBPM);
    notifyListeners();
  }

  void _handleBeat() {
    _beatsAtCurrentBpm++;

    switch (_tempoMode) {
      case TempoMode.gradual:
        // Gradually increase/decrease BPM towards target
        if (_bpm != _targetGradualBpm) {
          if (_bpm < _targetGradualBpm) {
            setBpm(_bpm + 1);
          } else if (_bpm > _targetGradualBpm) {
            setBpm(_bpm - 1);
          }
        }
        break;

      case TempoMode.step:
        // Increase BPM by 5 every 4 beats
        if (_beatsAtCurrentBpm >= _beatsPerIncrement) {
          _beatsAtCurrentBpm = 0;
          if (_bpm + 5 <= AppConstants.maxBPM) {
            setBpm(_bpm + 5);
          }
        }
        break;

      case TempoMode.interval:
        // Alternate between two BPMs every 4 beats
        final lowBpm = (_bpm ~/ 1.2).clamp(AppConstants.minBPM, AppConstants.maxBPM);
        final highBpm = _bpm;
        if (_beatsAtCurrentBpm >= _beatsPerIncrement) {
          _beatsAtCurrentBpm = 0;
          // Toggle between low and high BPM
          if (_bpm == highBpm) {
            setBpm(lowBpm);
          } else {
            setBpm(highBpm);
          }
        }
        break;

      case TempoMode.manual:
        // No automatic changes
        break;
    }
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      _metronome.pause();
      _tempoChangeTimer?.cancel();
      _tempoChangeTimer = null;
    } else {
      await initialize();
      _metronome.play();
      _beatsAtCurrentBpm = 0;

      // Start tempo change timer for non-manual modes
      if (_tempoMode != TempoMode.manual) {
        _startTempoChangeTimer();
      }
    }
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void _startTempoChangeTimer() {
    // Calculate interval based on current BPM (60 seconds / BPM = seconds per beat)
    final interval = Duration(milliseconds: ((60000 / _bpm) * _beatsPerIncrement).round());
    _tempoChangeTimer?.cancel();
    _tempoChangeTimer = Timer.periodic(interval, (_) {
      _handleBeat();
      // Update timer interval as BPM changes
      final newInterval = Duration(milliseconds: ((60000 / _bpm) * _beatsPerIncrement).round());
      _tempoChangeTimer?.cancel();
      _tempoChangeTimer = Timer.periodic(newInterval, (_) {
        _handleBeat();
      });
    });
  }

  Future<void> stop() async {
    await _metronome.stop();
    _tempoChangeTimer?.cancel();
    _tempoChangeTimer = null;
    _isPlaying = false;
    _beatsAtCurrentBpm = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _tempoChangeTimer?.cancel();
    _metronome.destroy();
    super.dispose();
  }
}