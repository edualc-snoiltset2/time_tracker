import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:time_tracker/utils/downloads_manager.dart';

void main() {
  late Directory tempDir;
  late DownloadsManager manager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('downloads_test');
    manager = DownloadsManager(directoryOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Creates a file in the temp dir and sets its last-modified time.
  Future<File> makeFile(String name, {required DateTime modified}) async {
    final file = File(p.join(tempDir.path, name));
    await file.writeAsString('x' * 10);
    await file.setLastModified(modified);
    return file;
  }

  final now = DateTime(2026, 6, 14);

  test('findOldDownloads only returns files older than maxAge', () async {
    await makeFile('old.pdf', modified: now.subtract(const Duration(days: 120)));
    await makeFile('edge.pdf', modified: now.subtract(const Duration(days: 91)));
    await makeFile('recent.pdf', modified: now.subtract(const Duration(days: 10)));

    final summary = await manager.findOldDownloads(now: now);

    expect(summary.count, 2);
    expect(summary.totalBytes, 20);
    expect(
      summary.files.map((f) => p.basename(f.path)).toSet(),
      {'old.pdf', 'edge.pdf'},
    );
  });

  test('deleteOldDownloads removes only stale files', () async {
    await makeFile('old.pdf', modified: now.subtract(const Duration(days: 200)));
    await makeFile('recent.pdf', modified: now.subtract(const Duration(days: 5)));

    final result = await manager.deleteOldDownloads(now: now);

    expect(result.deletedCount, 1);
    expect(result.freedBytes, 10);
    expect(File(p.join(tempDir.path, 'old.pdf')).existsSync(), isFalse);
    expect(File(p.join(tempDir.path, 'recent.pdf')).existsSync(), isTrue);
  });

  test('saveInvoicePdf writes a sanitized filename', () async {
    final file = await manager.saveInvoicePdf(
      'INV/2026 #1',
      Uint8List.fromList([1, 2, 3]),
    );

    expect(p.basename(file.path), 'invoice_INV_2026__1.pdf');
    expect(await file.readAsBytes(), [1, 2, 3]);
  });

  test('empty directory yields an empty summary', () async {
    final summary = await manager.findOldDownloads(now: now);
    expect(summary.isEmpty, isTrue);
    expect(summary.totalBytes, 0);
  });
}
