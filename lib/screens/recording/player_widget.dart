import 'package:flutter/material.dart';
import 'package:guitar_assistant/data/models/recording.dart';

class PlayerWidget extends StatelessWidget {
  final String filePath;
  final RecordingMode mode;

  const PlayerWidget({
    super.key,
    required this.filePath,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: () {},
            ),
            const Expanded(
              child: Text('Audio Player'),
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
