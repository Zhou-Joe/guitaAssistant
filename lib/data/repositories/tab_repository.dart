import 'package:hive_flutter/hive_flutter.dart';
import 'package:guitar_assistant/data/models/tab.dart';
import 'package:guitar_assistant/config/constants.dart';

class TabRepository {
  Box<Tab>? _box;

  void initialize() {
    _box = Hive.box<Tab>(AppConstants.tabsBox);
  }

  List<Tab> getAll() {
    return _box?.values.toList() ?? [];
  }

  Tab? getById(String id) {
    return _box?.get(id);
  }

  Future<void> create(Tab tab) async {
    await _box?.put(tab.id, tab);
  }

  Future<void> update(Tab tab) async {
    await _box?.put(tab.id, tab);
  }

  Future<void> delete(String id) async {
    await _box?.delete(id);
  }

  List<Tab> getByFolderId(String folderId) {
    return _box?.values.where((t) => t.folderId == folderId).toList() ?? [];
  }
}