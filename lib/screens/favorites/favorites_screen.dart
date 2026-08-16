import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:guitar_assistant/config/theme.dart';
import 'package:guitar_assistant/providers/favorites_provider.dart';
import 'package:guitar_assistant/data/models/tab.dart' as guitar_tab;
import 'package:guitar_assistant/l10n/app_localizations.dart';
import 'tab_viewer_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider(
      create: (_) => FavoritesProvider()..initialize(),
      child: Consumer<FavoritesProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Text(l10n.favorites),
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
            ),
            body: Column(
              children: [
                _buildSearchBar(provider),
                Expanded(child: _buildTabList(provider)),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              backgroundColor: AppColors.cta,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add, size: 28),
              onPressed: () => _importFile(context, provider),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(FavoritesProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search sheet music...',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: provider.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    provider.clearSearch();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: (value) => provider.setSearchQuery(value),
      ),
    );
  }

  Widget _buildTabList(FavoritesProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.cta));
    }

    final tabs = provider.getFilteredTabs();

    if (tabs.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: tabs.length,
      itemBuilder: (context, index) => _buildTabItem(context, provider, tabs[index]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.library_music, size: 64, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          const Text('No sheet music yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Tap + to import PDF or images', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, FavoritesProvider provider, guitar_tab.Tab tab) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceElevated, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            tab.fileType == guitar_tab.TabFileType.pdf ? Icons.picture_as_pdf : Icons.image,
            color: tab.fileType == guitar_tab.TabFileType.pdf ? AppColors.error : AppColors.secondary,
          ),
        ),
        title: Text(
          tab.title,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          tab.fileType.name.toUpperCase(),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          onSelected: (value) => _handleMenuAction(context, provider, tab, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.open_in_new, color: AppColors.cta),
                  SizedBox(width: 12),
                  Text('Open', style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit, color: AppColors.secondary),
                  SizedBox(width: 12),
                  Text('Rename', style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: AppColors.error),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _openTab(context, tab),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, FavoritesProvider provider, guitar_tab.Tab tab, String action) {
    switch (action) {
      case 'open':
        _openTab(context, tab);
        break;
      case 'rename':
        _showRenameDialog(context, provider, tab);
        break;
      case 'delete':
        _confirmDelete(context, provider, tab);
        break;
    }
  }

  void _showRenameDialog(BuildContext context, FavoritesProvider provider, guitar_tab.Tab tab) {
    final controller = TextEditingController(text: tab.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final updatedTab = tab.copyWith(title: newName);
                provider.updateTab(updatedTab);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cta, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, FavoritesProvider provider, guitar_tab.Tab tab) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Delete "${tab.title}"?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteTab(tab.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFile(BuildContext context, FavoritesProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          final fileType = p.extension(file.path!).toLowerCase() == '.pdf'
              ? guitar_tab.TabFileType.pdf
              : guitar_tab.TabFileType.image;

          final defaultName = p.basenameWithoutExtension(file.path!);

          // Show rename dialog immediately after import
          final controller = TextEditingController(text: defaultName);
          final newName = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Import File', style: TextStyle(color: AppColors.textPrimary)),
              content: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter name',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, controller.text.trim().isEmpty ? defaultName : controller.text.trim()),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.cta, foregroundColor: Colors.white),
                  child: const Text('Import'),
                ),
              ],
            ),
          );

          if (newName != null && mounted) {
            final tab = guitar_tab.Tab(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: newName,
              filePath: file.path!,
              fileType: fileType,
              folderId: 'default',
            );

            await provider.addTab(tab);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Imported: $newName'), backgroundColor: AppColors.surface),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error importing file: $e');
    }
  }

  void _openTab(BuildContext context, guitar_tab.Tab tab) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TabViewerScreen(tab: tab)),
    );
  }
}