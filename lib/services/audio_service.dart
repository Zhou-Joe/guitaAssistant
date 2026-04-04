import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final _recordingController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get recordingStream => _recordingController.stream;
  bool _isRecording = false;

  Future<void> startRecording() async {
    if (_isRecording) return;
    final config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 44100,
      numChannels: 1,
    );
    await _recorder.startStream(config);
    _isRecording = true;
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    await _recorder.stop();
    _isRecording = false;
  }

  Future<bool> isRecording() async => _recorder.isRecording();
  Future<bool> hasPermission() async => _recorder.hasPermission();

  Future<void> dispose() async {
    await _recorder.dispose();
    await _recordingController.close();
  }
}
