import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/metronome_provider.dart';
import 'package:guitar_assistant/config/theme.dart';
import 'package:guitar_assistant/l10n/app_localizations.dart';
import 'widgets/bpm_control_compact.dart';
import 'widgets/expandable_setting_card.dart';

class MetronomeScreen extends StatelessWidget {
  const MetronomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.metronome),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Consumer<MetronomeProvider>(
        builder: (context, provider, child) {
          return Container(
            color: AppColors.background,
            child: SafeArea(
              child: Column(
                children: [
                  // Scrollable content area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          // BPM Control - always visible at top
                          BpmControlCompact(provider: provider),

                          const SizedBox(height: 16),

                          // Function cards - all visible without scrolling
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                // Row 1: Time Signature + Sound
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ExpandableSettingCard(
                                        title: l10n.timeSignature,
                                        icon: Icons.music_note,
                                        currentValue: provider.timeSignature,
                                        accentColor: AppColors.secondary,
                                        children: _buildTimeSignatureOptions(provider, l10n),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ExpandableSettingCard(
                                        title: l10n.sound,
                                        icon: Icons.speaker,
                                        currentValue: soundDisplayName[provider.soundStyle]!,
                                        accentColor: AppColors.cta,
                                        children: _buildSoundOptions(provider),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Row 2: Tempo Mode (full width)
                                ExpandableSettingCard(
                                  title: l10n.tempoMode,
                                  icon: Icons.speed,
                                  currentValue: _getTempoModeLabel(provider, l10n),
                                  accentColor: AppColors.primary,
                                  children: _buildTempoModeOptions(provider, l10n),
                                ),

                                if (provider.error != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            provider.error!,
                                            style: TextStyle(color: AppColors.error),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Fixed play button at bottom
                  Container(
                    padding: const EdgeInsets.only(bottom: 24, top: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.background.withOpacity(0),
                          AppColors.background,
                        ],
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 140,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            backgroundColor: provider.isPlaying
                                ? AppColors.error
                                : AppColors.cta,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: (provider.isPlaying ? AppColors.error : AppColors.cta)
                                .withOpacity(0.3),
                          ),
                          onPressed: provider.togglePlay,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                provider.isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                provider.isPlaying ? l10n.pause : l10n.start,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getTempoModeLabel(MetronomeProvider provider, AppLocalizations l10n) {
    switch (provider.tempoMode) {
      case TempoMode.manual:
        return l10n.manual;
      case TempoMode.gradual:
        return l10n.gradualTarget(provider.targetGradualBpm);
      case TempoMode.step:
        return l10n.stepPlus;
      case TempoMode.interval:
        return l10n.intervalAlternating;
    }
  }

  List<Widget> _buildTimeSignatureOptions(MetronomeProvider provider, AppLocalizations l10n) {
    final signatures = ['2/4', '3/4', '4/4', '5/4', '6/8', '7/8', '9/8', '12/8'];
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: signatures
            .map((sig) => _buildCompactChip(
                  sig,
                  provider.timeSignature == sig,
                  () => provider.setTimeSignature(sig),
                ))
            .toList(),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.firstBeatAccent,
        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
    ];
  }

  List<Widget> _buildSoundOptions(MetronomeProvider provider) {
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: SoundStyle.values
            .map((style) => _buildCompactChip(
                  soundDisplayName[style]!,
                  provider.soundStyle == style,
                  () => provider.setSoundStyle(style),
                ))
            .toList(),
      ),
    ];
  }

  List<Widget> _buildTempoModeOptions(MetronomeProvider provider, AppLocalizations l10n) {
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildCompactChip(
            l10n.manual,
            provider.tempoMode == TempoMode.manual,
            () => provider.setTempoMode(TempoMode.manual),
          ),
          _buildCompactChip(
            l10n.gradual,
            provider.tempoMode == TempoMode.gradual,
            () => provider.setTempoMode(TempoMode.gradual),
          ),
          _buildCompactChip(
            l10n.stepPlus,
            provider.tempoMode == TempoMode.step,
            () => provider.setTempoMode(TempoMode.step),
          ),
          _buildCompactChip(
            l10n.interval,
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
                _getModeDescription(provider.tempoMode, l10n),
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
      if (provider.tempoMode == TempoMode.gradual) ...[
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.targetBpm, style: TextStyle(color: AppColors.textSecondary)),
            Text(
              '${provider.targetGradualBpm}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 12),
            _buildSmallButton(Icons.remove, () => provider.setTargetGradualBpm(provider.targetGradualBpm - 5)),
            const SizedBox(width: 8),
            _buildSmallButton(Icons.add, () => provider.setTargetGradualBpm(provider.targetGradualBpm + 5)),
          ],
        ),
      ],
    ];
  }

  Widget _buildCompactChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: AppColors.secondary, width: 1.5) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: AppColors.textPrimary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, size: 16, color: AppColors.textPrimary),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }

  String _getModeDescription(TempoMode mode, AppLocalizations l10n) {
    switch (mode) {
      case TempoMode.manual:
        return l10n.manualDescription;
      case TempoMode.gradual:
        return l10n.gradualDescription;
      case TempoMode.step:
        return l10n.stepDescription;
      case TempoMode.interval:
        return l10n.intervalDescription;
    }
  }
}