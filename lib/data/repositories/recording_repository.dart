import 'package:hive_flutter/hive_flutter.dart';
import 'package:guitar_assistant/data/models/recording.dart';
import 'package:guitar_assistant/config/constants.dart';

class RecordingRepository {
  late final Box _box;

  Future<void> initialize() async {
    _box = await Hive.openBox(AppConstants.recordingsBox);
  }

  Future<List<Recording>> getAll() async {
    return _box.values.cast<Recording>().toList();
  }

  Future<Recording?> getById(String id) async {
    return _box.get(id) as Recording?;
  }

  Future<void> create(Recording recording) async {
    await _box.put(recording.id, recording);
  }

  Future<void> update(Recording recording) async {
    await _box.put(recording.id, recording);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
