import 'package:flutter/foundation.dart';
import 'package:guitar_assistant/services/pitch_service.dart';
import 'package:guitar_assistant/config/constants.dart';

class TunerProvider extends ChangeNotifier {
  final PitchService _pitchService = PitchService();
  double _currentFrequency = 0;
  String _detectedNote = '';
  double _cents = 0;
  int _nearestStringIndex = 0;
  int? _selectedStringIndex; // 用户选择的琴弦
  bool _isListening = false;
  bool _isInTune = false;

  double get currentFrequency => _currentFrequency;
  String get detectedNote => _detectedNote;
  double get cents => _cents;
  int get nearestStringIndex => _nearestStringIndex;
  String get nearestStringNote => AppConstants.guitarStringNotes[_nearestStringIndex];
  int? get selectedStringIndex => _selectedStringIndex;
  bool get isListening => _isListening;
  bool get isInTune => _isInTune;

  // 获取目标琴弦的频率
  double? get targetFrequency =>
      _selectedStringIndex != null
          ? AppConstants.guitarStringFrequencies[_selectedStringIndex!]
          : null;

  // 获取目标琴弦的音符
  String? get targetNote =>
      _selectedStringIndex != null
          ? AppConstants.guitarStringNotes[_selectedStringIndex!]
          : null;

  void setSelectedString(int? index) {
    _selectedStringIndex = index;
    _pitchService.setTargetString(index);
    notifyListeners();
  }

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    _pitchService.startListening();

    // 监听音高数据
    _pitchService.pitchStream.listen((freq) {
      _currentFrequency = freq;
      if (_selectedStringIndex != null) {
        _nearestStringIndex = _selectedStringIndex!;
      } else {
        _nearestStringIndex = _pitchService.getNearestStringIndex(freq);
      }
      notifyListeners();
    });

    _pitchService.noteStream.listen((note) {
      _detectedNote = note;
      notifyListeners();
    });

    _pitchService.centsStream.listen((cents) {
      _cents = cents;
      _isInTune = cents.abs() <= AppConstants.defaultTunerTolerance;
      notifyListeners();
    });
  }

  void stopListening() {
    if (!_isListening) return;
    _pitchService.stopListening();
    _isListening = false;
    _currentFrequency = 0;
    _detectedNote = '';
    _cents = 0;
    _isInTune = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _pitchService.dispose();
    super.dispose();
  }
}
