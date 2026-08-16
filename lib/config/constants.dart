/// Application-wide constants for Guitar Assistant.
class AppConstants {
  /// Application display name.
  static const String appName = 'Guitar Assistant';

  /// Tuner tolerance in cents (how close to note is considered "in tune").
  static const double defaultTunerTolerance = 5.0;

  /// Standard guitar tuning frequencies in Hz.
  /// Index 0 = String 6 (Low E2), Index 5 = String 1 (High E4)
  static const List<double> guitarStringFrequencies = [
    82.41,   // String 6: E2 (Low E)
    110.00,  // String 5: A2
    146.83,  // String 4: D3
    196.00,  // String 3: G3
    246.94,  // String 2: B3
    329.63,  // String 1: E4 (High E)
  ];

  /// Standard guitar string note names with octave.
  static const List<String> guitarStringNotes = ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'];

  /// Standard guitar string note names without octave (for simple display).
  static const List<String> guitarStringNoteLetters = ['E', 'A', 'D', 'G', 'B', 'E'];

  /// String display names (1-6, as labeled on guitar).
  static const List<String> guitarStringNames = ['6', '5', '4', '3', '2', '1'];

  /// Minimum tempo value for metronome (BPM).
  static const int minBPM = 30;

  /// Maximum tempo value for metronome (BPM).
  static const int maxBPM = 250;

  /// Default tempo value for metronome (BPM).
  static const int defaultBPM = 120;

  /// Default time signature for metronome.
  static const String defaultTimeSignature = '4/4';

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
