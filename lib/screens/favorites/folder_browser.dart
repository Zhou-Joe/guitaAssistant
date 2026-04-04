import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guitar_assistant/providers/favorites_provider.dart';

class FolderBrowser extends StatelessWidget {
  const FolderBrowser({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final tabs = provider.getTabsInCurrentFolder();

        if (tabs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No tabs yet', style: TextStyle(color: Colors.grey[600])),
                const Text('Tap + to add a tab', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: tabs.length,
          itemBuilder: (context, index) {
            final tab = tabs[index];
            return Card(
              child: Column(
                children: [
                  Expanded(
                    child: Icon(
                      tab.fileType.name == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                      size: 48,
                      color: tab.isFavorite ? Colors.red : Colors.grey,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      tab.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
