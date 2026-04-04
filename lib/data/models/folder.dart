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
