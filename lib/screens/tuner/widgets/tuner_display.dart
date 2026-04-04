import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:guitar_assistant/config/theme.dart';

class TunerDisplay extends StatelessWidget {
  final double frequency;
  final String note;
  final double cents;
  final String nearestString;
  final bool isInTune;

  const TunerDisplay({
    super.key,
    required this.frequency,
    required this.note,
    required this.cents,
    required this.nearestString,
    required this.isInTune,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          nearestString,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: isInTune ? AppColors.success : AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        if (frequency > 0)
          Text(
            frequency.toStringAsFixed(1) + ' Hz',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.text,
            ),
          ),
        const SizedBox(height: 30),
        _buildNeedleMeter(),
        const SizedBox(height: 20),
        Text(
          isInTune ? 'In Tune!' : cents < 0 ? 'Tighten' : 'Loosen',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isInTune ? AppColors.success : AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildNeedleMeter() {
    return Container(
      width: 200,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: CustomPaint(
        painter: NeedlePainter(cents: cents, isInTune: isInTune),
      ),
    );
  }
}

class NeedlePainter extends CustomPainter {
  final double cents;
  final bool isInTune;

  NeedlePainter({required this.cents, required this.isInTune});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isInTune ? AppColors.success : AppColors.error
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height);
    final angle = (cents / 50).clamp(-1.0, 1.0) * (math.pi / 2);
    final needleLength = size.height - 10;

    canvas.drawLine(
      center,
      Offset(
        center.dx + needleLength * math.sin(angle),
        center.dy - needleLength * math.cos(angle),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant NeedlePainter oldDelegate) =>
      oldDelegate.cents != cents || oldDelegate.isInTune != isInTune;
}
