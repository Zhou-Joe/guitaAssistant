import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/recording_provider.dart';
import 'package:guitar_assistant/data/models/recording.dart';
import 'recording_list.dart';

class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecordingProvider()..initialize(),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Recordings'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Audio'),
                Tab(text: 'Video'),
              ],
            ),
          ),
          body: const RecordingList(),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.mic),
            onPressed: () => _showRecordingDialog(context),
          ),
        ),
      ),
    );
  }

  void _showRecordingDialog(BuildContext context) {
    final provider = context.read<RecordingProvider>();
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('Audio Recording'),
            onTap: () {
              provider.setMode(RecordingMode.audio);
              Navigator.pop(context);
              _startRecording(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text('Video Recording'),
            onTap: () {
              provider.setMode(RecordingMode.video);
              Navigator.pop(context);
              _startRecording(context);
            },
          ),
        ],
      ),
    );
  }

  void _startRecording(BuildContext context) {
    context.read<RecordingProvider>().startRecording();
  }
}
