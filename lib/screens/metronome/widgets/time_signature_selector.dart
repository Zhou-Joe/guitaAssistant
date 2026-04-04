import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/metronome_provider.dart';

class TimeSignatureSelector extends StatelessWidget {
  const TimeSignatureSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MetronomeProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Time Signature', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['2/4', '3/4', '4/4', '5/4', '6/8', '7/8', '9/8', '12/8']
                  .map((sig) => ChoiceChip(
                        label: Text(sig),
                        selected: provider.timeSignature == sig,
                        onSelected: (selected) {
                          if (selected) provider.setTimeSignature(sig);
                        },
                      ))
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}