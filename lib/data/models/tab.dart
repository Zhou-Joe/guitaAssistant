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
