import 'dart:math' show log, sqrt, cos, sin, pi;
import 'package:audio_analyzer/audio_analyzer.dart';

class AnalysisResult {
  final List<double> waveform;
  final List<Map<String, dynamic>> beatMarkers;
  final Map<String, dynamic> timingStats;

  AnalysisResult({
    required this.waveform,
    required this.beatMarkers,
    required this.timingStats,
  });
}

class AnalysisService {
  Future<AnalysisResult> analyzeRecording(String filePath, int targetBPM) async {
    final analyzer = AudioAnalyzer();
    final data = await analyzer.analyze(filePath);

    final waveform = data.waveform;
    final beatMarkers = _detectBeats(waveform, targetBPM);
    final timingStats = _calculateTimingStats(beatMarkers, targetBPM);

    return AnalysisResult(waveform: waveform, beatMarkers: beatMarkers, timingStats: timingStats);
  }

  List<Map<String, dynamic>> _detectBeats(List<double> waveform, int bpm) {
    final markers = <Map<String, dynamic>>[];
    for (int i = 0; i < waveform.length; i++) {
      if (_isPeak(waveform, i)) {
        markers.add({'index': i, 'amplitude': waveform[i], 'timeMs': i * 10.0});
      }
    }
    return markers;
  }

  bool _isPeak(List<double> waveform, int index) {
    if (index < 2 || index >= waveform.length - 2) return false;
    return waveform[index] > waveform[index - 1] &&
           waveform[index] > waveform[index + 1] &&
           waveform[index] > 0.3;
  }

  Map<String, dynamic> _calculateTimingStats(List<Map<String, dynamic>> markers, int targetBPM) {
    if (markers.length < 2) return {'consistency': 0.0, 'avgDeviation': 0.0};
    final targetInterval = 60.0 / targetBPM * 1000;
    double totalDeviation = 0;
    for (int i = 1; i < markers.length; i++) {
      final actualInterval = (markers[i]['timeMs'] as double) - (markers[i - 1]['timeMs'] as double);
      totalDeviation += (actualInterval - targetInterval).abs();
    }
    return {
      'consistency': 100 - (totalDeviation / markers.length / targetInterval * 100),
      'avgDeviation': totalDeviation / markers.length,
    };
  }

  void dispose() {}
}
