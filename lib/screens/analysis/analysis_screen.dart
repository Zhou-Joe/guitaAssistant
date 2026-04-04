import 'package:flutter/material.dart';
import 'package:guitar_assistant/screens/analysis/widgets/waveform_view.dart';
import 'package:guitar_assistant/screens/analysis/widgets/timeline_view.dart';
import 'package:guitar_assistant/screens/analysis/widgets/heatmap_view.dart';

enum AnalysisViewType { waveform, timeline, heatmap }

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  AnalysisViewType _currentView = AnalysisViewType.waveform;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis'),
        bottom: TabBar(
          tabs: const [
            Tab(text: 'Waveform'),
            Tab(text: 'Timeline'),
            Tab(text: 'Heatmap'),
          ],
          onTap: (index) {
            setState(() {
              _currentView = AnalysisViewType.values[index];
            });
          },
        ),
      ),
      body: _buildCurrentView(),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case AnalysisViewType.waveform:
        return const WaveformView();
      case AnalysisViewType.timeline:
        return const TimelineView();
      case AnalysisViewType.heatmap:
        return const HeatmapView();
    }
  }
}
