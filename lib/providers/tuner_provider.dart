import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:guitar_assistant/services/pitch_service.dart';
import 'package:guitar_assistant/config/constants.dart';

class TunerProvider extends ChangeNotifier {
  final PitchService _pitchService = PitchService();

  // Stream subscriptions for proper cleanup
  StreamSubscription<double>? _pitchSubscription;
  StreamSubscription<String>? _noteSubscription;
  StreamSubscription<double>? _centsSubscription;

  double _currentFrequency = 0;
  String _detectedNote = '';
  double _cents = 0;
  int _nearestStringIndex = 0;
  int? _selectedStringIndex;
  bool _isListening = false;
  bool _isInTune = false;
  String? _errorMessage;

  double get currentFrequency => _currentFrequency;
  String get detectedNote => _detectedNote;
  double get cents => _cents;
  int get nearestStringIndex => _nearestStringIndex;
  String get nearestStringNote => AppConstants.guitarStringNotes[_nearestStringIndex];
  int? get selectedStringIndex => _selectedStringIndex;
  bool get isListening => _isListening;
  bool get isInTune => _isInTune;
  String? get errorMessage => _errorMessage;

  double? get targetFrequency =>
      _selectedStringIndex != null
          ? AppConstants.guitarStringFrequencies[_selectedStringIndex!]
          : null;

  String? get targetNote =>
      _selectedStringIndex != null
          ? AppConstants.guitarStringNotes[_selectedStringIndex!]
          : null;

  void setSelectedString(int? index) {
    _selectedStringIndex = index;
    _pitchService.setTargetString(index);
    notifyListeners();
  }

  Future<void> startListening() async {
    if (_isListening) return;
    _errorMessage = null;

    // Check if platform is supported
    if (!_pitchService.isPlatformSupported) {
      _errorMessage = 'Tuner only available on iOS device';
      notifyListeners();
      return;
    }

    _isListening = true;
    notifyListeners();

    try {
      await _pitchService.startListening();

      if (!_pitchService.isListening) {
        _errorMessage = 'Microphone access denied or unavailable';
        _isListening = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Error starting pitch detection: $e');
      _isListening = false;
      _errorMessage = 'Failed to start microphone: $e';
      notifyListeners();
      return;
    }

    await _cancelSubscriptions();

    _pitchSubscription = _pitchService.pitchStream.listen((freq) {
      _currentFrequency = freq;
      if (_selectedStringIndex != null) {
        _nearestStringIndex = _selectedStringIndex!;
      } else {
        _nearestStringIndex = _pitchService.getNearestStringIndex(freq);
      }
      notifyListeners();
    });

    _noteSubscription = _pitchService.noteStream.listen((note) {
      _detectedNote = note;
      notifyListeners();
    });

    _centsSubscription = _pitchService.centsStream.listen((cents) {
      _cents = cents;
      _isInTune = cents.abs() <= AppConstants.defaultTunerTolerance;
      notifyListeners();
    });

    notifyListeners();
  }

  Future<void> _cancelSubscriptions() async {
    await _pitchSubscription?.cancel();
    _pitchSubscription = null;
    await _noteSubscription?.cancel();
    _noteSubscription = null;
    await _centsSubscription?.cancel();
    _centsSubscription = null;
  }

  void stopListening() {
    if (!_isListening) return;
    _pitchService.stopListening();
    _cancelSubscriptions();
    _isListening = false;
    _currentFrequency = 0;
    _detectedNote = '';
    _cents = 0;
    _isInTune = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    _pitchService.dispose();
    super.dispose();
  }
}
