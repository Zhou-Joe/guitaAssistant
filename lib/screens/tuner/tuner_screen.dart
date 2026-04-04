import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/tuner_provider.dart';
import 'widgets/tuner_display.dart';

class TunerScreen extends StatelessWidget {
  const TunerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TunerProvider(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Tuner')),
        body: Consumer<TunerProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TunerDisplay(
                  frequency: provider.currentFrequency,
                  note: provider.detectedNote,
                  cents: provider.cents,
                  nearestString: provider.nearestStringNote,
                  isInTune: provider.isInTune,
                ),
                const SizedBox(height: 40),
                if (provider.isListening)
                  ElevatedButton(
                    onPressed: provider.stopListening,
                    child: const Text('Stop'),
                  )
                else
                  ElevatedButton(
                    onPressed: provider.startListening,
                    child: const Text('Start Tuning'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
