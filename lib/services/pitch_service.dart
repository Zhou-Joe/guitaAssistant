import 'dart:async';
import 'dart:math' show log;
import 'package:flutter_detect_pitch/flutter_detect_pitch.dart';
import 'package:guitar_assistant/config/constants.dart';

class PitchService {
  StreamSubscription? _pitchSubscription;
  bool _isListening = false;
  final _pitchController = StreamController<double>.broadcast();
  final _noteController = StreamController<String>.broadcast();
  final _centsController = StreamController<double>.broadcast();

  Stream<double> get pitchStream => _pitchController.stream;
  Stream<String> get noteStream => _noteController.stream;
  Stream<double> get centsStream => _centsController.stream;

  static const List<String> notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;
    _pitchSubscription = IosPitchDetector.pitchStream.listen((frequency) {
      _pitchController.add(frequency);
      final noteData = _frequencyToNote(frequency);
      _noteController.add(noteData['note'] as String);
      _centsController.add(noteData['cents'] as double);
    });
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    await _pitchSubscription?.cancel();
    _isListening = false;
  }

  Map<String, dynamic> _frequencyToNote(double frequency) {
    if (frequency <= 0) return {'note': '', 'cents': 0.0, 'octave': 0};
    final a4 = 440.0;
    final semitones = 12 * (log(frequency / a4) / log(2));
    final noteIndex = ((semitones.round() % 12) + 12) % 12;
    final octave = (semitones / 12).floor() + 4;
    final cents = (semitones - semitones.round()) * 100;
    return {'note': notes[noteIndex], 'cents': cents, 'octave': octave};
  }

  int getNearestStringIndex(double frequency) {
    int nearestIndex = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < AppConstants.guitarStringFrequencies.length; i++) {
      final diff = (frequency - AppConstants.guitarStringFrequencies[i]).abs();
      if (diff < minDiff) { minDiff = diff; nearestIndex = i; }
    }
    return nearestIndex;
  }

  bool isInTune(double cents, double tolerance) => cents.abs() <= tolerance;

  void dispose() {
    stopListening();
    _pitchController.close();
    _noteController.close();
    _centsController.close();
  }
}
