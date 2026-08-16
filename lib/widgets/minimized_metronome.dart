import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/metronome_provider.dart';
import 'package:guitar_assistant/config/theme.dart';
import 'package:guitar_assistant/l10n/app_localizations.dart';

class MinimizedMetronome extends StatefulWidget {
  const MinimizedMetronome({super.key});

  @override
  State<MinimizedMetronome> createState() => _MinimizedMetronomeState();
}

class _MinimizedMetronomeState extends State<MinimizedMetronome> {
  bool _hasBeenStarted = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<MetronomeProvider>(
      builder: (context, provider, child) {
        // Track if metronome has been started at least once
        if (provider.isPlaying) {
          _hasBeenStarted = true;
        }

        // Show widget if metronome has been started and not on metronome screen
        if (!_hasBeenStarted) return const SizedBox.shrink();

        return Positioned(
          bottom: 80, // Above bottom nav
          right: 16,
          child: Material(
            elevation: 8,
            color: Colors.transparent,
            shadowColor: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: provider.isPlaying
                      ? AppColors.cta.withValues(alpha: 0.3)
                      : AppColors.surfaceElevated,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // BPM display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      l10n.bpmValue(provider.bpm),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Play/Pause button
                  GestureDetector(
                    onTap: provider.togglePlay,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: provider.isPlaying ? AppColors.error : AppColors.cta,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (provider.isPlaying ? AppColors.error : AppColors.cta)
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        provider.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}