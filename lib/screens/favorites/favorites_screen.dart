import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/favorites_provider.dart';
import 'folder_browser.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FavoritesProvider()..initialize(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: const FolderBrowser(),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () => _showAddTabDialog(context),
        ),
      ),
    );
  }

  void _showAddTabDialog(BuildContext context) {
    // TODO: Implement add tab dialog
  }
}
