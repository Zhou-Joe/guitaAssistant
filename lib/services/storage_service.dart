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
    await Directory('${_appDirectory!.path}/${AppConstants.analysisFolder}').create(recursive: true);
  }

  String get tabsPath => '${_appDirectory!.path}/${AppConstants.tabsFolder}';
  String get audioRecordingsPath => '${_appDirectory!.path}/${AppConstants.recordingsFolder}/audio';
  String get videoRecordingsPath => '${_appDirectory!.path}/${AppConstants.recordingsFolder}/video';
  String get analysisPath => '${_appDirectory!.path}/${AppConstants.analysisFolder}';

  Future<bool> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) { await file.delete(); return true; }
    return false;
  }

  Future<bool> fileExists(String path) async => File(path).exists();
  Future<int> getFileSize(String path) async => File(path).length();
}
