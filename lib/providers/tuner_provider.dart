import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:guitar_assistant/services/pitch_service.dart';
import 'package:guitar_assistant/config/constants.dart';
import 'package:permission_handler/permission_handler.dart';

class TunerProvider extends ChangeNotifier {
  final PitchService _pitchService = PitchService();
  double _currentFrequency = 0;
  String _detectedNote = '';
  double _cents = 0;
  int _nearestStringIndex = 0;
  int? _selectedStringIndex; // 用户选择的琴弦
  bool _isListening = false;
  bool _isInTune = false;
  String? _errorMessage; // Error message for permission issues

  double get currentFrequency => _currentFrequency;
  String get detectedNote => _detectedNote;
  double get cents => _cents;
  int get nearestStringIndex => _nearestStringIndex;
  String get nearestStringNote => AppConstants.guitarStringNotes[_nearestStringIndex];
  int? get selectedStringIndex => _selectedStringIndex;
  bool get isListening => _isListening;
  bool get isInTune => _isInTune;
  String? get errorMessage => _errorMessage;

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

  Future<void> startListening() async {
    if (_isListening) return;
    _errorMessage = null;
    _isListening = true;
    notifyListeners();

    // Request microphone permission on iOS
    if (Platform.isIOS) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print('Microphone permission not granted: $status');
        _isListening = false;

        // If permanently denied, we need to open settings
        if (status == PermissionStatus.permanentlyDenied ||
            status == PermissionStatus.restricted) {
          _errorMessage = '麦克风权限已被拒绝，请在系统设置中启用';
          // Open settings after a short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            openAppSettings();
          });
        } else {
          _errorMessage = '需要麦克风权限才能进行调音';
        }
        notifyListeners();
        return;
      }
    }

    try {
      await _pitchService.startListening();

      // Check if listening actually started (permission granted)
      if (!_pitchService.isListening) {
        _errorMessage = '需要麦克风权限才能进行调音';
        _isListening = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      print('Error starting pitch detection: $e');
      _isListening = false;
      _errorMessage = '无法启动麦克风：$e';
      notifyListeners();
      return;
    }

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
