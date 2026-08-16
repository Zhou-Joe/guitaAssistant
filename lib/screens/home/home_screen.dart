import 'package:flutter/material.dart';
import 'package:guitar_assistant/config/theme.dart';
import 'package:guitar_assistant/widgets/bottom_nav.dart';
import 'package:guitar_assistant/widgets/minimized_metronome.dart';
import 'package:guitar_assistant/l10n/app_localizations.dart';
import '../tuner/tuner_screen.dart';
import '../metronome/metronome_screen.dart';
import '../favorites/favorites_screen.dart';
import '../settings/settings_screen.dart';

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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              const TunerScreen(),
              const MetronomeScreen(),
              const FavoritesScreen(),
              const SettingsScreen(),
            ],
          ),
          // Show minimized metronome when not on metronome screen (index 1)
          if (_currentIndex != 1) const MinimizedMetronome(),
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _navigateTo,
      ),
    );
  }
}