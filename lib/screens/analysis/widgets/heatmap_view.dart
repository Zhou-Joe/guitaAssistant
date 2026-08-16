import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:guitar_assistant/config/theme.dart';

class HeatmapView extends StatelessWidget {
  const HeatmapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Precision Heatmap',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Timing accuracy across practice sessions',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(AppColors.cta, 'On beat'),
              const SizedBox(width: 24),
              _buildLegendItem(AppColors.warning, 'Close'),
              const SizedBox(width: 24),
              _buildLegendItem(AppColors.error, 'Off'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: HeatmapPainter(),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Accuracy summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Accuracy', '87%', AppColors.cta),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.textMuted.withOpacity(0.3),
                ),
                _buildStatItem('On Beat', '14/16', AppColors.cta),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.textMuted.withOpacity(0.3),
                ),
                _buildStatItem('Avg Deviation', '12ms', AppColors.textSecondary),
              ],
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class HeatmapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final segmentWidth = size.width / 20;
    final segmentSpacing = 4.0;

    // Draw background grid
    final gridPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.1)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Draw segments
    for (int i = 0; i < 20; i++) {
      final accuracy = random.nextDouble();
      Color segmentColor;
      if (accuracy > 0.8) {
        segmentColor = AppColors.cta;
      } else if (accuracy > 0.5) {
        segmentColor = AppColors.warning;
      } else {
        segmentColor = AppColors.error;
      }

      final paint = Paint()
        ..color = segmentColor.withOpacity(0.6 + accuracy * 0.4)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = segmentColor.withOpacity(0.8)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final height = size.height * (0.2 + accuracy * 0.6);
      final rect = Rect.fromLTWH(
        i * segmentWidth + segmentSpacing / 2,
        (size.height - height) / 2,
        segmentWidth - segmentSpacing,
        height,
      );

      // Draw rounded rectangle
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rrect, paint);
      canvas.drawRRect(rrect, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}