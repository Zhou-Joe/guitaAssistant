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
            const Text('Tempo Mode', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Manual'),
                  selected: provider.tempoMode == TempoMode.manual,
                  onSelected: (_) => provider.setTempoMode(TempoMode.manual),
                ),
                ChoiceChip(
                  label: const Text('Gradual'),
                  selected: provider.tempoMode == TempoMode.gradual,
                  onSelected: (_) => provider.setTempoMode(TempoMode.gradual),
                ),
                ChoiceChip(
                  label: const Text('Step'),
                  selected: provider.tempoMode == TempoMode.step,
                  onSelected: (_) => provider.setTempoMode(TempoMode.step),
                ),
                ChoiceChip(
                  label: const Text('Interval'),
                  selected: provider.tempoMode == TempoMode.interval,
                  onSelected: (_) => provider.setTempoMode(TempoMode.interval),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}