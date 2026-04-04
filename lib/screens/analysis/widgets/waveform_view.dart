import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:guitar_assistant/config/theme.dart';

class WaveformView extends StatelessWidget {
  const WaveformView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Waveform + Beat Markers',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: CustomPaint(
                painter: WaveformPainter(),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2;

    final centerY = size.height / 2;
    final sampleData = _generateSampleWaveform(size.width.toInt());

    for (int i = 0; i < sampleData.length; i++) {
      final x = (i / sampleData.length) * size.width;
      final amplitude = sampleData[i] * size.height * 0.4;
      canvas.drawLine(
        Offset(x, centerY - amplitude),
        Offset(x, centerY + amplitude),
        paint,
      );
    }
  }

  List<double> _generateSampleWaveform(int width) {
    final data = <double>[];
    for (int i = 0; i < width; i++) {
      final normalized = i / width;
      final wave = math.sin(normalized * math.pi * 8) * 0.5 +
                   math.sin(normalized * math.pi * 16) * 0.3 +
                   (math.Random().nextDouble() - 0.5) * 0.2;
      data.add(wave.abs());
    }
    return data;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
