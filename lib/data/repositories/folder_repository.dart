import 'package:hive_flutter/hive_flutter.dart';
import 'package:guitar_assistant/data/models/folder.dart';
import 'package:guitar_assistant/config/constants.dart';

class FolderRepository {
  Box<Folder>? _box;

  void initialize() {
    _box = Hive.box<Folder>(AppConstants.foldersBox);
  }

  List<Folder> getAll() {
    return _box?.values.toList() ?? [];
  }

  Folder? getById(String id) {
    return _box?.get(id);
  }

  Future<void> create(Folder folder) async {
    await _box?.put(folder.id, folder);
  }

  Future<void> update(Folder folder) async {
    await _box?.put(folder.id, folder);
  }

  Future<void> delete(String id) async {
    await _box?.delete(id);
  }

  List<Folder> getByParentId(String? parentId) {
    return _box?.values.where((f) => f.parentId == parentId).toList() ?? [];
  }
}