import 'package:flutter/material.dart';
import 'package:guitar_assistant/config/theme.dart';
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Analysis'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                tabs: const [
                  Tab(text: 'Waveform'),
                  Tab(text: 'Timeline'),
                  Tab(text: 'Heatmap'),
                ],
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorPadding: const EdgeInsets.all(4),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                onTap: (index) {
                  setState(() {
                    _currentView = AnalysisViewType.values[index];
                  });
                },
              ),
            ),
          ),
        ),
        body: _buildCurrentView(),
      ),
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