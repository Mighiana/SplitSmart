import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../providers/app_state.dart';
import 'database_service.dart';
import 'db_key_service.dart';

class BackupPreview {
  final int fileCount;
  final int dbSizeKb;
  const BackupPreview({required this.fileCount, required this.dbSizeKb});
}

/// Outcome of a restore attempt. The DB inside a backup can be:
///  - legacy plaintext (pre-encryption backups),
///  - keyed with THIS device's key (local/auto backups),
///  - keyed with a user passphrase (portable/shared backups).
enum RestoreResult {
  success,
  invalidFile,

  /// Encrypted with a passphrase — caller must prompt and retry.
  needsPassphrase,

  /// A passphrase was supplied but does not open this backup.
  wrongPassphrase,
}

class BackupService {
  BackupService._();

  static const _prefAutoBackup = 'auto_backup_enabled';
  static const _maxBackupZipBytes = 100 * 1024 * 1024; // 100 MB
  static const _maxBackupExpandedBytes = 250 * 1024 * 1024; // 250 MB
  static const _maxBackupEntryBytes = 100 * 1024 * 1024; // 100 MB
  static const _maxBackupEntries = 1000;

  static bool _archiveLooksSafe(Archive archive) {
    if (archive.length > _maxBackupEntries) return false;

    var expandedBytes = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      if (file.size < 0 || file.size > _maxBackupEntryBytes) return false;
      expandedBytes += file.size;
      if (expandedBytes > _maxBackupExpandedBytes) return false;
    }

    return true;
  }

  /// Create a backup ZIP.
  ///
  /// With a [passphrase], the DB goes in as a portable SQLCipher snapshot
  /// keyed to that passphrase — restorable on any device. Without one (local
  /// and auto backups), the raw device-keyed DB files are zipped; such a
  /// backup only restores on THIS device while its key survives.
  static Future<File> createBackup({String? passphrase}) async {
    final docs = await getApplicationDocumentsDirectory();
    final dbDir = await getDatabasesPath();
    final dbFile = File(p.join(dbDir, 'splitsmart_v3.db'));

    final now = DateTime.now();
    final name = 'splitsmart_backup_${now.year}_${now.month.toString().padLeft(2, "0")}_${now.day.toString().padLeft(2, "0")}.zip';
    final zipFile = File(p.join(docs.path, name));

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);

    File? portableTmp;
    if (passphrase != null) {
      // Portable snapshot via sqlcipher_export — consistent, no WAL sidecars,
      // and the live connection stays open.
      portableTmp = File(p.join(docs.path, 'portable_export.db'));
      await DatabaseService.instance
          .exportEncryptedCopy(portableTmp.path, passphrase);
      encoder.addFile(portableTmp, 'splitsmart.db');
    } else {
      // Close DB connection to flush WAL and release locks before zipping
      await DatabaseService.instance.closeDatabase();

      if (await dbFile.exists()) {
        encoder.addFile(dbFile, 'splitsmart.db');
      }
      // Add WAL and SHM if they exist
      final dbWalFile = File(p.join(dbDir, 'splitsmart_v3.db-wal'));
      final dbShmFile = File(p.join(dbDir, 'splitsmart_v3.db-shm'));
      if (await dbWalFile.exists()) {
        encoder.addFile(dbWalFile, 'splitsmart.db-wal');
      }
      if (await dbShmFile.exists()) {
        encoder.addFile(dbShmFile, 'splitsmart.db-shm');
      }
    }

    // Add Receipts
    final receiptsDir = Directory(p.join(docs.path, 'receipts'));
    if (await receiptsDir.exists()) {
      encoder.addDirectory(receiptsDir, includeDirName: true);
    }

    encoder.close();
    if (portableTmp != null && await portableTmp.exists()) {
      await portableTmp.delete();
    }

    // The database will be re-opened automatically on the next query
    // by DatabaseService.instance.get _database

    return zipFile;
  }

  static Future<void> shareBackup(File file, BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip')],
        subject: 'Splitzee Backup',
        text: 'Splitzee data + receipts backup.',
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      ),
    );
  }

  static Future<void> shareSupportLogs(BuildContext context) async {
    final docs = await getApplicationDocumentsDirectory();
    final logFile = File(p.join(docs.path, 'app_errors.log'));
    if (!await logFile.exists()) {
      // Capture messenger before any await gap
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No crash logs found! Your app is running perfectly.', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(logFile.path, mimeType: 'text/plain')],
        subject: 'Splitzee Error Logs',
        text: 'Attached are the crash logs for Splitzee.',
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      ),
    );
  }

  static Future<BackupPreview?> previewFile(File file) async {
    try {
      if (await file.length() > _maxBackupZipBytes) return null;
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      if (!_archiveLooksSafe(archive)) return null;
      int size = 0;
      for (final f in archive) {
        if (f.name == 'splitsmart.db') size = f.size ~/ 1024;
      }
      return BackupPreview(fileCount: archive.length, dbSizeKb: size);
    } catch (_) {
      return null;
    }
  }

  static Future<File?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  /// Restore from a backup ZIP. Handles all three DB flavors (see
  /// [RestoreResult]); the restored DB always ends up keyed to THIS device's
  /// key, and legacy plaintext DBs are encrypted during the process.
  static Future<RestoreResult> restoreFromFile(
    File zipFile,
    AppState state, {
    String? passphrase,
  }) async {
    File? stagedDb;
    try {
      if (await zipFile.length() > _maxBackupZipBytes) {
        debugPrint('[BackupService] restore rejected: backup file is too large');
        return RestoreResult.invalidFile;
      }

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      if (!_archiveLooksSafe(archive)) {
        debugPrint('[BackupService] restore rejected: unsafe archive size');
        return RestoreResult.invalidFile;
      }

      final docs = await getApplicationDocumentsDirectory();
      final dbDir = await getDatabasesPath();
      final dbEntry = archive.files
          .where((f) => f.isFile && f.name == 'splitsmart.db')
          .firstOrNull;
      if (dbEntry == null) return RestoreResult.invalidFile;

      // Stage the DB and work out which key opens it BEFORE touching the
      // live database, so a wrong passphrase leaves current data intact.
      stagedDb = File(p.join(docs.path, 'restore_staged.db'));
      await stagedDb.writeAsBytes(dbEntry.content as List<int>, flush: true);

      final deviceKey = await DbKeyService.getOrCreateKey();
      final headerBytes = (dbEntry.content as List<int>).take(16).toList();
      final isPlaintext =
          String.fromCharCodes(headerBytes).startsWith('SQLite format 3');

      var includeSidecars = false;
      if (isPlaintext) {
        // Legacy backup: placed as-is (with WAL/SHM), then encrypted in
        // place below once the sidecars are merged.
        includeSidecars = true;
      } else if (await DatabaseService.canOpenWithKey(
          stagedDb.path, deviceKey)) {
        includeSidecars = true; // device-keyed local/auto backup
      } else if (passphrase == null) {
        return RestoreResult.needsPassphrase;
      } else if (await DatabaseService.canOpenWithKey(
          stagedDb.path, passphrase)) {
        // Portable backup: re-encrypt the snapshot onto the device key.
        final rekeyed = File(p.join(docs.path, 'restore_rekeyed.db'));
        await DatabaseService.rekeyCopy(
            stagedDb.path, passphrase, rekeyed.path, deviceKey);
        await stagedDb.delete();
        stagedDb = rekeyed;
      } else {
        return RestoreResult.wrongPassphrase;
      }

      // Close the active DB connection before overwriting the file
      await DatabaseService.instance.closeDatabase();

      final targetDbFile = File(p.join(dbDir, 'splitsmart_v3.db'));
      await targetDbFile.parent.create(recursive: true);
      await stagedDb.copy(targetDbFile.path);
      await stagedDb.delete();
      stagedDb = null;

      // Stale sidecars from the previous DB must never pair with the
      // restored file; rewrite them only for flavors that ship their own.
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('${targetDbFile.path}$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }

      for (final file in archive) {
        if (file.isFile) {
          if (includeSidecars && file.name == 'splitsmart.db-wal') {
            final targetWal = File(p.join(dbDir, 'splitsmart_v3.db-wal'));
            await targetWal.writeAsBytes(file.content as List<int>, flush: true);
          } else if (includeSidecars && file.name == 'splitsmart.db-shm') {
            final targetShm = File(p.join(dbDir, 'splitsmart_v3.db-shm'));
            await targetShm.writeAsBytes(file.content as List<int>, flush: true);
          } else if (file.name.startsWith('receipts/')) {
             // SEC-4: Sanitize filename to prevent path traversal attacks
             final safeName = p.basename(file.name);
             if (safeName.isEmpty || safeName.contains('..') || safeName.contains('/') || safeName.contains('\\')) {
               continue; // Skip malicious entry
             }
             final outFile = File(p.join(docs.path, 'receipts', safeName));
             await outFile.parent.create(recursive: true);
             await outFile.writeAsBytes(file.content as List<int>, flush: true);
          }
        }
      }

      // Legacy plaintext restores get encrypted now (WAL merged during the
      // export); newer flavors are already on the device key.
      if (isPlaintext) {
        await DatabaseService.encryptPlaintextDb(targetDbFile.path, deviceKey);
      }

      await state.reloadFromDatabase();
      return RestoreResult.success;
    } catch (e) {
      debugPrint('[BackupService] restore error: $e');
      return RestoreResult.invalidFile;
    } finally {
      if (stagedDb != null && await stagedDb.exists()) {
        await stagedDb.delete();
      }
    }
  }

  static Future<List<File>> listLocalBackups() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip') && f.path.contains('splitsmart_backup_'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
  }

  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefAutoBackup) ?? false;
  }

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoBackup, enabled);
  }

  static Future<DateTime?> lastAutoBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('last_auto_backup_ms');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> checkAutoBackup() async {
    final enabled = await isAutoBackupEnabled();
    if (!enabled) return;
    
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('last_auto_backup_ms') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - lastMs < 7 * 24 * 60 * 60 * 1000) return;

    try {
      await createBackup();
      await prefs.setInt('last_auto_backup_ms', nowMs);
    } catch (e) {
      debugPrint('[BackupService] auto-backup failed: $e');
    }
  }
}
