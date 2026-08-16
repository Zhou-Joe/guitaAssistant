import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/recording_provider.dart';
import 'package:guitar_assistant/data/models/recording.dart';
import 'package:guitar_assistant/config/theme.dart';

class PlayerWidget extends StatelessWidget {
  final String filePath;
  final RecordingMode mode;
  final String recordingId;

  const PlayerWidget({
    super.key,
    required this.filePath,
    required this.mode,
    required this.recordingId,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, provider, child) {
        final isPlaying = provider.isRecordingPlaying(recordingId);
        final progress = provider.getPlaybackProgress(recordingId);
        final position = provider.playbackPosition;
        final duration = provider.playbackDuration;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: () {
                  provider.playRecording(recordingId, filePath);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cta,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Progress bar
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.cta,
                        inactiveTrackColor: AppColors.surface,
                        thumbColor: AppColors.cta,
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayColor: AppColors.cta.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: (value) {
                          if (duration.inMilliseconds > 0) {
                            final newPosition = Duration(
                              milliseconds:
                                  (value * duration.inMilliseconds).round(),
                            );
                            provider.seekPlayback(newPosition);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Time display
              Text(
                provider.currentlyPlayingId == recordingId
                    ? '${_formatDuration(position)} / ${_formatDuration(duration)}'
                    : '0:00',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              // Share button
              IconButton(
                icon: Icon(
                  Icons.share_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () {
                  _shareRecording(filePath);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareRecording(String filePath) {
    // TODO: Implement share functionality using share_plus package
    // This will be implemented when share functionality is fully designed
  }
}