import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:guitar_assistant/config/theme.dart';
import 'package:guitar_assistant/data/models/tab.dart' as guitar_tab;
import 'package:guitar_assistant/providers/metronome_provider.dart';

class TabViewerScreen extends StatefulWidget {
  final guitar_tab.Tab tab;

  const TabViewerScreen({super.key, required this.tab});

  @override
  State<TabViewerScreen> createState() => _TabViewerScreenState();
}

class _TabViewerScreenState extends State<TabViewerScreen> {
  bool _showMetronomePanel = false;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.tab.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.music_note,
              color: _showMetronomePanel ? AppColors.cta : AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _showMetronomePanel = !_showMetronomePanel),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sheet music viewer
          Expanded(child: _buildContentViewer()),
          // Metronome panel
          if (_showMetronomePanel) _buildMetronomePanel(),
        ],
      ),
    );
  }

  Widget _buildContentViewer() {
    if (widget.tab.fileType == guitar_tab.TabFileType.pdf) {
      return PDFView(
        filePath: widget.tab.filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onPageChanged: (page, total) {
          setState(() {
            _currentPage = page ?? 0;
            _totalPages = total ?? 0;
          });
        },
        onError: (error) {
          debugPrint('PDF error: $error');
        },
      );
    } else {
      // Image viewer
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.file(
            File(widget.tab.filePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64, color: AppColors.textMuted),
          ),
        ),
      );
    }
  }

  Widget _buildMetronomePanel() {
    return Consumer<MetronomeProvider>(
      builder: (context, provider, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // BPM Control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: AppColors.textPrimary),
                        onPressed: () => provider.setBpm((provider.bpm - 5).clamp(30, 250)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${provider.bpm} BPM',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: AppColors.textPrimary),
                        onPressed: () => provider.setBpm((provider.bpm + 5).clamp(30, 250)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Play/Stop button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: provider.isPlaying ? AppColors.error : AppColors.cta,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: provider.togglePlay,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(provider.isPlaying ? Icons.pause : Icons.play_arrow, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            provider.isPlaying ? 'Stop' : 'Start Practice',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}