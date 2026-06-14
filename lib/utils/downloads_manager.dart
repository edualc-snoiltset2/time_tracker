// lib/utils/downloads_manager.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Summary of files eligible for clean-up.
class OldDownloadsSummary {
  const OldDownloadsSummary({required this.files, required this.totalBytes});

  /// Files older than the configured age.
  final List<File> files;

  /// Combined size, in bytes, of all [files].
  final int totalBytes;

  int get count => files.length;

  bool get isEmpty => files.isEmpty;
}

/// Result of a delete operation.
class DeletionResult {
  const DeletionResult({required this.deletedCount, required this.freedBytes});

  final int deletedCount;
  final int freedBytes;
}

/// Manages the app's own "downloads" directory — the folder where generated
/// artifacts such as invoice PDFs are saved — and provides maintenance
/// helpers for pruning old files.
///
/// This deliberately operates only on the app-managed downloads directory
/// (under the application documents directory), never the operating system's
/// personal Downloads folder, so clean-up only ever touches files this app
/// created.
class DownloadsManager {
  /// Allows tests to point the manager at a temporary directory instead of the
  /// real platform documents directory.
  DownloadsManager({Directory? directoryOverride})
      : _directoryOverride = directoryOverride;

  final Directory? _directoryOverride;

  /// Files older than this are considered stale and eligible for clean-up.
  static const Duration defaultMaxAge = Duration(days: 90);

  /// Resolves (and creates, if necessary) the app-managed downloads directory.
  Future<Directory> resolveDirectory() async {
    if (_directoryOverride != null) {
      if (!await _directoryOverride!.exists()) {
        await _directoryOverride!.create(recursive: true);
      }
      return _directoryOverride!;
    }
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'downloads'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Saves [bytes] as a PDF for the given [invoiceId] inside the downloads
  /// directory and returns the written file.
  Future<File> saveInvoicePdf(String invoiceId, Uint8List bytes) async {
    final dir = await resolveDirectory();
    final safeId = invoiceId.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final file = File(p.join(dir.path, 'invoice_$safeId.pdf'));
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Returns the files in the downloads directory whose last-modified time is
  /// older than [maxAge] relative to [now] (defaults to the current time).
  Future<OldDownloadsSummary> findOldDownloads({
    Duration maxAge = defaultMaxAge,
    DateTime? now,
  }) async {
    final dir = await resolveDirectory();
    final cutoff = (now ?? DateTime.now()).subtract(maxAge);

    final old = <File>[];
    var totalBytes = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      if (stat.modified.isBefore(cutoff)) {
        old.add(entity);
        totalBytes += stat.size;
      }
    }
    return OldDownloadsSummary(files: old, totalBytes: totalBytes);
  }

  /// Deletes files in the downloads directory older than [maxAge] and returns
  /// how many were removed along with the freed space.
  Future<DeletionResult> deleteOldDownloads({
    Duration maxAge = defaultMaxAge,
    DateTime? now,
  }) async {
    final summary = await findOldDownloads(maxAge: maxAge, now: now);
    var deleted = 0;
    for (final file in summary.files) {
      try {
        await file.delete();
        deleted++;
      } on FileSystemException {
        // Skip files that can't be removed (e.g. locked); keep going.
      }
    }
    return DeletionResult(deletedCount: deleted, freedBytes: summary.totalBytes);
  }
}

/// Formats a byte count into a short human-readable string.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024;
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
}
