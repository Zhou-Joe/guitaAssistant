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
  Future<bool>? _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initHive();
  }

  Future<bool> _initHive() async {
    try {
      await Hive.initFlutter();
      await Hive.openBox(AppConstants.settingsBox);
      await Hive.openBox(AppConstants.foldersBox);
      await Hive.openBox(AppConstants.tabsBox);
      await Hive.openBox(AppConstants.recordingsBox);
      await Hive.openBox(AppConstants.aiConfigBox);
      return true;
    } catch (e) {
      debugPrint('Failed to initialize Hive: $e');
      return false;
    }
  }

  @override
  void dispose() {
    Hive.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.data == false) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to initialize storage',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _initializationFuture = _initHive();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const HomeScreen(),
        );
      },
    );
  }
}
