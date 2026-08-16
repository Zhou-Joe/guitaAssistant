import 'package:flutter/material.dart';
import 'package:guitar_assistant/providers/metronome_provider.dart';
import 'package:guitar_assistant/config/theme.dart';

class BpmControlCompact extends StatelessWidget {
  final MetronomeProvider provider;

  const BpmControlCompact({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Beat indicator (only when playing)
          if (provider.isPlaying) ...[
            _buildBeatIndicator(provider),
            const SizedBox(height: 16),
          ],

          // BPM display and controls in a row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BPM decrease buttons
              _buildBpmButton(Icons.remove, () => provider.setBpm(provider.bpm - 5), isLarge: true),
              const SizedBox(width: 8),
              _buildBpmButton(Icons.remove_circle_outline, () => provider.setBpm(provider.bpm - 1)),

              // BPM display
              Container(
                width: 120,
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Text(
                      provider.bpm.toString(),
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'BPM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              // BPM increase buttons
              _buildBpmButton(Icons.add_circle_outline, () => provider.setBpm(provider.bpm + 1)),
              const SizedBox(width: 8),
              _buildBpmButton(Icons.add, () => provider.setBpm(provider.bpm + 5), isLarge: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBpmButton(IconData icon, VoidCallback onTap, {bool isLarge = false}) {
    return Container(
      width: isLarge ? 48 : 40,
      height: isLarge ? 48 : 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: isLarge ? 22 : 18,
          color: AppColors.textPrimary,
        ),
        onPressed: onTap,
        padding: EdgeInsets.zero,
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
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 16 : 10,
          height: isActive ? 16 : 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? (i == 0 ? AppColors.cta : AppColors.secondary)
                : AppColors.surfaceElevated,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: (i == 0 ? AppColors.cta : AppColors.secondary).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}