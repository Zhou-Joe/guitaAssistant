import 'package:flutter/foundation.dart';
import 'package:guitar_assistant/data/models/folder.dart';
import 'package:guitar_assistant/data/models/tab.dart';
import 'package:guitar_assistant/data/repositories/folder_repository.dart';
import 'package:guitar_assistant/data/repositories/tab_repository.dart';

class FavoritesProvider extends ChangeNotifier {
  final FolderRepository _folderRepository = FolderRepository();
  final TabRepository _tabRepository = TabRepository();

  List<Folder> _folders = [];
  List<Tab> _tabs = [];
  String? _currentFolderId;
  bool _isLoading = false;

  List<Folder> get folders => _folders;
  List<Tab> get tabs => _tabs;
  String? get currentFolderId => _currentFolderId;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    await _folderRepository.initialize();
    await _tabRepository.initialize();
    await loadFolders();
    await loadTabs();
  }

  Future<void> loadFolders() async {
    _isLoading = true;
    notifyListeners();
    _folders = await _folderRepository.getAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTabs() async {
    _isLoading = true;
    notifyListeners();
    _tabs = await _tabRepository.getAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> navigateToFolder(String? folderId) async {
    _currentFolderId = folderId;
    notifyListeners();
  }

  List<Tab> getTabsInCurrentFolder() {
    if (_currentFolderId == null) return _tabs;
    return _tabs.where((t) => t.folderId == _currentFolderId).toList();
  }
}
