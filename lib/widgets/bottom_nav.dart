import 'package:flutter/material.dart';
import 'package:guitar_assistant/config/theme.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textLight,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Tuner'),
        BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Metronome'),
        BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Favorites'),
        BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Record'),
      ],
    );
  }
}
