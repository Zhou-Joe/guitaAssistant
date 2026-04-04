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
