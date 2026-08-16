import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/metronome_provider.dart';
import 'package:guitar_assistant/config/theme.dart';

class BpmControl extends StatelessWidget {
  const BpmControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MetronomeProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Beat indicator dots
              if (provider.isPlaying) _buildBeatIndicator(provider),
              const SizedBox(height: 16),
              // BPM display - large circular dial style
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.surfaceElevated,
                          AppColors.surface,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                  // Inner content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        provider.bpm.toString(),
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -2,
                        ),
                      ),
                      Text(
                        'BPM',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // BPM controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bpmButton(Icons.remove, () => provider.setBpm(provider.bpm - 5), isLarge: true),
                  const SizedBox(width: 8),
                  _bpmButton(Icons.remove_circle_outline, () => provider.setBpm(provider.bpm - 1)),
                  const SizedBox(width: 16),
                  _bpmButton(Icons.add_circle_outline, () => provider.setBpm(provider.bpm + 1)),
                  const SizedBox(width: 8),
                  _bpmButton(Icons.add, () => provider.setBpm(provider.bpm + 5), isLarge: true),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bpmButton(IconData icon, VoidCallback onTap, {bool isLarge = false}) {
    return Container(
      width: isLarge ? 52 : 44,
      height: isLarge ? 52 : 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: isLarge ? 24 : 20,
          color: AppColors.textPrimary,
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildBeatIndicator(MetronomeProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(provider.beatsPerMeasure, (i) {
        final isActive = i == provider.currentBeat;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: isActive ? 20 : 12,
          height: isActive ? 20 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? (i == 0 ? AppColors.cta : AppColors.secondary)
                : AppColors.surfaceElevated,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: (i == 0 ? AppColors.cta : AppColors.secondary)
                          .withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
