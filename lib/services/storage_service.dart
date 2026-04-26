import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // SEC-H5: Allowed receipt extensions and max file size (10 MB)
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'};
  static const _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  /// Uploads a local receipt image to Firebase Storage and returns the public download URL.
  Future<String?> uploadReceipt(int groupId, int expenseId, String localPath) async {
    final uid = AuthService.instance.uid;
    if (uid == null) return null;

    final file = File(localPath);
    if (!await file.exists()) return null;

    try {
      final ext = localPath.split('.').last.toLowerCase();

      // SEC-H5: Validate extension whitelist
      if (!_allowedExtensions.contains(ext)) {
        debugPrint('[StorageService] Rejected upload: unsupported extension .$ext');
        return null;
      }

      // SEC-H5: Validate file size
      final fileSize = await file.length();
      if (fileSize > _maxFileSizeBytes) {
        debugPrint('[StorageService] Rejected upload: file too large (${fileSize ~/ 1024}KB > ${_maxFileSizeBytes ~/ 1024}KB)');
        return null;
      }

      final ref = _storage.ref().child('groups/$groupId/receipts/exp_$expenseId.$ext');

      // BUG-12 fix: detect MIME type from extension instead of hardcoding jpeg
      final mimeTypes = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
        'gif': 'image/gif',
        'heic': 'image/heic',
      };
      final contentType = mimeTypes[ext] ?? 'image/jpeg';

      final task = await ref.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );

      final url = await task.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('[StorageService] Error uploading receipt: $e');
      return null;
    }
  }

  /// Deletes a receipt image from Firebase Storage.
  Future<void> deleteReceipt(int groupId, int expenseId, String remoteUrl) async {
    try {
      // Create a reference from the HTTPS URL
      final ref = _storage.refFromURL(remoteUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('[StorageService] Error deleting receipt: $e');
    }
  }
}
