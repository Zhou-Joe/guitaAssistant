import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:guitar_assistant/config/constants.dart';

enum TempoMode { manual, gradual, step, interval }

enum SoundStyle { classic, woodblock, hiihat, cowbell, digital }

const Map<SoundStyle, String> soundAssetNormal = {
  SoundStyle.classic: 'click_classic.wav',
  SoundStyle.woodblock: 'click_woodblock.wav',
  SoundStyle.hiihat: 'click_hihat.wav',
  SoundStyle.cowbell: 'click_cowbell.wav',
  SoundStyle.digital: 'click_digital.wav',
};

const Map<SoundStyle, String> soundAssetAccent = {
  SoundStyle.classic: 'click_classic_accent.wav',
  SoundStyle.woodblock: 'click_woodblock_accent.wav',
  SoundStyle.hiihat: 'click_hihat_accent.wav',
  SoundStyle.cowbell: 'click_cowbell_accent.wav',
  SoundStyle.digital: 'click_digital_accent.wav',
};

const Map<SoundStyle, String> soundDisplayName = {
  SoundStyle.classic: '经典',
  SoundStyle.woodblock: '木鱼',
  SoundStyle.hiihat: '踩镲',
  SoundStyle.cowbell: '牛铃',
  SoundStyle.digital: '电子',
};

class MetronomeProvider extends ChangeNotifier {
  int _bpm = AppConstants.defaultBPM;
  String _timeSignature = AppConstants.defaultTimeSignature;
  TempoMode _tempoMode = TempoMode.manual;
  SoundStyle _soundStyle = SoundStyle.classic;
  bool _isPlaying = false;
  bool _isInitialized = false;
  String? _error;

  // Beat tracking
  int _currentBeat = 0;
  int _beatsPerMeasure = 4;

  // Tempo mode
  int _targetGradualBpm = 120;
  int _beatsAtCurrentBpm = 0;
  final int _beatsPerIncrement = 4;

  // Interval mode
  int _intervalLowBpm = 60;
  int _intervalHighBpm = 100;
  bool _isAtHighInterval = true;

  final AudioPlayer _normalPlayer = AudioPlayer();
  final AudioPlayer _accentPlayer = AudioPlayer();
  Timer? _beatTimer;

  int get bpm => _bpm;
  String get timeSignature => _timeSignature;
  TempoMode get tempoMode => _tempoMode;
  SoundStyle get soundStyle => _soundStyle;
  bool get isPlaying => _isPlaying;
  int get targetGradualBpm => _targetGradualBpm;
  String? get error => _error;
  int get currentBeat => _currentBeat;
  int get beatsPerMeasure => _beatsPerMeasure;

  int _parseTimeSignature(String sig) => int.parse(sig.split('/')[0]);

  Future<void> _loadSounds() async {
    final normal = soundAssetNormal[_soundStyle]!;
    final accent = soundAssetAccent[_soundStyle]!;
    await _normalPlayer.setSource(AssetSource('audio/$normal'));
    await _normalPlayer.setVolume(0.7);
    await _normalPlayer.setReleaseMode(ReleaseMode.stop);
    await _accentPlayer.setSource(AssetSource('audio/$accent'));
    await _accentPlayer.setVolume(1.0);
    await _accentPlayer.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _error = null;
    try {
      await _loadSounds();
      _isInitialized = true;
      debugPrint('Metronome initialized with sound: $soundStyle');
    } catch (e) {
      _error = '初始化失败: $e';
      _isInitialized = false;
      debugPrint('Metronome init error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _reloadSounds() async {
    _isInitialized = false;
    await _normalPlayer.stop();
    await _accentPlayer.stop();
    await _loadSounds();
    _isInitialized = true;
  }

  Future<void> stop() async {
    _beatTimer?.cancel();
    _beatTimer = null;
    _isPlaying = false;
    _currentBeat = 0;
    _beatsAtCurrentBpm = 0;
    await _normalPlayer.stop();
    await _accentPlayer.stop();
    notifyListeners();
  }

  Future<void> setBpm(int bpm) async {
    _bpm = bpm.clamp(AppConstants.minBPM, AppConstants.maxBPM);
    if (_isPlaying) _restartBeatTimer();
    notifyListeners();
  }

  void setTimeSignature(String signature) {
    _timeSignature = signature;
    _beatsPerMeasure = _parseTimeSignature(signature);
    _currentBeat = 0;
    notifyListeners();
  }

  void setSoundStyle(SoundStyle style) {
    if (_soundStyle == style) return;
    _soundStyle = style;
    if (_isPlaying) {
      _reloadSounds().then((_) {
        _restartBeatTimer();
        notifyListeners();
      });
    } else {
      _isInitialized = false;
      notifyListeners();
    }
  }

  void setTempoMode(TempoMode mode) {
    _tempoMode = mode;
    _beatsAtCurrentBpm = 0;
    if (mode == TempoMode.interval) {
      _intervalHighBpm = _bpm;
      _intervalLowBpm = (_bpm ~/ 1.2).clamp(AppConstants.minBPM, AppConstants.maxBPM);
      _isAtHighInterval = true;
    }
    notifyListeners();
  }

  void setTargetGradualBpm(int bpm) {
    _targetGradualBpm = bpm.clamp(AppConstants.minBPM, AppConstants.maxBPM);
    notifyListeners();
  }

  Future<void> _playClick(bool isAccent) async {
    try {
      final player = isAccent ? _accentPlayer : _normalPlayer;
      await player.stop();
      await player.resume();
    } catch (e) {
      debugPrint('Error playing click: $e');
    }
  }

  void _handleBeat() {
    _beatsAtCurrentBpm++;

    switch (_tempoMode) {
      case TempoMode.gradual:
        if (_bpm < _targetGradualBpm && _beatsAtCurrentBpm >= _beatsPerIncrement) {
          _beatsAtCurrentBpm = 0;
          setBpm(_bpm + 1);
        } else if (_bpm > _targetGradualBpm && _beatsAtCurrentBpm >= _beatsPerIncrement) {
          _beatsAtCurrentBpm = 0;
          setBpm(_bpm - 1);
        }
        break;
      case TempoMode.step:
        if (_beatsAtCurrentBpm >= _beatsPerIncrement) {
          _beatsAtCurrentBpm = 0;
          if (_bpm + 5 <= AppConstants.maxBPM) setBpm(_bpm + 5);
        }
        break;
      case TempoMode.interval:
        if (_beatsAtCurrentBpm >= _beatsPerIncrement) {
          _beatsAtCurrentBpm = 0;
          if (_isAtHighInterval) {
            setBpm(_intervalLowBpm);
            _isAtHighInterval = false;
          } else {
            setBpm(_intervalHighBpm);
            _isAtHighInterval = true;
          }
        }
        break;
      case TempoMode.manual:
        break;
    }
  }

  void _startBeatTimer() {
    _beatTimer?.cancel();
    _currentBeat = 0;
    final msPerBeat = (60000 / _bpm).round();
    _beatTimer = Timer.periodic(Duration(milliseconds: msPerBeat), (_) {
      _playClick(_currentBeat == 0);
      _currentBeat = (_currentBeat + 1) % _beatsPerMeasure;
      _handleBeat();
      notifyListeners();
    });
  }

  void _restartBeatTimer() {
    if (_isPlaying) _startBeatTimer();
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      await stop();
      return;
    }

    _error = null;
    notifyListeners();

    try {
      await initialize();
      if (!_isInitialized) {
        _error = '节拍器初始化失败';
        notifyListeners();
        return;
      }

      _beatsPerMeasure = _parseTimeSignature(_timeSignature);
      _currentBeat = 0;
      _isPlaying = true;
      _beatsAtCurrentBpm = 0;

      if (_tempoMode == TempoMode.interval) {
        _intervalHighBpm = _bpm;
        _intervalLowBpm = (_bpm ~/ 1.2).clamp(AppConstants.minBPM, AppConstants.maxBPM);
        _isAtHighInterval = true;
      }

      _startBeatTimer();
      notifyListeners();
    } catch (e) {
      _error = '播放失败: $e';
      _isPlaying = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _beatTimer?.cancel();
    _normalPlayer.dispose();
    _accentPlayer.dispose();
    super.dispose();
  }
}
