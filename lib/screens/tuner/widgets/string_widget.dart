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

    if (isInTune) {
      bgColor = AppColors.success.withOpacity(0.3);
      borderColor = AppColors.success;
    } else if (isDetected) {
      bgColor = AppColors.warning.withOpacity(0.3);
      borderColor = AppColors.warning;
    } else if (isSelected) {
      bgColor = AppColors.primary.withOpacity(0.2);
      borderColor = AppColors.primary;
    } else {
      bgColor = AppColors.card;
      borderColor = Colors.grey.shade300;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                if (isSelected || isDetected)
                  BoxShadow(
                    color: borderColor.withOpacity(0.3),
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
                    color: borderColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stringNumber.toString(),
                      style: const TextStyle(
                        color: Colors.white,
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
                              Colors.grey.shade400,
                              Colors.grey.shade600,
                              Colors.grey.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '弦 ${stringNumber}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
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
                        color: borderColor,
                      ),
                    ),
                    Text(
                      '${frequency.toStringAsFixed(2)} Hz',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (isInTune) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
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
