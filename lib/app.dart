import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'screens/home/home_screen.dart';
import 'data/models/folder.dart';
import 'data/models/tab.dart' as guitar_tab;
import 'data/models/recording.dart';
import 'data/models/ai_config.dart';
import 'providers/language_provider.dart';
import 'providers/metronome_provider.dart';
import 'l10n/app_localizations.dart';

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

      // Register type adapters
      Hive.registerAdapter(FolderAdapter());
      Hive.registerAdapter(guitar_tab.TabFileTypeAdapter());
      Hive.registerAdapter(guitar_tab.TabAdapter());
      Hive.registerAdapter(RecordingModeAdapter());
      Hive.registerAdapter(RecordingAdapter());
      Hive.registerAdapter(AIConfigAdapter());

      await Hive.openBox<Folder>(AppConstants.foldersBox);
      await Hive.openBox<guitar_tab.Tab>(AppConstants.tabsBox);
      await Hive.openBox<Recording>(AppConstants.recordingsBox);
      await Hive.openBox<AIConfig>(AppConstants.aiConfigBox);
      await Hive.openBox(AppConstants.settingsBox);
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
            theme: AppTheme.darkTheme,
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
            theme: AppTheme.darkTheme,
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

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider(create: (_) => MetronomeProvider()),
          ],
          child: Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) {
              return MaterialApp(
                title: AppConstants.appName,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.darkTheme,
                locale: languageProvider.locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const HomeScreen(),
              );
            },
          ),
        );
      },
    );
  }
}
