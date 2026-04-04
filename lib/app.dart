import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'screens/home/home_screen.dart';

class GuitarApp extends StatefulWidget {
  const GuitarApp({super.key});

  @override
  State<GuitarApp> createState() => _GuitarAppState();
}

class _GuitarAppState extends State<GuitarApp> {
  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    await Hive.initFlutter();
    await Hive.openBox(AppConstants.settingsBox);
    await Hive.openBox(AppConstants.foldersBox);
    await Hive.openBox(AppConstants.tabsBox);
    await Hive.openBox(AppConstants.recordingsBox);
    await Hive.openBox(AppConstants.aiConfigBox);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
