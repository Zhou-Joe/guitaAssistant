import 'package:flutter/foundation.dart';
import 'package:guitar_assistant/services/pitch_service.dart';
import 'package:guitar_assistant/config/constants.dart';

class TunerProvider extends ChangeNotifier {
  final PitchService _pitchService = PitchService();
  double _currentFrequency = 0;
  String _detectedNote = '';
  double _cents = 0;
  int _nearestStringIndex = 0;
  bool _isListening = false;

  double get currentFrequency => _currentFrequency;
  String get detectedNote => _detectedNote;
  double get cents => _cents;
  int get nearestStringIndex => _nearestStringIndex;
  String get nearestStringNote => AppConstants.guitarStringNotes[_nearestStringIndex];
  bool get isListening => _isListening;
  bool get isInTune => _cents.abs() <= AppConstants.defaultTunerTolerance;

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    _pitchService.startListening();
    _pitchService.pitchStream.listen((freq) {
      _currentFrequency = freq;
      _nearestStringIndex = _pitchService.getNearestStringIndex(freq);
      notifyListeners();
    });
    _pitchService.noteStream.listen((note) {
      _detectedNote = note;
      notifyListeners();
    });
    _pitchService.centsStream.listen((cents) {
      _cents = cents;
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
    notifyListeners();
  }

  @override
  void dispose() {
    _pitchService.dispose();
    super.dispose();
  }
}
