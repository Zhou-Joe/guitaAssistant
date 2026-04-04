class AppConstants {
  static const String appName = 'Guitar Assistant';
  static const double defaultTunerTolerance = 5.0;
  static const List<double> guitarStringFrequencies = [
    82.41, 110.00, 146.83, 196.00, 246.94, 329.63,
  ];
  static const List<String> guitarStringNotes = ['E', 'A', 'D', 'G', 'B', 'E'];
  static const int minBPM = 30;
  static const int maxBPM = 250;
  static const int defaultBPM = 120;
  static const String settingsBox = 'settings';
  static const String foldersBox = 'folders';
  static const String tabsBox = 'tabs';
  static const String recordingsBox = 'recordings';
  static const String aiConfigBox = 'ai_config';
}
