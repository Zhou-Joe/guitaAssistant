import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/recording_provider.dart';
import 'package:guitar_assistant/data/models/recording.dart';
import 'player_widget.dart';

class RecordingList extends StatelessWidget {
  const RecordingList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final recordings = provider.recordings;

        if (recordings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_none, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No recordings yet', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: recordings.length,
          itemBuilder: (context, index) {
            final recording = recordings[index];
            return ListTile(
              leading: Icon(
                recording.mode == RecordingMode.audio ? Icons.mic : Icons.videocam,
              ),
              title: Text(recording.title),
              subtitle: Text('${recording.durationSeconds}s'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {},
              ),
            );
          },
        );
      },
    );
  }
}
