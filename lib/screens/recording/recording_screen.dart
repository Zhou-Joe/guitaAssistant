import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/recording_provider.dart';
import 'package:guitar_assistant/data/models/recording.dart';
import 'package:guitar_assistant/config/theme.dart';
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
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Recordings'),
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            bottom: TabBar(
              indicatorColor: AppColors.cta,
              indicatorWeight: 3,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Audio'),
                Tab(text: 'Video'),
              ],
            ),
          ),
          body: const RecordingList(),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.cta,
            foregroundColor: AppColors.textPrimary,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.mic, size: 28),
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
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle indicator
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.mic, color: AppColors.cta),
                ),
                title: Text(
                  'Audio Recording',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Record audio only',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () {
                  provider.setMode(RecordingMode.audio);
                  Navigator.pop(context);
                  _startRecording(context);
                },
              ),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam, color: AppColors.cta),
                ),
                title: Text(
                  'Video Recording',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Record with camera',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () {
                  provider.setMode(RecordingMode.video);
                  Navigator.pop(context);
                  _startRecording(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startRecording(BuildContext context) {
    context.read<RecordingProvider>().startRecording();
  }
}