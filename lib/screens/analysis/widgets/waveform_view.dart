import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:guitar_assistant/config/theme.dart';

class WaveformView extends StatelessWidget {
  const WaveformView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Waveform + Beat Markers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Visual representation of audio amplitude over time',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: WaveformPainter(),
                  size: Size.infinite,
                ),
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
    // Draw subtle grid lines
    final gridPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.2)
      ..strokeWidth = 1;

    // Horizontal center line
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      gridPaint,
    );

    // Draw vertical beat markers
    final markerPaint = Paint()
      ..color = AppColors.secondary.withOpacity(0.3)
      ..strokeWidth = 1;

    for (int i = 0; i < 8; i++) {
      final x = (i + 1) * size.width / 8;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        markerPaint,
      );
    }

    // Draw waveform with gradient
    final waveformPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.cta,
          AppColors.secondary,
          AppColors.primary,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2;

    final sampleData = _generateSampleWaveform(size.width.toInt());

    for (int i = 0; i < sampleData.length; i++) {
      final x = (i / sampleData.length) * size.width;
      final amplitude = sampleData[i] * size.height * 0.35;
      canvas.drawLine(
        Offset(x, centerY - amplitude),
        Offset(x, centerY + amplitude),
        waveformPaint..strokeWidth = 1.5,
      );
    }

    // Draw accent line at peaks
    final accentPaint = Paint()
      ..color = AppColors.cta
      ..strokeWidth = 2;

    for (int i = 0; i < sampleData.length; i++) {
      if (sampleData[i] > 0.7) {
        final x = (i / sampleData.length) * size.width;
        final amplitude = sampleData[i] * size.height * 0.35;
        canvas.drawCircle(
          Offset(x, centerY - amplitude),
          2,
          accentPaint,
        );
        canvas.drawCircle(
          Offset(x, centerY + amplitude),
          2,
          accentPaint,
        );
      }
    }
  }

  List<double> _generateSampleWaveform(int width) {
    final data = <double>[];
    final rand = math.Random(42); // Fixed seed for consistent display
    for (int i = 0; i < width; i++) {
      final normalized = i / width;
      final wave = math.sin(normalized * math.pi * 8) * 0.5 +
          math.sin(normalized * math.pi * 16) * 0.3 +
          (rand.nextDouble() - 0.5) * 0.2;
      data.add(wave.abs());
    }
    return data;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}