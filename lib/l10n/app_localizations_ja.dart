// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'ギターアシスタント';

  @override
  String get home => 'ホーム';

  @override
  String get tuner => '調音器';

  @override
  String get metronome => 'メトロノーム';

  @override
  String get favorites => 'お気に入り';

  @override
  String get record => '録音';

  @override
  String get analysis => '分析';

  @override
  String get settings => '設定';

  @override
  String get tunerSubtitle => '6弦ギター調音';

  @override
  String get metronomeSubtitle => 'テンポで練習';

  @override
  String get favoritesSubtitle => 'ギター譜面';

  @override
  String get recordSubtitle => '練習を録音';

  @override
  String get analysisSubtitle => '演奏を分析';

  @override
  String get settingsSubtitle => 'アプリ設定';

  @override
  String get tapToStartTuning => 'タップして調音を開始';

  @override
  String get selectString => '弦を選択';

  @override
  String get standardTuning => '標準調弦';

  @override
  String get bpm => 'BPM';

  @override
  String bpmValue(int bpm) {
    return '$bpm BPM';
  }

  @override
  String get timeSignature => '拍子記号';

  @override
  String get tempoMode => 'テンポモード';

  @override
  String get sound => '音色';

  @override
  String get normal => '通常';

  @override
  String get accent => 'アクセント';

  @override
  String get random => 'ランダム';

  @override
  String get classic => 'クラシック';

  @override
  String get digital => 'デジタル';

  @override
  String get woodblock => '木ブロック';

  @override
  String get hihat => 'ハイハット';

  @override
  String get cowbell => 'カウベル';

  @override
  String get aiFeatures => 'AI機能';

  @override
  String get aiConfiguration => 'AI設定';

  @override
  String get configureMultimodalApi => 'マルチモーダルAPIエンドポイントを設定';

  @override
  String get language => '言語';

  @override
  String get about => '概要';

  @override
  String version(String version) {
    return 'バージョン $version';
  }

  @override
  String get retry => '再試行';

  @override
  String get failedToInitializeStorage => 'ストレージの初期化に失敗';

  @override
  String string(int number) {
    return '弦$number';
  }

  @override
  String get start => '開始';

  @override
  String get stop => '停止';

  @override
  String get pause => '一時停止';

  @override
  String get manual => '手動';

  @override
  String get gradual => '徐々に';

  @override
  String get step => 'ステップ +5';

  @override
  String get interval => 'インターバル';

  @override
  String gradualTarget(int target) {
    return '徐々に → $target';
  }

  @override
  String get stepPlus => 'ステップ +5';

  @override
  String get intervalAlternating => '交互インターバル';

  @override
  String get firstBeatAccent => '最初の拍が強拍';

  @override
  String get manualDescription => '手動制御、テンポ一定';

  @override
  String get gradualDescription => '4拍ごとに±1 BPM自動変更';

  @override
  String get stepDescription => '4拍ごとに+5 BPM自動増加';

  @override
  String get intervalDescription => '高低速交互練習、4拍ごと切替';

  @override
  String get targetBpm => '目標BPM: ';
}
