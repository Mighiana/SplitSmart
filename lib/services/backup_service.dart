import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:sqflite/sqflite.dart';
import '../providers/app_state.dart';
import 'database_service.dart';

class BackupPreview {
  final int fileCount;
  final int dbSizeKb;
  const BackupPreview({required this.fileCount, required this.dbSizeKb});
}

class BackupService {
  BackupService._();

  static const _prefAutoBackup = 'auto_backup_enabled';

  static Future<File> createBackup() async {
    final docs = await getApplicationDocumentsDirectory();
    final dbDir = await getDatabasesPath();
    final dbFile = File(p.join(dbDir, 'splitsmart_v3.db'));

    final now = DateTime.now();
    final name = 'splitsmart_backup_${now.year}_${now.month.toString().padLeft(2, "0")}_${now.day.toString().padLeft(2, "0")}.zip';
    final zipFile = File(p.join(docs.path, name));

    // Close DB connection to flush WAL and release locks before zipping
    await DatabaseService.instance.closeDatabase();

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);
    
    // Add DB
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
    
    // Add Receipts
    final receiptsDir = Directory(p.join(docs.path, 'receipts'));
    if (await receiptsDir.exists()) {
      encoder.addDirectory(receiptsDir, includeDirName: true);
    }
    
    encoder.close();

    // The database will be re-opened automatically on the next query
    // by DatabaseService.instance.get _database
    
    return zipFile;
  }

  static Future<void> shareBackup(File file, BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip')],
        subject: 'SplitSmart Backup',
        text: 'SplitSmart data + receipts backup.',
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
        subject: 'SplitSmart Error Logs',
        text: 'Attached are the crash logs for SplitSmart.',
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      ),
    );
  }

  static Future<BackupPreview?> previewFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
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

  static Future<bool> restoreFromFile(File zipFile, AppState state) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final docs = await getApplicationDocumentsDirectory();
      final dbDir = await getDatabasesPath();
      final targetDbFile = File(p.join(dbDir, 'splitsmart_v3.db'));

      // Close the active DB connection before overwriting the file
      await DatabaseService.instance.closeDatabase();
      
      for (final file in archive) {
        if (file.isFile) {
          if (file.name == 'splitsmart.db') {
            await targetDbFile.writeAsBytes(file.content as List<int>, flush: true);
          } else if (file.name == 'splitsmart.db-wal') {
            final targetWal = File(p.join(dbDir, 'splitsmart_v3.db-wal'));
            await targetWal.writeAsBytes(file.content as List<int>, flush: true);
          } else if (file.name == 'splitsmart.db-shm') {
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
      
      await state.reloadFromDatabase();
      return true;
    } catch (e) {
      debugPrint('[BackupService] restore error: $e');
      return false;
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
