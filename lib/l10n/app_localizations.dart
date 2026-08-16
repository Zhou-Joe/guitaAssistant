import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Guitar Assistant'**
  String get appTitle;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Tuner tab label
  ///
  /// In en, this message translates to:
  /// **'Tuner'**
  String get tuner;

  /// Metronome tab label
  ///
  /// In en, this message translates to:
  /// **'Metronome'**
  String get metronome;

  /// Favorites tab label
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// Record tab label
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// Analysis tab label
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get analysis;

  /// Settings tab label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Tuner card subtitle on home screen
  ///
  /// In en, this message translates to:
  /// **'6-string guitar tuner'**
  String get tunerSubtitle;

  /// Metronome card subtitle on home screen
  ///
  /// In en, this message translates to:
  /// **'Practice with tempo'**
  String get metronomeSubtitle;

  /// Favorites card subtitle on home screen
  ///
  /// In en, this message translates to:
  /// **'Your guitar tabs'**
  String get favoritesSubtitle;

  /// Record card subtitle on home screen
  ///
  /// In en, this message translates to:
  /// **'Record practice'**
  String get recordSubtitle;

  /// Analysis card subtitle on home screen
  ///
  /// In en, this message translates to:
  /// **'Analyze your playing'**
  String get analysisSubtitle;

  /// Settings card subtitle on home screen
  ///
  /// In en, this message translates to:
  /// **'App configuration'**
  String get settingsSubtitle;

  /// Instruction to start tuning
  ///
  /// In en, this message translates to:
  /// **'Tap to start tuning'**
  String get tapToStartTuning;

  /// Instruction to select a guitar string
  ///
  /// In en, this message translates to:
  /// **'Select a string'**
  String get selectString;

  /// Standard guitar tuning mode
  ///
  /// In en, this message translates to:
  /// **'Standard Tuning'**
  String get standardTuning;

  /// Beats per minute
  ///
  /// In en, this message translates to:
  /// **'BPM'**
  String get bpm;

  /// BPM display with value
  ///
  /// In en, this message translates to:
  /// **'{bpm} BPM'**
  String bpmValue(int bpm);

  /// Time signature setting
  ///
  /// In en, this message translates to:
  /// **'Time Signature'**
  String get timeSignature;

  /// Tempo mode setting
  ///
  /// In en, this message translates to:
  /// **'Tempo Mode'**
  String get tempoMode;

  /// Sound selection
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// Normal tempo mode
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// Accent tempo mode
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get accent;

  /// Random tempo mode
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get random;

  /// Classic click sound
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get classic;

  /// Digital click sound
  ///
  /// In en, this message translates to:
  /// **'Digital'**
  String get digital;

  /// Woodblock click sound
  ///
  /// In en, this message translates to:
  /// **'Woodblock'**
  String get woodblock;

  /// Hi-Hat click sound
  ///
  /// In en, this message translates to:
  /// **'Hi-Hat'**
  String get hihat;

  /// Cowbell click sound
  ///
  /// In en, this message translates to:
  /// **'Cowbell'**
  String get cowbell;

  /// AI features section header
  ///
  /// In en, this message translates to:
  /// **'AI Features'**
  String get aiFeatures;

  /// AI configuration menu item
  ///
  /// In en, this message translates to:
  /// **'AI Configuration'**
  String get aiConfiguration;

  /// AI configuration subtitle
  ///
  /// In en, this message translates to:
  /// **'Configure multimodal API endpoint'**
  String get configureMultimodalApi;

  /// Language section header
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// About section header
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Version display
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Error message when storage fails
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize storage'**
  String get failedToInitializeStorage;

  /// Guitar string label
  ///
  /// In en, this message translates to:
  /// **'String {number}'**
  String string(int number);

  /// Start button label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// Stop button label
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// Pause button label
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Manual tempo mode
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// Gradual tempo mode
  ///
  /// In en, this message translates to:
  /// **'Gradual'**
  String get gradual;

  /// Step tempo mode
  ///
  /// In en, this message translates to:
  /// **'Step +5'**
  String get step;

  /// Interval tempo mode
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get interval;

  /// Gradual tempo mode with target BPM
  ///
  /// In en, this message translates to:
  /// **'Gradual → {target}'**
  String gradualTarget(int target);

  /// Step tempo mode display
  ///
  /// In en, this message translates to:
  /// **'Step +5'**
  String get stepPlus;

  /// Interval tempo mode display
  ///
  /// In en, this message translates to:
  /// **'Interval Alternating'**
  String get intervalAlternating;

  /// Time signature hint
  ///
  /// In en, this message translates to:
  /// **'First beat is accent'**
  String get firstBeatAccent;

  /// Manual mode description
  ///
  /// In en, this message translates to:
  /// **'Manual control, tempo stays constant'**
  String get manualDescription;

  /// Gradual mode description
  ///
  /// In en, this message translates to:
  /// **'Auto ±1 BPM every 4 beats, gradual change'**
  String get gradualDescription;

  /// Step mode description
  ///
  /// In en, this message translates to:
  /// **'Auto +5 BPM every 4 beats, step increase'**
  String get stepDescription;

  /// Interval mode description
  ///
  /// In en, this message translates to:
  /// **'High/low speed alternating, switches every 4 beats'**
  String get intervalDescription;

  /// Target BPM label
  ///
  /// In en, this message translates to:
  /// **'Target BPM: '**
  String get targetBpm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
