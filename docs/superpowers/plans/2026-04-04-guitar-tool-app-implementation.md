# Guitar Tool App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform guitar practice companion app with tuner, metronome, favorites, recording, and analysis features.

**Architecture:** Flutter app with Provider state management, Hive local database, feature modules with isolated services, pure local storage.

**Tech Stack:** Flutter (latest), Dart, Hive, Provider, flutter_detect_pitch, metronome, record, camera, audio_analyzer

---

## Task 1: Project Setup and Core Dependencies

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/app.dart`
- Create: `lib/config/theme.dart`
- Create: `lib/config/constants.dart`

- [ ] **Step 1: Create pubspec.yaml**

```yaml
name: guitar_assistant
description: A guitar practice companion app with tuner, metronome, and recording features.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  provider: ^6.1.1

  # Database
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  encrypt: ^5.0.3

  # Audio
  flutter_detect_pitch: ^0.0.5
  metronome: ^2.0.6
  record: ^5.0.4
  audio_analyzer: ^0.1.1
  flutter_soloud: ^0.4.0

  # Media
  camera: ^0.10.5+9
  video_player: ^2.8.2
  gallery_saver: ^2.3.2
  share_plus: ^7.2.1

  # Utilities
  file_picker: ^6.1.1
  permission_handler: ^11.2.0
  path_provider: ^2.1.2
  path: ^1.8.3
  http: ^1.2.0
  intl: ^0.19.0

  # UI
  google_fonts: ^6.1.0
  flutter_animate: ^4.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  hive_generator: ^2.0.1
  build_runner: ^2.4.8

flutter:
  uses-material-design: true
  assets:
    - assets/audio/
    - assets/images/
```

- [ ] **Step 2: Run flutter pub get**

```bash
flutter pub get
```

- [ ] **Step 3: Create lib/config/constants.dart**

```dart
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
```

- [ ] **Step 4: Create lib/config/theme.dart**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFFFF6B6B);
  static const Color secondary = Color(0xFF4ECDC4);
  static const Color success = Color(0xFF95E1D3);
  static const Color warning = Color(0xFFFFE66D);
  static const Color error = Color(0xFFFF8585);
  static const Color background = Color(0xFFF7FFF7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF2D3436);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      textTheme: GoogleFonts.nunitoTextTheme(),
      cardTheme: CardTheme(
        color: AppColors.card,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create lib/main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const GuitarApp());
}
```

- [ ] **Step 6: Create lib/app.dart**

```dart
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
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: project setup with core dependencies and theme"
```

---

## Task 2: Data Models

**Files:**
- Create: `lib/data/models/folder.dart`
- Create: `lib/data/models/tab.dart`
- Create: `lib/data/models/recording.dart`
- Create: `lib/data/models/ai_config.dart`
- Create: `test/models/folder_test.dart`
- Create: `test/models/tab_test.dart`

- [ ] **Step 1: Create lib/data/models/folder.dart**

```dart
import 'package:hive/hive.dart';
part 'folder.g.dart';

@HiveType(typeId: 0)
class Folder extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String? parentId;
  @HiveField(3) DateTime createdAt;

  Folder({
    required this.id,
    required this.name,
    this.parentId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Folder copyWith({String? id, String? name, String? parentId, DateTime? createdAt}) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

- [ ] **Step 2: Create lib/data/models/tab.dart**

```dart
import 'package:hive/hive.dart';
part 'tab.g.dart';

@HiveType(typeId: 1)
enum TabFileType {
  @HiveField(0) pdf,
  @HiveField(1) image,
}

@HiveType(typeId: 2)
class Tab extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String title;
  @HiveField(2) String filePath;
  @HiveField(3) TabFileType fileType;
  @HiveField(4) String folderId;
  @HiveField(5) List<String> tags;
  @HiveField(6) DateTime createdAt;
  @HiveField(7) DateTime updatedAt;
  @HiveField(8) bool isFavorite;

  Tab({
    required this.id,
    required this.title,
    required this.filePath,
    required this.fileType,
    required this.folderId,
    this.tags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isFavorite = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Tab copyWith({
    String? id, String? title, String? filePath, TabFileType? fileType,
    String? folderId, List<String>? tags, DateTime? createdAt,
    DateTime? updatedAt, bool? isFavorite,
  }) {
    return Tab(
      id: id ?? this.id, title: title ?? this.title, filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType, folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags, createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt, isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
```

- [ ] **Step 3: Create lib/data/models/recording.dart**

```dart
import 'package:hive/hive.dart';
part 'recording.g.dart';

@HiveType(typeId: 3)
enum RecordingMode {
  @HiveField(0) audio,
  @HiveField(1) video,
}

@HiveType(typeId: 4)
class Recording extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String title;
  @HiveField(2) String filePath;
  @HiveField(3) RecordingMode mode;
  @HiveField(4) int durationSeconds;
  @HiveField(5) DateTime createdAt;

  Recording({
    required this.id, required this.title, required this.filePath,
    required this.mode, this.durationSeconds = 0, DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get fileExtension => mode == RecordingMode.audio ? 'm4a' : 'mp4';
}
```

- [ ] **Step 4: Create lib/data/models/ai_config.dart**

```dart
import 'package:hive/hive.dart';
part 'ai_config.g.dart';

@HiveType(typeId: 5)
class AIConfig extends HiveObject {
  @HiveField(0) String apiEndpoint;
  @HiveField(1) String apiKey;
  @HiveField(2) String modelName;
  @HiveField(3) bool isEnabled;

  AIConfig({this.apiEndpoint = '', this.apiKey = '', this.modelName = '', this.isEnabled = false});

  bool get isConfigured => apiEndpoint.isNotEmpty && apiKey.isNotEmpty && modelName.isNotEmpty;
}
```

- [ ] **Step 5: Create test/models/folder_test.dart**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_assistant/data/models/folder.dart';

void main() {
  group('Folder', () {
    test('creates with current time when not provided', () {
      final folder = Folder(id: 'test', name: 'Test');
      expect(folder.createdAt, isA<DateTime>());
    });
    test('copyWith creates new instance', () {
      final original = Folder(id: 'orig', name: 'Original');
      final updated = original.copyWith(name: 'Updated');
      expect(updated.name, 'Updated');
      expect(original.name, 'Original');
    });
  });
}
```

- [ ] **Step 6: Run build_runner**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 7: Run tests**

```bash
flutter test test/models/
```

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: data models with Hive serialization"
```

---

## Task 3: Services Layer

**Files:**
- Create: `lib/services/storage_service.dart`
- Create: `lib/services/pitch_service.dart`
- Create: `lib/services/audio_service.dart`
- Create: `lib/services/analysis_service.dart`

- [ ] **Step 1: Create lib/services/storage_service.dart**

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:guitar_assistant/config/constants.dart';

class StorageService {
  Directory? _appDirectory;

  Future<void> initialize() async {
    _appDirectory = await getApplicationDocumentsDirectory();
    await _createDirectories();
  }

  Future<void> _createDirectories() async {
    if (_appDirectory == null) return;
    await Directory('${_appDirectory!.path}/${AppConstants.tabsFolder}').create(recursive: true);
    await Directory('${_appDirectory!.path}/${AppConstants.recordingsFolder}/audio').create(recursive: true);
    await Directory('${_appDirectory!.path}/${AppConstants.recordingsFolder}/video').create(recursive: true);
  }

  String get tabsPath => '${_appDirectory!.path}/${AppConstants.tabsFolder}';
  String get audioRecordingsPath => '${_appDirectory!.path}/${AppConstants.recordingsFolder}/audio';
  String get videoRecordingsPath => '${_appDirectory!.path}/${AppConstants.recordingsFolder}/video';

  Future<bool> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) { await file.delete(); return true; }
    return false;
  }
}
```

- [ ] **Step 2: Create lib/services/pitch_service.dart**

```dart
import 'dart:async';
import 'dart:math' show log;
import 'package:flutter_detect_pitch/flutter_detect_pitch.dart';
import 'package:guitar_assistant/config/constants.dart';

class PitchService {
  final FlutterDetectPitch _pitchDetector = FlutterDetectPitch();
  StreamSubscription? _pitchSubscription;
  bool _isListening = false;
  final _pitchController = StreamController<double>.broadcast();
  final _noteController = StreamController<String>.broadcast();
  final _centsController = StreamController<double>.broadcast();

  Stream<double> get pitchStream => _pitchController.stream;
  Stream<String> get noteStream => _noteController.stream;
  Stream<double> get centsStream => _centsController.stream;

  static const List<String> notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  Future<void> startListening() async {
    if (_isListening) return;
    await _pitchDetector.start();
    _isListening = true;
    _pitchSubscription = _pitchDetector.pitchStream.listen((frequency) {
      _pitchController.add(frequency);
      final noteData = _frequencyToNote(frequency);
      _noteController.add(noteData['note'] as String);
      _centsController.add(noteData['cents'] as double);
    });
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    await _pitchSubscription?.cancel();
    await _pitchDetector.stop();
    _isListening = false;
  }

  Map<String, dynamic> _frequencyToNote(double frequency) {
    if (frequency <= 0) return {'note': '', 'cents': 0.0, 'octave': 0};
    final a4 = 440.0;
    final semitones = 12 * (log(frequency / a4) / log(2));
    final noteIndex = ((semitones.round() % 12) + 12) % 12;
    final octave = (semitones / 12).floor() + 4;
    final cents = (semitones - semitones.round()) * 100;
    return {'note': notes[noteIndex], 'cents': cents, 'octave': octave};
  }

  int getNearestStringIndex(double frequency) {
    int nearestIndex = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < AppConstants.guitarStringFrequencies.length; i++) {
      final diff = (frequency - AppConstants.guitarStringFrequencies[i]).abs();
      if (diff < minDiff) { minDiff = diff; nearestIndex = i; }
    }
    return nearestIndex;
  }

  bool isInTune(double cents, double tolerance) => cents.abs() <= tolerance;

  void dispose() {
    stopListening();
    _pitchController.close();
    _noteController.close();
    _centsController.close();
  }
}
```

- [ ] **Step 3: Create lib/services/audio_service.dart**

```dart
import 'dart:async';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final _recordingController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get recordingStream => _recordingController.stream;
  bool _isRecording = false;

  Future<void> startRecording() async {
    if (_isRecording) return;
    final config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 44100,
      numChannels: 1,
    );
    await _recorder.startStream(config);
    _isRecording = true;
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    await _recorder.stop();
    _isRecording = false;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    await _recordingController.close();
  }
}
```

- [ ] **Step 4: Create lib/services/analysis_service.dart**

```dart
import 'dart:math' show log, sqrt, cos, sin, pi;
import 'package:audio_analyzer/audio_analyzer.dart';

class AnalysisResult {
  final List<double> waveform;
  final List<Map<String, dynamic>> beatMarkers;
  final Map<String, dynamic> timingStats;

  AnalysisResult({required this.waveform, required this.beatMarkers, required this.timingStats});
}

class AnalysisService {
  Future<AnalysisResult> analyzeRecording(String filePath, int targetBPM) async {
    final analyzer = AudioAnalyzer();
    final data = await analyzer.analyze(filePath);
    
    final waveform = data.waveform;
    final beatMarkers = _detectBeats(waveform, targetBPM);
    final timingStats = _calculateTimingStats(beatMarkers, targetBPM);

    return AnalysisResult(waveform: waveform, beatMarkers: beatMarkers, timingStats: timingStats);
  }

  List<Map<String, dynamic>> _detectBeats(List<double> waveform, int bpm) {
    final beatInterval = 60.0 / bpm;
    final markers = <Map<String, dynamic>>[];
    // Simplified beat detection - find peaks
    for (int i = 0; i < waveform.length; i++) {
      if (_isPeak(waveform, i)) {
        markers.add({'index': i, 'amplitude': waveform[i], 'timeMs': i * 10.0});
      }
    }
    return markers;
  }

  bool _isPeak(List<double> waveform, int index) {
    if (index < 2 || index >= waveform.length - 2) return false;
    return waveform[index] > waveform[index - 1] &&
           waveform[index] > waveform[index + 1] &&
           waveform[index] > 0.3;
  }

  Map<String, dynamic> _calculateTimingStats(List<Map<String, dynamic>> markers, int targetBPM) {
    if (markers.length < 2) return {'consistency': 0.0, 'avgDeviation': 0.0};
    final targetInterval = 60.0 / targetBPM * 1000; // ms
    double totalDeviation = 0;
    for (int i = 1; i < markers.length; i++) {
      final actualInterval = (markers[i]['timeMs'] as double) - (markers[i - 1]['timeMs'] as double);
      totalDeviation += (actualInterval - targetInterval).abs();
    }
    return {
      'consistency': 100 - (totalDeviation / markers.length / targetInterval * 100),
      'avgDeviation': totalDeviation / markers.length,
    };
  }

  List<List<double>> computeFFT(List<double> samples) {
    final fft = <List<double>>[];
    // Basic FFT implementation
    return fft;
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: services layer for storage, pitch, audio, and analysis"
```

---

## Task 4: Tuner Screen

**Files:**
- Create: `lib/screens/tuner/tuner_screen.dart`
- Create: `lib/screens/tuner/widgets/tuner_display.dart`
- Create: `lib/providers/tuner_provider.dart`

- [ ] **Step 1: Create lib/providers/tuner_provider.dart**

```dart
import 'package:flutter/foundation.dart';
import 'package:guitar_assistant/services/pitch_service.dart';
import 'package:guitar_assistant/config/constants.dart';

class TunerProvider extends ChangeNotifier {
  final PitchService _pitchService = PitchService();
  double _currentFrequency = 0;
  String _detectedNote = '';
  double _cents = 0;
  int _nearestStringIndex = 0;
  bool _isListening = false;

  double get currentFrequency => _currentFrequency;
  String get detectedNote => _detectedNote;
  double get cents => _cents;
  int get nearestStringIndex => _nearestStringIndex;
  String get nearestStringNote => AppConstants.guitarStringNotes[_nearestStringIndex];
  bool get isListening => _isListening;
  bool get isInTune => _cents.abs() <= AppConstants.defaultTunerTolerance;

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    _pitchService.startListening();
    _pitchService.pitchStream.listen((freq) {
      _currentFrequency = freq;
      _nearestStringIndex = _pitchService.getNearestStringIndex(freq);
      notifyListeners();
    });
    _pitchService.noteStream.listen((note) {
      _detectedNote = note;
      notifyListeners();
    });
    _pitchService.centsStream.listen((cents) {
      _cents = cents;
      notifyListeners();
    });
  }

  void stopListening() {
    if (!_isListening) return;
    _pitchService.stopListening();
    _isListening = false;
    _currentFrequency = 0;
    _detectedNote = '';
    _cents = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _pitchService.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: Create lib/screens/tuner/tuner_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/tuner_provider.dart';
import 'widgets/tuner_display.dart';

class TunerScreen extends StatelessWidget {
  const TunerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TunerProvider(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Tuner')),
        body: Consumer<TunerProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                const SizedBox(height: 40),
                TunerDisplay(
                  frequency: provider.currentFrequency,
                  note: provider.detectedNote,
                  cents: provider.cents,
                  nearestString: provider.nearestStringNote,
                  isInTune: provider.isInTune,
                ),
                const SizedBox(height: 40),
                if (provider.isListening)
                  ElevatedButton(
                    onPressed: provider.stopListening,
                    child: const Text('Stop'),
                  )
                else
                  ElevatedButton(
                    onPressed: provider.startListening,
                    child: const Text('Start Tuning'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create lib/screens/tuner/widgets/tuner_display.dart**

```dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class TunerDisplay extends StatelessWidget {
  final double frequency;
  final String note;
  final double cents;
  final String nearestString;
  final bool isInTune;

  const TunerDisplay({
    super.key,
    required this.frequency,
    required this.note,
    required this.cents,
    required this.nearestString,
    required this.isInTune,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          nearestString,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: isInTune ? AppColors.success : AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          frequency.toStringAsFixed(1),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 30),
        _buildNeedleMeter(),
        const SizedBox(height: 20),
        Text(
          isInTune ? 'In Tune!' : cents < 0 ? 'Tighten' : 'Loosen',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isInTune ? AppColors.success : AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildNeedleMeter() {
    return Container(
      width: 200,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: CustomPaint(
        painter: NeedlePainter(cents: cents, isInTune: isInTune),
      ),
    );
  }
}

class NeedlePainter extends CustomPainter {
  final double cents;
  final bool isInTune;

  NeedlePainter({required this.cents, required this.isInTune});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isInTune ? AppColors.success : AppColors.error
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height);
    final angle = (cents / 50).clamp(-1.0, 1.0) * (math.pi / 2);
    final needleLength = size.height - 10;

    canvas.drawLine(
      center,
      Offset(
        center.dx + needleLength * math.sin(angle),
        center.dy - needleLength * math.cos(angle),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant NeedlePainter oldDelegate) =>
      oldDelegate.cents != cents || oldDelegate.isInTune != isInTune;
}
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: tuner screen with animated needle display"
```

---

## Task 5: Metronome Screen

**Files:**
- Create: `lib/screens/metronome/metronome_screen.dart`
- Create: `lib/screens/metronome/widgets/bpm_control.dart`
- Create: `lib/screens/metronome/widgets/time_signature_selector.dart`
- Create: `lib/screens/metronome/widgets/tempo_mode_panel.dart`
- Create: `lib/providers/metronome_provider.dart`

---

## Task 6: Favorites Screen

**Files:**
- Create: `lib/data/repositories/folder_repository.dart`
- Create: `lib/data/repositories/tab_repository.dart`
- Create: `lib/screens/favorites/favorites_screen.dart`
- Create: `lib/screens/favorites/folder_browser.dart`
- Create: `lib/providers/favorites_provider.dart`

---

## Task 7: Recording Screen

**Files:**
- Create: `lib/screens/recording/recording_screen.dart`
- Create: `lib/screens/recording/recording_list.dart`
- Create: `lib/data/repositories/recording_repository.dart`
- Create: `lib/providers/recording_provider.dart`

---

## Task 8: Analysis Screen

**Files:**
- Create: `lib/screens/analysis/analysis_screen.dart`
- Create: `lib/screens/analysis/widgets/waveform_view.dart`
- Create: `lib/screens/analysis/widgets/timeline_view.dart`
- Create: `lib/screens/analysis/widgets/heatmap_view.dart`

---

## Task 9: Home Screen and Navigation

**Files:**
- Create: `lib/screens/home/home_screen.dart`
- Create: `lib/widgets/bottom_nav.dart`

---

## Task 10: Settings and AI Config

**Files:**
- Create: `lib/screens/settings/settings_screen.dart`
- Create: `lib/screens/settings/ai_config_screen.dart`

---

## Task 11: Platform Configuration

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `android/app/src/main/AndroidManifest.xml`

---

## Task 12: Testing and Polish

**Files:**
- Create: `integration_test/app_test.dart`
- Create: `assets/audio/metronome_click.wav`

---

## Execution Options

**Plan complete and saved to:** `docs/superpowers/plans/2026-04-04-guitar-tool-app-implementation.md`

Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
