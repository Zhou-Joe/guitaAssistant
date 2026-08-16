// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '吉他助手';

  @override
  String get home => '首页';

  @override
  String get tuner => '调音器';

  @override
  String get metronome => '节拍器';

  @override
  String get favorites => '收藏';

  @override
  String get record => '录音';

  @override
  String get analysis => '分析';

  @override
  String get settings => '设置';

  @override
  String get tunerSubtitle => '六弦吉他调音';

  @override
  String get metronomeSubtitle => '按节拍练习';

  @override
  String get favoritesSubtitle => '您的吉他谱';

  @override
  String get recordSubtitle => '录制练习';

  @override
  String get analysisSubtitle => '分析演奏';

  @override
  String get settingsSubtitle => '应用设置';

  @override
  String get tapToStartTuning => '点击开始调音';

  @override
  String get selectString => '选择琴弦';

  @override
  String get standardTuning => '标准调音';

  @override
  String get bpm => 'BPM';

  @override
  String bpmValue(int bpm) {
    return '$bpm BPM';
  }

  @override
  String get timeSignature => '拍号';

  @override
  String get tempoMode => '节奏模式';

  @override
  String get sound => '音色';

  @override
  String get normal => '正常';

  @override
  String get accent => '重音';

  @override
  String get random => '随机';

  @override
  String get classic => '经典';

  @override
  String get digital => '数字';

  @override
  String get woodblock => '木块';

  @override
  String get hihat => '踩镲';

  @override
  String get cowbell => '牛铃';

  @override
  String get aiFeatures => 'AI功能';

  @override
  String get aiConfiguration => 'AI配置';

  @override
  String get configureMultimodalApi => '配置多模态API端点';

  @override
  String get language => '语言';

  @override
  String get about => '关于';

  @override
  String version(String version) {
    return '版本 $version';
  }

  @override
  String get retry => '重试';

  @override
  String get failedToInitializeStorage => '存储初始化失败';

  @override
  String string(int number) {
    return '第$number弦';
  }

  @override
  String get start => '开始';

  @override
  String get stop => '停止';

  @override
  String get pause => '暂停';

  @override
  String get manual => '手动';

  @override
  String get gradual => '渐进';

  @override
  String get step => '步进 +5';

  @override
  String get interval => '间隔';

  @override
  String gradualTarget(int target) {
    return '渐进 → $target';
  }

  @override
  String get stepPlus => '步进 +5';

  @override
  String get intervalAlternating => '间隔交替';

  @override
  String get firstBeatAccent => '第一拍为强拍';

  @override
  String get manualDescription => '手动控制速度，保持不变';

  @override
  String get gradualDescription => '每4拍自动±1 BPM，向目标渐进';

  @override
  String get stepDescription => '每4拍自动+5 BPM，逐步加速';

  @override
  String get intervalDescription => '高低速交替练习，每4拍切换';

  @override
  String get targetBpm => '目标BPM: ';
}
