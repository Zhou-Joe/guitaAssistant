import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show log;
import 'package:flutter_detect_pitch/flutter_detect_pitch.dart';
import 'package:guitar_assistant/config/constants.dart';
import 'package:permission_handler/permission_handler.dart';

class PitchService {
  StreamSubscription? _pitchSubscription;
  bool _isListening = false;
  int? _targetStringIndex; // 用户选择的目标琴弦
  bool get isListening => _isListening;
  final _pitchController = StreamController<double>.broadcast();
  final _noteController = StreamController<String>.broadcast();
  final _centsController = StreamController<double>.broadcast();
  final _isInTuneController = StreamController<bool>.broadcast();

  Stream<double> get pitchStream => _pitchController.stream;
  Stream<String> get noteStream => _noteController.stream;
  Stream<double> get centsStream => _centsController.stream;
  Stream<bool> get isInTuneStream => _isInTuneController.stream;

  // 设置目标琴弦索引，用于更精确的音高检测
  void setTargetString(int? index) {
    _targetStringIndex = index;
  }

  static const List<String> notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  Future<void> startListening() async {
    if (_isListening) return;

    // Request microphone permission on iOS
    if (Platform.isIOS) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print('Microphone permission not granted: $status');
        return;
      }
    }

    try {
      _isListening = true;

      // Listen to the iOS pitch detector stream
      _pitchSubscription = IosPitchDetector.pitchStream.listen((frequency) {
        if (frequency > 0 && frequency.isFinite) {
          _pitchController.add(frequency);

          final noteData = _frequencyToNote(frequency);
          _noteController.add(noteData['note'] as String);
          final cents = noteData['cents'] as double;
          _centsController.add(cents);
          _isInTuneController.add(cents.abs() <= AppConstants.defaultTunerTolerance);
        }
      }, onError: (error) {
        print('Pitch detection error: $error');
        _isListening = false;
      });
    } catch (e) {
      print('Error starting pitch detection: $e');
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    await _pitchSubscription?.cancel();
    _pitchSubscription = null;
    _isListening = false;
  }

  Map<String, dynamic> _frequencyToNote(double frequency) {
    if (frequency <= 0) return {'note': '', 'cents': 0.0, 'octave': 0};

    final a4 = 440.0;
    final semitones = 12 * (log(frequency / a4) / log(2));
    final noteIndex = ((semitones.round() % 12) + 12) % 12;
    final octave = (semitones / 12).floor() + 4;
    final cents = (semitones - semitones.round()) * 100;

    return {
      'note': notes[noteIndex],
      'cents': cents,
      'octave': octave,
    };
  }

  int getNearestStringIndex(double frequency) {
    // 如果设置了目标琴弦，优先返回目标琴弦
    if (_targetStringIndex != null) {
      return _targetStringIndex!;
    }

    int nearestIndex = 0;
    double minDiff = double.infinity;

    for (int i = 0; i < AppConstants.guitarStringFrequencies.length; i++) {
      final diff = (frequency - AppConstants.guitarStringFrequencies[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  bool isInTune(double cents, double tolerance) => cents.abs() <= tolerance;

  void dispose() {
    stopListening();
    _pitchController.close();
    _noteController.close();
    _centsController.close();
    _isInTuneController.close();
  }
}
