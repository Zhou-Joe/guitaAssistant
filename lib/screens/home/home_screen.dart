import 'package:flutter/material.dart';
import 'package:guitar_assistant/config/theme.dart';
import 'package:guitar_assistant/widgets/bottom_nav.dart';
import 'package:guitar_assistant/widgets/common/card_widget.dart';
import '../tuner/tuner_screen.dart';
import '../metronome/metronome_screen.dart';
import '../favorites/favorites_screen.dart';
import '../recording/recording_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeContent(onNavigate: _navigateTo),
          const TunerScreen(),
          const MetronomeScreen(),
          const FavoritesScreen(),
          const RecordingScreen(),
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _navigateTo,
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final void Function(int) onNavigate;

  const _HomeContent({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guitar Assistant'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            CommonCard(
              title: 'Tuner',
              subtitle: '6-string guitar tuner',
              icon: Icons.tune,
              color: AppColors.primary,
              onTap: () => onNavigate(1),
            ),
            CommonCard(
              title: 'Metronome',
              subtitle: 'Practice with tempo',
              icon: Icons.music_note,
              color: AppColors.secondary,
              onTap: () => onNavigate(2),
            ),
            CommonCard(
              title: 'Favorites',
              subtitle: 'Your guitar tabs',
              icon: Icons.folder,
              color: AppColors.success,
              onTap: () => onNavigate(3),
            ),
            CommonCard(
              title: 'Recording',
              subtitle: 'Record practice',
              icon: Icons.mic,
              color: AppColors.warning,
              onTap: () => onNavigate(4),
            ),
            CommonCard(
              title: 'Analysis',
              subtitle: 'Analyze your playing',
              icon: Icons.analytics,
              color: AppColors.error,
              onTap: () => onNavigate(5),
            ),
            CommonCard(
              title: 'Settings',
              subtitle: 'App configuration',
              icon: Icons.settings,
              color: AppColors.text,
              onTap: () => onNavigate(6),
            ),
          ],
        ),
      ),
    );
  }
}
