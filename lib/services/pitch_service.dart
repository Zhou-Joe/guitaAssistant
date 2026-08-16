import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show log;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:guitar_assistant/config/constants.dart';
import 'package:record/record.dart';

/// Cross-platform pitch detection service using YIN algorithm
class PitchService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _audioSubscription;
  bool _isListening = false;
  int? _targetStringIndex;

  bool get isListening => _isListening;

  final _pitchController = StreamController<double>.broadcast();
  final _noteController = StreamController<String>.broadcast();
  final _centsController = StreamController<double>.broadcast();
  final _isInTuneController = StreamController<bool>.broadcast();

  Stream<double> get pitchStream => _pitchController.stream;
  Stream<String> get noteStream => _noteController.stream;
  Stream<double> get centsStream => _centsController.stream;
  Stream<bool> get isInTuneStream => _isInTuneController.stream;

  static const List<String> notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  // Audio config
  static const int sampleRate = 44100;
  static const int bufferSize = 1024; // Smaller buffer for faster response

  // YIN parameters
  static const double yinThreshold = 0.15;

  // Frequency smoothing
  final List<double> _freqHistory = [];
  static const int smoothingWindow = 3; // Less smoothing for faster response
  double _lastStableFreq = 0;

  bool get isPlatformSupported => Platform.isIOS || Platform.isMacOS || Platform.isAndroid;

  void setTargetString(int? index) {
    _targetStringIndex = index;
    _freqHistory.clear();
    _lastStableFreq = 0;
  }

  Future<void> startListening() async {
    if (_isListening) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (hasPermission != true) {
        debugPrint('Microphone permission not granted');
        return;
      }

      _isListening = true;
      _freqHistory.clear();

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      );

      final stream = await _recorder.startStream(config);

      _audioSubscription = stream.listen((Uint8List data) {
        _processAudioData(data);
      }, onError: (error) {
        debugPrint('Audio stream error: $error');
        _isListening = false;
      });
    } catch (e) {
      debugPrint('Error starting audio stream: $e');
      _isListening = false;
    }
  }

  void _processAudioData(Uint8List data) {
    final samples = _bytesToInt16Samples(data);
    if (samples.length < bufferSize) return;

    // Detect pitch using YIN
    final frequency = _yinPitchDetection(samples);

    if (frequency > 0 && frequency.isFinite) {
      // Apply median filter for stability
      final stableFreq = _medianFilter(frequency);

      if (stableFreq > 0) {
        _pitchController.add(stableFreq);

        double cents;
        String note;

        if (_targetStringIndex != null) {
          final targetFreq = AppConstants.guitarStringFrequencies[_targetStringIndex!];
          cents = 1200 * log(stableFreq / targetFreq) / ln2;
          note = AppConstants.guitarStringNotes[_targetStringIndex!];
        } else {
          final noteData = _frequencyToNote(stableFreq);
          note = noteData['note'] as String;
          cents = noteData['cents'] as double;
        }

        _noteController.add(note);
        _centsController.add(cents);
        _isInTuneController.add(cents.abs() <= AppConstants.defaultTunerTolerance);
      }
    }
  }

  /// Median filter for frequency stability
  double _medianFilter(double newFreq) {
    // Reject frequencies outside guitar range
    if (newFreq < 70 || newFreq > 400) {
      return _lastStableFreq;
    }

    // Accept larger jumps (25%) for faster response
    if (_lastStableFreq > 0 && (newFreq / _lastStableFreq - 1).abs() > 0.25) {
      // Reset history on big jump - user changed strings
      _freqHistory.clear();
    }

    _freqHistory.add(newFreq);
    if (_freqHistory.length > smoothingWindow) {
      _freqHistory.removeAt(0);
    }

    // Return median of recent values
    final sorted = List<double>.from(_freqHistory)..sort();
    final median = sorted[sorted.length ~/ 2];

    _lastStableFreq = median;
    return median;
  }

  List<int> _bytesToInt16Samples(Uint8List bytes) {
    final samples = <int>[];
    for (int i = 0; i < bytes.length - 1; i += 2) {
      int sample = bytes[i] | (bytes[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      samples.add(sample);
    }
    return samples;
  }

  /// YIN pitch detection - proper implementation
  double _yinPitchDetection(List<int> samples) {
    final n = samples.length;
    final yinBufferSize = n ~/ 2;
    final yinBuffer = List<double>.filled(yinBufferSize, 0.0);

    // Calculate search range for guitar (E2=82Hz to E4=330Hz)
    // tau = sampleRate / frequency
    final minTau = (sampleRate / 400).floor(); // ~110 for high E
    final maxTau = (sampleRate / 70).floor();  // ~630 for low E

    if (maxTau >= yinBufferSize) return 0;

    // Step 1: Difference function d'(tau)
    for (int tau = 0; tau < yinBufferSize; tau++) {
      double sum = 0;
      for (int j = 0; j < yinBufferSize; j++) {
        final delta = samples[j].toDouble() - samples[j + tau].toDouble();
        sum += delta * delta;
      }
      yinBuffer[tau] = sum;
    }

    // Step 2: Cumulative mean normalized difference function
    yinBuffer[0] = 1.0;
    double runningSum = 0;
    for (int tau = 1; tau < yinBufferSize; tau++) {
      runningSum += yinBuffer[tau];
      yinBuffer[tau] = yinBuffer[tau] * tau / runningSum;
    }

    // Step 3: Absolute threshold - find first tau below threshold
    int bestTau = -1;

    // Search within guitar frequency range
    for (int tau = minTau; tau < maxTau; tau++) {
      if (yinBuffer[tau] < yinThreshold) {
        // Found candidate - search for local minimum
        while (tau + 1 < maxTau && yinBuffer[tau + 1] < yinBuffer[tau]) {
          tau++;
        }
        bestTau = tau;
        break;
      }
    }

    // If no candidate found, find the global minimum in range
    if (bestTau == -1) {
      double minVal = double.infinity;
      for (int tau = minTau; tau < maxTau; tau++) {
        if (yinBuffer[tau] < minVal) {
          minVal = yinBuffer[tau];
          bestTau = tau;
        }
      }
    }

    if (bestTau <= 0) return 0;

    // Step 4: Parabolic interpolation for sub-sample accuracy
    final interpolatedTau = _parabolicInterpolation(yinBuffer, bestTau);

    return sampleRate / interpolatedTau;
  }

  double _parabolicInterpolation(List<double> yinBuffer, int tau) {
    if (tau < 1 || tau >= yinBuffer.length - 1) return tau.toDouble();

    final s0 = yinBuffer[tau - 1];
    final s1 = yinBuffer[tau];
    final s2 = yinBuffer[tau + 1];

    final denom = 2 * s1 - s2 - s0;
    if (denom.abs() < 0.0001) return tau.toDouble();

    final adjustment = (s2 - s0) / (2 * denom);
    return tau + adjustment;
  }

  Map<String, dynamic> _frequencyToNote(double frequency) {
    if (frequency <= 0) return {'note': '', 'cents': 0.0, 'octave': 0};

    const a4 = 440.0;
    final semitones = 12 * log(frequency / a4) / ln2;
    final rounded = semitones.round();
    final noteIndex = ((rounded % 12) + 12) % 12;
    final octave = (semitones / 12).floor() + 4;
    final cents = (semitones - rounded) * 100;

    return {
      'note': notes[noteIndex],
      'cents': cents,
      'octave': octave,
    };
  }

  int getNearestStringIndex(double frequency) {
    if (_targetStringIndex != null) return _targetStringIndex!;

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

  Future<void> stopListening() async {
    if (!_isListening) return;

    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _recorder.stop();
    _isListening = false;
    _freqHistory.clear();
    _lastStableFreq = 0;
  }

  void dispose() {
    stopListening();
    _pitchController.close();
    _noteController.close();
    _centsController.close();
    _isInTuneController.close();
    _recorder.dispose();
  }
}

const ln2 = 0.6931471805599453;