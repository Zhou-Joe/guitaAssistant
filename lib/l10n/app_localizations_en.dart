// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Guitar Assistant';

  @override
  String get home => 'Home';

  @override
  String get tuner => 'Tuner';

  @override
  String get metronome => 'Metronome';

  @override
  String get favorites => 'Favorites';

  @override
  String get record => 'Record';

  @override
  String get analysis => 'Analysis';

  @override
  String get settings => 'Settings';

  @override
  String get tunerSubtitle => '6-string guitar tuner';

  @override
  String get metronomeSubtitle => 'Practice with tempo';

  @override
  String get favoritesSubtitle => 'Your guitar tabs';

  @override
  String get recordSubtitle => 'Record practice';

  @override
  String get analysisSubtitle => 'Analyze your playing';

  @override
  String get settingsSubtitle => 'App configuration';

  @override
  String get tapToStartTuning => 'Tap to start tuning';

  @override
  String get selectString => 'Select a string';

  @override
  String get standardTuning => 'Standard Tuning';

  @override
  String get bpm => 'BPM';

  @override
  String bpmValue(int bpm) {
    return '$bpm BPM';
  }

  @override
  String get timeSignature => 'Time Signature';

  @override
  String get tempoMode => 'Tempo Mode';

  @override
  String get sound => 'Sound';

  @override
  String get normal => 'Normal';

  @override
  String get accent => 'Accent';

  @override
  String get random => 'Random';

  @override
  String get classic => 'Classic';

  @override
  String get digital => 'Digital';

  @override
  String get woodblock => 'Woodblock';

  @override
  String get hihat => 'Hi-Hat';

  @override
  String get cowbell => 'Cowbell';

  @override
  String get aiFeatures => 'AI Features';

  @override
  String get aiConfiguration => 'AI Configuration';

  @override
  String get configureMultimodalApi => 'Configure multimodal API endpoint';

  @override
  String get language => 'Language';

  @override
  String get about => 'About';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get retry => 'Retry';

  @override
  String get failedToInitializeStorage => 'Failed to initialize storage';

  @override
  String string(int number) {
    return 'String $number';
  }

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get pause => 'Pause';

  @override
  String get manual => 'Manual';

  @override
  String get gradual => 'Gradual';

  @override
  String get step => 'Step +5';

  @override
  String get interval => 'Interval';

  @override
  String gradualTarget(int target) {
    return 'Gradual → $target';
  }

  @override
  String get stepPlus => 'Step +5';

  @override
  String get intervalAlternating => 'Interval Alternating';

  @override
  String get firstBeatAccent => 'First beat is accent';

  @override
  String get manualDescription => 'Manual control, tempo stays constant';

  @override
  String get gradualDescription => 'Auto ±1 BPM every 4 beats, gradual change';

  @override
  String get stepDescription => 'Auto +5 BPM every 4 beats, step increase';

  @override
  String get intervalDescription =>
      'High/low speed alternating, switches every 4 beats';

  @override
  String get targetBpm => 'Target BPM: ';
}
