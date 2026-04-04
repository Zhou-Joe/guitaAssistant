import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/metronome_provider.dart';
import 'widgets/bpm_control.dart';
import 'widgets/time_signature_selector.dart';
import 'widgets/tempo_mode_panel.dart';

class MetronomeScreen extends StatelessWidget {
  const MetronomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MetronomeProvider(),
      child: Scaffold(
        appBar: AppBar(title: const Text('节拍器')),
        body: Consumer<MetronomeProvider>(
          builder: (context, provider, child) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const BpmControl(),
                  const SizedBox(height: 24),
                  const TimeSignatureSelector(),
                  const SizedBox(height: 24),
                  const TempoModePanel(),
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: provider.isPlaying
                            ? Colors.red
                            : Colors.green,
                      ),
                      onPressed: provider.togglePlay,
                      child: Icon(
                        provider.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}