import 'package:flutter/material.dart';
import 'package:guitar_assistant/config/theme.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Timeline Comparison',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildTimelineRow('Expected', Colors.blue),
          const SizedBox(height: 16),
          _buildTimelineRow('Actual', Colors.green),
          const SizedBox(height: 24),
          const Text(
            'Green dots show when you actually played.\nBlue dots show when beats were expected.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(String label, Color color) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label)),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
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
    final paint = Paint()..color = color;
    final dotPositions = [0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0];

    for (final pos in dotPositions) {
      final x = pos * size.width;
      canvas.drawCircle(Offset(x, size.height / 2), 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
