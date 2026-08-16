import 'package:flutter/material.dart';
import 'package:guitar_assistant/config/theme.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline Comparison',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Compare expected beats vs actual playback timing',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          _buildTimelineRow('Expected', AppColors.secondary),
          const SizedBox(height: 16),
          _buildTimelineRow('Actual', AppColors.cta),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Green dots show when you actually played.\nIndigo dots show when beats were expected.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(String label, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: CustomPaint(
              painter: TimelineDotPainter(color: color),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    );
  }
}

class TimelineDotPainter extends CustomPainter {
  final Color color;

  TimelineDotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPositions = [0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 0.95];
    final centerY = size.height / 2;

    // Draw connection line
    final linePaint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(dotPositions.first * size.width, centerY),
      Offset(dotPositions.last * size.width, centerY),
      linePaint,
    );

    // Draw dots
    for (final pos in dotPositions) {
      final x = pos * size.width;
      canvas.drawCircle(Offset(x, centerY), 8, paint);
      canvas.drawCircle(Offset(x, centerY), 10, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}