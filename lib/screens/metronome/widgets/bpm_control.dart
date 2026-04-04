import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/metronome_provider.dart';
import 'package:guitar_assistant/config/constants.dart';

class BpmControl extends StatelessWidget {
  const BpmControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MetronomeProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            Text(
              provider.bpm.toString(),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 72,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text('BPM', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => provider.setBpm(provider.bpm - 5),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => provider.setBpm(provider.bpm - 1),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => provider.setBpm(provider.bpm + 1),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => provider.setBpm(provider.bpm + 5),
                ),
              ],
            ),
            Slider(
              value: provider.bpm.toDouble(),
              min: AppConstants.minBPM.toDouble(),
              max: AppConstants.maxBPM.toDouble(),
              onChanged: (value) => provider.setBpm(value.round()),
            ),
          ],
        );
      },
    );
  }
}