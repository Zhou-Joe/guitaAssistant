import 'package:flutter/foundation.dart';
import 'package:guitar_assistant/data/models/tab.dart';
import 'package:guitar_assistant/data/repositories/tab_repository.dart';

class FavoritesProvider extends ChangeNotifier {
  final TabRepository _tabRepository = TabRepository();

  List<Tab> _tabs = [];
  String _searchQuery = '';
  bool _isLoading = false;

  List<Tab> get tabs => _tabs;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  void initialize() {
    _tabRepository.initialize();
    loadTabs();
  }

  void loadTabs() {
    _isLoading = true;
    notifyListeners();
    _tabs = _tabRepository.getAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTab(Tab tab) async {
    await _tabRepository.create(tab);
    loadTabs();
  }

  Future<void> deleteTab(String id) async {
    await _tabRepository.delete(id);
    loadTabs();
  }

  Future<void> updateTab(Tab tab) async {
    await _tabRepository.update(tab);
    loadTabs();
  }

  List<Tab> getFilteredTabs() {
    if (_searchQuery.isEmpty) return _tabs;
    return _tabs.where((t) {
      return t.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }
}