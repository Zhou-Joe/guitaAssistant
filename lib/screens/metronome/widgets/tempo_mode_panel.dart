import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/metronome_provider.dart';
import 'package:guitar_assistant/config/theme.dart';

class TempoModePanel extends StatelessWidget {
  const TempoModePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MetronomeProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '速度模式',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildModeChip(
                    '手动',
                    provider.tempoMode == TempoMode.manual,
                    () => provider.setTempoMode(TempoMode.manual),
                  ),
                  _buildModeChip(
                    '渐进 ${provider.targetGradualBpm}',
                    provider.tempoMode == TempoMode.gradual,
                    () {
                      provider.setTempoMode(TempoMode.gradual);
                      if (!provider.isPlaying) {
                        provider.setTargetGradualBpm(provider.bpm + 10);
                      }
                    },
                  ),
                  _buildModeChip(
                    '步进 +5',
                    provider.tempoMode == TempoMode.step,
                    () => provider.setTempoMode(TempoMode.step),
                  ),
                  _buildModeChip(
                    '间隔',
                    provider.tempoMode == TempoMode.interval,
                    () => provider.setTempoMode(TempoMode.interval),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getModeDescription(provider.tempoMode),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.tempoMode == TempoMode.gradual) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '目标BPM: ',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        '${provider.targetGradualBpm}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildSmallButton(
                        Icons.remove,
                        () => provider.setTargetGradualBpm(
                          provider.targetGradualBpm - 5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildSmallButton(
                        Icons.add,
                        () => provider.setTargetGradualBpm(
                          provider.targetGradualBpm + 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(color: AppColors.secondary, width: 1.5)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: AppColors.textPrimary),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }

  String _getModeDescription(TempoMode mode) {
    switch (mode) {
      case TempoMode.manual:
        return '手动控制速度，不变';
      case TempoMode.gradual:
        return '每4拍自动+1/-1 BPM，向目标速度渐进';
      case TempoMode.step:
        return '每4拍自动+5 BPM，逐步加速';
      case TempoMode.interval:
        return '高低速交替练习，每4拍切换';
    }
  }
}
