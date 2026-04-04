import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/metronome_provider.dart';

class TempoModePanel extends StatelessWidget {
  const TempoModePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MetronomeProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('节奏模式', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('手动'),
                  selected: provider.tempoMode == TempoMode.manual,
                  onSelected: (_) => provider.setTempoMode(TempoMode.manual),
                ),
                ChoiceChip(
                  label: Text('渐进 ${provider.targetGradualBpm}'),
                  selected: provider.tempoMode == TempoMode.gradual,
                  onSelected: (_) {
                    provider.setTempoMode(TempoMode.gradual);
                    if (!provider.isPlaying) {
                      provider.setTargetGradualBpm(provider.bpm + 10);
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('步进 +5'),
                  selected: provider.tempoMode == TempoMode.step,
                  onSelected: (_) => provider.setTempoMode(TempoMode.step),
                ),
                ChoiceChip(
                  label: const Text('间隔'),
                  selected: provider.tempoMode == TempoMode.interval,
                  onSelected: (_) => provider.setTempoMode(TempoMode.interval),
                ),
              ],
            ),
            // Show current mode description
            if (provider.tempoMode == TempoMode.gradual) ...[
              const SizedBox(height: 8),
              Text(
                '每 4 拍增加/减少 1 BPM，目标：${provider.targetGradualBpm} BPM',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ] else if (provider.tempoMode == TempoMode.step) ...[
              const SizedBox(height: 8),
              Text(
                '每 4 拍增加 5 BPM',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ] else if (provider.tempoMode == TempoMode.interval) ...[
              const SizedBox(height: 8),
              Text(
                '每 4 拍在当前 BPM 和 ${(provider.bpm ~/ 1.2).clamp(40, 200)} BPM 之间切换',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        );
      },
    );
  }
}