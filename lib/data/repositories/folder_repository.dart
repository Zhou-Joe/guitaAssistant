import 'package:hive_flutter/hive_flutter.dart';
import 'package:guitar_assistant/data/models/folder.dart';
import 'package:guitar_assistant/config/constants.dart';

class FolderRepository {
  late final Box _box;

  Future<void> initialize() async {
    _box = await Hive.openBox(AppConstants.foldersBox);
  }

  Future<List<Folder>> getAll() async {
    return _box.values.cast<Folder>().toList();
  }

  Future<Folder?> getById(String id) async {
    return _box.get(id) as Folder?;
  }

  Future<void> create(Folder folder) async {
    await _box.put(folder.id, folder);
  }

  Future<void> update(Folder folder) async {
    await _box.put(folder.id, folder);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<List<Folder>> getByParentId(String? parentId) async {
    return _box.values.where((f) => (f as Folder).parentId == parentId).cast<Folder>().toList();
  }
}
