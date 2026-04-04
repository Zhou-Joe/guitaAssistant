import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_assistant/data/models/folder.dart';

void main() {
  group('Folder', () {
    test('creates with current time when not provided', () {
      final folder = Folder(id: 'test', name: 'Test');
      expect(folder.createdAt, isA<DateTime>());
    });
    test('copyWith creates new instance', () {
      final original = Folder(id: 'orig', name: 'Original');
      final updated = original.copyWith(name: 'Updated');
      expect(updated.name, 'Updated');
      expect(original.name, 'Original');
    });
  });
}
