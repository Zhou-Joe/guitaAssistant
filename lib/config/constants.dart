/// Application-wide constants for Guitar Assistant.
class AppConstants {
  /// Application display name.
  static const String appName = 'Guitar Assistant';

  /// Tuner tolerance in cents (how close to note is considered "in tune").
  static const double defaultTunerTolerance = 5.0;

  /// Standard guitar tuning frequencies in Hz (E2, A2, D3, G3, B3, E4).
  static const List<double> guitarStringFrequencies = [
    82.41, 110.00, 146.83, 196.00, 246.94, 329.63,
  ];

  /// Standard guitar string note names.
  static const List<String> guitarStringNotes = ['E', 'A', 'D', 'G', 'B', 'E'];

  /// Minimum tempo value for metronome (BPM).
  static const int minBPM = 30;

  /// Maximum tempo value for metronome (BPM).
  static const int maxBPM = 250;

  /// Default tempo value for metronome (BPM).
  static const int defaultBPM = 120;

  /// Hive box name for application settings.
  static const String settingsBox = 'settings';

  /// Hive box name for folder paths.
  static const String foldersBox = 'folders';

  /// Hive box name for saved guitar tabs.
  static const String tabsBox = 'tabs';

  /// Hive box name for audio recordings.
  static const String recordingsBox = 'recordings';

  /// Hive box name for AI configuration settings.
  static const String aiConfigBox = 'ai_config';

  /// Folder name for tabs.
  static const String tabsFolder = 'tabs';

  /// Folder name for recordings.
  static const String recordingsFolder = 'recordings';

  /// Folder name for analysis results.
  static const String analysisFolder = 'analysis';
}
