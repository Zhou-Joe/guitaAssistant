import 'dart:async';
import 'dart:math' show log;
import 'package:guitar_assistant/config/constants.dart';

class PitchService {
  StreamSubscription? _pitchSubscription;
  bool _isListening = false;
  int? _targetStringIndex; // 用户选择的目标琴弦
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

    // TODO: 实现真实的音高检测
    // 目前使用模拟数据来演示功能
    _isListening = true;
    _simulatePitchDetection();
  }

  // 模拟音高检测 - 实际使用时需要替换为真实的麦克风输入
  void _simulatePitchDetection() {
    // 这里应该使用 microphone 输入进行实时音高检测
    // 目前用定时器模拟输出
    var count = 0;
    _pitchSubscription = Stream.periodic(const Duration(milliseconds: 100), (_) {
      count++;
      // 模拟吉他弦频率附近的波动
      final baseFreq = _targetStringIndex != null
          ? AppConstants.guitarStringFrequencies[_targetStringIndex!]
          : 110.0;
      // 添加一些随机波动模拟真实情况
      final randomOffset = (count % 10 - 5) * 0.5;
      final simulatedFreq = baseFreq + randomOffset + (count % 20 - 10);

      _pitchController.add(simulatedFreq.abs());
      final noteData = _frequencyToNote(simulatedFreq.abs());
      _noteController.add(noteData['note'] as String);
      _centsController.add(noteData['cents'] as double);
      _isInTuneController.add(noteData['cents'].abs() <= 5.0);
    }).listen((_) {});
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
    return {'note': notes[noteIndex], 'cents': cents, 'octave': octave};
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
    _isInTuneController.close();
  }
}
