import 'package:hive_flutter/hive_flutter.dart';
import 'package:guitar_assistant/data/models/tab.dart';
import 'package:guitar_assistant/config/constants.dart';

class TabRepository {
  late final Box _box;

  Future<void> initialize() async {
    _box = await Hive.openBox(AppConstants.tabsBox);
  }

  Future<List<Tab>> getAll() async {
    return _box.values.cast<Tab>().toList();
  }

  Future<Tab?> getById(String id) async {
    return _box.get(id) as Tab?;
  }

  Future<void> create(Tab tab) async {
    await _box.put(tab.id, tab);
  }

  Future<void> update(Tab tab) async {
    await _box.put(tab.id, tab);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<List<Tab>> getByFolderId(String folderId) async {
    return _box.values.where((t) => (t as Tab).folderId == folderId).cast<Tab>().toList();
  }

  Future<List<Tab>> getByTag(String tag) async {
    return _box.values.where((t) => (t as Tab).tags.contains(tag)).cast<Tab>().toList();
  }

  Future<List<Tab>> getFavorites() async {
    return _box.values.where((t) => (t as Tab).isFavorite).cast<Tab>().toList();
  }
}
