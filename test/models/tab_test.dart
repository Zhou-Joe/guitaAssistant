import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_assistant/data/models/tab.dart';

void main() {
  group('Tab', () {
    test('creates with default values', () {
      final tab = Tab(
        id: 'tab-1', title: 'Test', filePath: '/path.pdf',
        fileType: TabFileType.pdf, folderId: 'folder-1',
      );
      expect(tab.isFavorite, false);
      expect(tab.tags, isEmpty);
    });
  });
}
