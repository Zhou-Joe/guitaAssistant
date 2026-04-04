import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:guitar_assistant/config/theme.dart';

class HeatmapView extends StatelessWidget {
  const HeatmapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Precision Heatmap',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(AppColors.success, 'On beat'),
              const SizedBox(width: 16),
              _buildLegendItem(AppColors.warning, 'Close'),
              const SizedBox(width: 16),
              _buildLegendItem(AppColors.error, 'Off'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: CustomPaint(
                painter: HeatmapPainter(),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class HeatmapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final segmentWidth = size.width / 20;

    for (int i = 0; i < 20; i++) {
      final accuracy = random.nextDouble();
      final color = accuracy > 0.8 ? AppColors.success
                  : accuracy > 0.5 ? AppColors.warning
                  : AppColors.error;

      final paint = Paint()..color = color.withOpacity(0.6 + accuracy * 0.4);
      final height = size.height * (0.3 + accuracy * 0.6);

      canvas.drawRect(
        Rect.fromLTWH(
          i * segmentWidth + 2,
          (size.height - height) / 2,
          segmentWidth - 4,
          height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
