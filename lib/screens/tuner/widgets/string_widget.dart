import 'package:flutter/material.dart';
import 'package:guitar_assistant/config/theme.dart';

class GuitarStringWidget extends StatelessWidget {
  final int stringNumber;
  final String note;
  final double frequency;
  final bool isSelected;
  final bool isDetected;
  final bool isInTune;
  final VoidCallback onTap;

  const GuitarStringWidget({
    super.key,
    required this.stringNumber,
    required this.note,
    required this.frequency,
    required this.isSelected,
    required this.isDetected,
    required this.isInTune,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color accentColor;

    if (isInTune) {
      bgColor = AppColors.cta.withValues(alpha: 0.15);
      borderColor = AppColors.cta;
      accentColor = AppColors.cta;
    } else if (isDetected) {
      bgColor = AppColors.warning.withValues(alpha: 0.15);
      borderColor = AppColors.warning;
      accentColor = AppColors.warning;
    } else if (isSelected) {
      bgColor = AppColors.secondary.withValues(alpha: 0.2);
      borderColor = AppColors.secondary;
      accentColor = AppColors.secondary;
    } else {
      bgColor = AppColors.surface;
      borderColor = AppColors.surfaceElevated;
      accentColor = AppColors.textMuted;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                if (isSelected || isDetected)
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Row(
              children: [
                // 琴弦编号
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stringNumber.toString(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 琴弦视觉表示
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 模拟琴弦
                      Container(
                        height: stringNumber <= 2 ? 2 : (stringNumber <= 4 ? 3 : 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.textMuted.withValues(alpha: 0.3),
                              AppColors.textSecondary.withValues(alpha: 0.5),
                              AppColors.textMuted.withValues(alpha: 0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '弦 $stringNumber',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 音符和频率
                Column(
                  children: [
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isInTune ? AppColors.cta : (isDetected ? AppColors.warning : AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      '${frequency.toStringAsFixed(2)} Hz',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (isInTune) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.cta,
                    size: 32,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
