import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:app_settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';

import '../providers/app_state.dart';
import '../services/backup_service.dart';
import '../utils/app_utils.dart';
import '../l10n/app_localizations.dart';
import '../services/export_service.dart';
import '../services/security_service.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';
import 'contact_us_screen.dart';
import 'import_csv_screen.dart';
import '../services/firestore_service.dart';

const Color _cGreen = Color(0xFF2DCE98);
const Color _cGreenL = Color(0xFFEAFAF4);
const Color _cRed = Color(0xFFF5365C);
const Color _cRedL = Color(0xFFFFF0F3);
const Color _cBlue = Color(0xFF5B8DEF);
const Color _cBlueL = Color(0xFFEFF6FF);
const Color _cPurple = Color(0xFF7C5CBF);
const Color _cPurpleL = Color(0xFFF3F0FF);
const Color _cOrange = Color(0xFFFF9F43);
const Color _cOrangeL = Color(0xFFFFF7ED);
const Color _cYellowL = Color(0xFFFFFBEB);
const Color _cGrey = Color(0xFF9CA3AF);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '1.0.0';
  bool _autoBackupEnabled = false;
  bool _loadingPrefs = true;
  bool _isWorking = false;
  bool _appLockEnabled = false;
  int _notifyBeforeDays = 1; // days before due date

  @override
  void initState() {
    super.initState();
    _loadAllPrefs();
  }

  Future<void> _loadAllPrefs() async {
    final autoE = await BackupService.isAutoBackupEnabled();
    final appLockE = await SecurityService.isAppLockEnabled();
    final prefs = await SharedPreferences.getInstance();
    final notifyDays = prefs.getInt('notify_before_days') ?? 1;

    if (!mounted) return;

    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {}

    setState(() {
      _autoBackupEnabled = autoE;
      _appLockEnabled = appLockE;
      _notifyBeforeDays = notifyDays;
      _loadingPrefs = false;
    });
  }

  void _snack(
    String msg, {
    Color? color,
    SnackBarAction? action,
    IconData? icon,
    Color? iconColor,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? _cGreen, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: TC.text(context),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color ?? TC.card(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: action,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _toggleAppLock(bool value) async {
    HapticFeedback.lightImpact();
    if (value) {
      final success = await SecurityService.authenticate();
      if (!success) return;
    }
    await SecurityService.setAppLockEnabled(value);
    if (value) AnalyticsService.logAppLockEnabled();
    setState(() {
      _appLockEnabled = value;
    });
  }

  Future<void> _toggleAuto(bool value) async {
    HapticFeedback.lightImpact();
    await BackupService.setAutoBackupEnabled(value);
    if (!mounted) return;
    setState(() => _autoBackupEnabled = value);
    _snack(
      value ? 'Auto-backup ON — runs every 7 days' : 'Auto-backup disabled',
      icon: value
          ? Icons.check_circle_rounded
          : Icons.notifications_off_rounded,
      iconColor: value ? _cGreen : _cRed,
    );
  }

  Future<void> _backupNow() async {
    if (_isWorking) return;
    HapticFeedback.lightImpact();
    setState(() => _isWorking = true);
    try {
      final file = await BackupService.createBackup();
      if (!mounted) return;
      _snack(
        'Backup saved successfully!',
        icon: Icons.check_circle_rounded,
        iconColor: _cGreen,
        action: SnackBarAction(
          label: 'Share',
          textColor: _cGreen,
          onPressed: () => BackupService.shareBackup(file, context),
        ),
      );
      AnalyticsService.logBackupCreated();
    } catch (e) {
      _snack('Backup failed: $e', icon: Icons.error_outline, iconColor: _cRed);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  /// Ask for a backup passphrase. Returns null if the user cancels.
  Future<String?> _askPassphrase({
    required String title,
    required String message,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TC.card(ctx),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: TC.text(ctx),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(fontSize: 13, color: TC.text2(ctx)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              style: TextStyle(color: TC.text(ctx)),
              decoration: InputDecoration(
                hintText: 'Passphrase (min 6 characters)',
                hintStyle: TextStyle(color: TC.text2(ctx), fontSize: 13),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: TC.text2(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text(
              'Continue',
              style: TextStyle(color: _cGreen, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return null;
    if (result.length < 6) {
      _snack('Passphrase must be at least 6 characters.',
          icon: Icons.error_outline, iconColor: _cRed);
      return null;
    }
    return result;
  }

  Future<void> _shareBackup() async {
    if (_isWorking) return;
    HapticFeedback.lightImpact();

    // Shared backups leave the device, so they are encrypted with a
    // passphrase (needed again to restore — including on a new phone).
    final passphrase = await _askPassphrase(
      title: 'Protect This Backup',
      message:
          'Choose a passphrase to encrypt the backup. You will need it to '
          'restore — there is no way to recover it if forgotten.',
    );
    if (passphrase == null || !mounted) return;

    setState(() => _isWorking = true);
    try {
      final file = await BackupService.createBackup(passphrase: passphrase);
      if (!mounted) return;
      await BackupService.shareBackup(file, context);
      AnalyticsService.logBackupShared();
    } catch (e) {
      _snack('Share failed: $e', icon: Icons.error_outline, iconColor: _cRed);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _restore() async {
    if (_isWorking) return;
    HapticFeedback.lightImpact();

    final file = await BackupService.pickBackupFile();
    if (file == null || !mounted) return;

    final preview = await BackupService.previewFile(file);
    if (!mounted) return;
    if (preview == null) {
      _snack('❌  Invalid or corrupted backup file.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TC.card(context),
        title: Text(
          'Restore Backup?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: TC.text(context),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Text('💾', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Database Size',
                      style: TextStyle(fontSize: 13, color: TC.text2(context)),
                    ),
                  ),
                  Text(
                    '${preview.dbSizeKb} KB',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: TC.text(context),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Text('📦', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total Files',
                      style: TextStyle(fontSize: 13, color: TC.text2(context)),
                    ),
                  ),
                  Text(
                    '${preview.fileCount}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: TC.text(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cRedDim(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cRed.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current data will be permanently replaced.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _cRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: TC.text2(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Restore',
              style: TextStyle(color: _cGreen, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isWorking = true);
    try {
      final appState = context.read<AppState>();
      var result = await BackupService.restoreFromFile(file, appState);

      // Passphrase-protected backup: prompt and retry once.
      if (result == RestoreResult.needsPassphrase && mounted) {
        setState(() => _isWorking = false);
        final passphrase = await _askPassphrase(
          title: 'Backup Is Protected',
          message: 'Enter the passphrase this backup was created with.',
        );
        if (passphrase == null || !mounted) return;
        setState(() => _isWorking = true);
        result = await BackupService.restoreFromFile(
          file,
          appState,
          passphrase: passphrase,
        );
      }

      if (!mounted) return;
      switch (result) {
        case RestoreResult.success:
          _snack(
            'Restore complete! All data recovered.',
            icon: Icons.check_circle_rounded,
          );
          AnalyticsService.logBackupRestored();
        case RestoreResult.wrongPassphrase:
          _snack(
            'Wrong passphrase for this backup.',
            icon: Icons.error_outline,
            iconColor: _cRed,
          );
        case RestoreResult.needsPassphrase:
          break; // user cancelled the prompt
        case RestoreResult.invalidFile:
          _snack(
            'Restore failed. File may be corrupted.',
            icon: Icons.error_outline,
            iconColor: _cRed,
          );
      }
    } catch (e) {
      _snack('Restore error: $e', icon: Icons.error_outline, iconColor: _cRed);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _showBackupBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            MediaQuery.viewInsetsOf(ctx).bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TC.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Backup & Restore',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: TC.text(context),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.save_outlined,
                  color: _cGreen,
                  size: 24,
                ),
                title: const Text(
                  'Backup Now',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Create a manual backup immediately.'),
                onTap: () {
                  Navigator.pop(context);
                  _backupNow();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.restore_outlined,
                  color: _cBlue,
                  size: 24,
                ),
                title: const Text(
                  'Restore Backup',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Restore your data from a backup file.'),
                onTap: () {
                  Navigator.pop(context);
                  _restore();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.share_outlined,
                  color: _cPurple,
                  size: 24,
                ),
                title: const Text(
                  'Share Backup',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Export and share a backup file.'),
                onTap: () {
                  Navigator.pop(context);
                  _shareBackup();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportToPdf() async {
    if (_isWorking) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    HapticFeedback.lightImpact();

    final appState = context.read<AppState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            MediaQuery.viewInsetsOf(ctx).bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TC.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Export PDF',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Text('🌍', style: TextStyle(fontSize: 24)),
                title: const Text(
                  'All App Data',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Export all combined groups, wallets, and transactions.',
                ),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  setState(() => _isWorking = true);
                  try {
                    await ExportService.exportAndSharePdf(appState, context);
                  } catch (e) {
                    _snack('❌  Export failed: $e');
                  } finally {
                    if (mounted) setState(() => _isWorking = false);
                  }
                },
              ),
              ListTile(
                leading: const Text('👥', style: TextStyle(fontSize: 24)),
                title: const Text(
                  'Specific Group',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Export only expenses and members of one group.',
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  _showGroupSelectionForPdf(appState);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupSelectionForPdf(AppState appState) {
    if (appState.groups.isEmpty) {
      _snack('No groups available to export.');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: TC.card(context),
          title: Text(
            'Select Group',
            style: TextStyle(
              color: TC.text(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: appState.groups.length,
              itemBuilder: (context, index) {
                final g = appState.groups[index];
                return ListTile(
                  leading: EmojiBox(emoji: g.emoji, size: 36),
                  title: Text(
                    g.name,
                    style: TextStyle(color: TC.text(context)),
                  ),
                  subtitle: Text(
                    g.isArchived ? 'Archived' : 'Active',
                    style: TextStyle(color: TC.text2(context), fontSize: 12),
                  ),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    setState(() => _isWorking = true);
                    try {
                      await ExportService.exportGroupPdf(g, appState, context);
                    } catch (e) {
                      _snack('❌  Export failed: $e');
                    } finally {
                      if (mounted) setState(() => _isWorking = false);
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareSupportLogs() async {
    HapticFeedback.lightImpact();
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = p.join(directory.path, 'app_errors.log');
      final file = File(path);

      if (!await file.exists() || (await file.length()) == 0) {
        _snack(
          'No error logs found — your app is running cleanly.',
          icon: Icons.check_circle_rounded,
        );
        return;
      }

      final logContent = await file.readAsString();
      final deviceInfo =
          '--- Support Info ---\n'
          'App Version: $_appVersion\n'
          'Date: ${DateTime.now()}\n'
          'Platform: Android\n'
          '--------------------\n\n';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        p.join(tempDir.path, 'SplitSmart_Support_Logs.txt'),
      );
      await tempFile.writeAsString(deviceInfo + logContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          subject: 'SplitSmart Support Logs v$_appVersion',
        ),
      );
      AnalyticsService.logSupportLogsShared();
    } catch (e) {
      _snack('Error sharing logs: $e');
    }
  }

  Future<void> _clearLogs() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TC.card(context),
        title: Text(
          'Clear Logs?',
          style: TextStyle(
            color: TC.text(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will permanently delete all error logs from this device.',
          style: TextStyle(color: TC.text2(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: TC.text2(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: _cRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final path = p.join(directory.path, 'app_errors.log');
        final file = File(path);
        if (await file.exists()) await file.delete();
        if (!mounted) return;
        _snack('Logs cleared successfully.', icon: Icons.check_circle_rounded);
      } catch (e) {
        if (!mounted) return;
        _snack(
          'Error clearing logs: $e',
          icon: Icons.error_outline,
          iconColor: _cRed,
        );
      }
    }
  }

  void _confirmReset(BuildContext context, AppState state, AppLocalizations l) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.card(context),
        title: Text(
          l.resetConfirm,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: TC.text(context),
          ),
        ),
        content: Text(l.resetBody, style: TextStyle(color: TC.text2(context))),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Text(l.cancel, style: TextStyle(color: TC.text2(context))),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              await state.resetAllData();
            },
            child: Text(l.reset, style: const TextStyle(color: _cRed)),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TC.card(context),
        title: Text(
          'Sign Out?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: TC.text(context),
          ),
        ),
        content: Text(
          'Your cloud data will remain safe. You can sign back in anytime.',
          style: TextStyle(color: TC.text2(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: TC.text2(context))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: _cRed, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: TC.border(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: TC.text(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last updated: May 2025',
                    style: TextStyle(fontSize: 12, color: TC.text3(context)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  _privacySection(
                    'Data Collection',
                    'SplitSmart collects only the information you provide directly, such as your name, profile picture, and financial transaction data you enter into the app.',
                  ),
                  _privacySection(
                    'Data Storage',
                    'Your data is stored locally in an encrypted database (SQLCipher, AES-256). The encryption key is created on your device and kept in your phone\'s secure hardware store — it never leaves your device. Optional cloud sync is powered by Firebase, which encrypts your data in transit and at rest on Google\'s servers.',
                  ),
                  _privacySection(
                    'Data Sharing',
                    'We do not sell, trade, or share your personal data with any third parties for marketing purposes. Data is only shared when you explicitly choose to export or share a backup.',
                  ),
                  _privacySection(
                    'Analytics',
                    'We use anonymous usage analytics to improve app performance and identify common issues. No personally identifiable information is included in analytics data.',
                  ),
                  _privacySection(
                    'Your Rights',
                    'You may delete all your data at any time using the "Reset All Data" option in Settings. For any privacy concerns or account deletion requests, contact us through the Contact Us screen or email usmanmighiana3898@gmail.com.',
                  ),
                  _privacySection(
                    'Security',
                    'Your database is encrypted at rest, and an optional biometric app lock protects access to the app. Backups you share are encrypted with a passphrase you choose — without it, the backup cannot be opened. Keep your passphrase safe: it cannot be recovered.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: TC.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: TC.text2(context),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ── Notify Before helpers ────────────────────────────────────────────────

  String _notifyBeforeLabel(int days) {
    if (days == 1) return '1 day before';
    if (days == 2) return '2 days before';
    if (days == 3) return '3 days before';
    if (days == 7) return '1 week before';
    if (days == 14) return '2 weeks before';
    if (days == 30) return '1 month before';
    return '$days days before';
  }

  void _showNotifyBeforePicker() {
    HapticFeedback.lightImpact();
    final options = [
      {'days': 1, 'label': '1 Day', 'sub': 'Notified the day before due'},
      {'days': 2, 'label': '2 Days', 'sub': 'Two days advance warning'},
      {'days': 3, 'label': '3 Days', 'sub': 'Three days advance warning'},
      {'days': 7, 'label': '1 Week', 'sub': 'A week before the due date'},
      {'days': 14, 'label': '2 Weeks', 'sub': 'Two weeks before the due date'},
      {'days': 30, 'label': '1 Month', 'sub': 'A full month in advance'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: TC.border(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Notify Before',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: TC.text(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How far in advance to send payment reminders',
                      style: TextStyle(fontSize: 12, color: TC.text3(context)),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              ...options.map((opt) {
                final days = opt['days'] as int;
                final isSelected = _notifyBeforeDays == days;
                return InkWell(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('notify_before_days', days);
                    if (!mounted) return;
                    setState(() => _notifyBeforeDays = days);
                    Navigator.pop(context);
                    _snack(
                      'Reminders set to ${_notifyBeforeLabel(days)}',
                      icon: Icons.check_circle_rounded,
                      iconColor: _cGreen,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? _cGreen : _cRedL,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? _cGreen
                                  : _cRed.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.alarm_rounded,
                            color: isSelected ? Colors.white : _cRed,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt['label'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? _cGreen
                                      : TC.text(context),
                                ),
                              ),
                              Text(
                                opt['sub'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: TC.text3(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: _cGreen,
                            size: 22,
                          )
                        else
                          Icon(
                            Icons.radio_button_unchecked_rounded,
                            color: TC.text3(context),
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  static const _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸', 'native': 'English'},
    {'code': 'ur', 'name': 'Urdu', 'flag': '🇵🇰', 'native': 'اردو'},
    {'code': 'ar', 'name': 'Arabic', 'flag': '🇸🇦', 'native': 'العربية'},
    {'code': 'fr', 'name': 'French', 'flag': '🇫🇷', 'native': 'Français'},
    {'code': 'es', 'name': 'Spanish', 'flag': '🇪🇸', 'native': 'Español'},
    {'code': 'de', 'name': 'German', 'flag': '🇩🇪', 'native': 'Deutsch'},
    {'code': 'tr', 'name': 'Turkish', 'flag': '🇹🇷', 'native': 'Türkçe'},
    {'code': 'hi', 'name': 'Hindi', 'flag': '🇮🇳', 'native': 'हिन्दी'},
  ];

  String _languageName(String code) {
    final l = _languages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => _languages.first,
    );
    return '${l['name']} (${l['native']})';
  }

  void _showLanguagePicker(BuildContext context, AppState state) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: TC.border(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Language',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: TC.text(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose your preferred language',
                    style: TextStyle(fontSize: 13, color: TC.text2(context)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                itemCount: _languages.length,
                itemBuilder: (_, i) {
                  final lang = _languages[i];
                  final isSelected = state.locale.languageCode == lang['code'];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      state.setLocale(Locale(lang['code']!));
                      AnalyticsService.logLanguageChanged(lang['code']!);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _cGreenDim(context)
                            : TC.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? _cGreen : TC.border(context),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            lang['flag']!,
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang['name']!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isSelected
                                        ? _cGreen
                                        : TC.text(context),
                                  ),
                                ),
                                Text(
                                  lang['native']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: TC.text2(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: _cGreen,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _cGreenDim(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF143026)
      : const Color(0xFFEAFAF4);
  Color _cRedDim(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF33171D)
      : const Color(0xFFFFF0F3);

  Future<void> _seedDemoData(AppState state) async {
    HapticFeedback.lightImpact();
    setState(() => _isWorking = true);

    // Show "Seeding..." snack
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 16),
            Text('Seeding demo data...'),
          ],
        ),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // 1. Create some wallets
      await state.createWallet('USD', 5000.0);
      await state.createWallet('EUR', 200.0);
      await state.createWallet('PKR', 15000.0);

      // 2. Create dummy transactions
      final now = DateTime.now();
      await state.addTransaction(
        TransactionData(
          id: now.microsecondsSinceEpoch,
          type: 'expense',
          desc: 'Morning Coffee',
          amount: 5.50,
          cat: '☕',
          currency: 'USD',
          sym: '\$',
          date: now.toIso8601String(),
        ),
      );

      await state.addTransaction(
        TransactionData(
          id: now.microsecondsSinceEpoch + 1,
          type: 'income',
          desc: 'Freelance Payment',
          amount: 850.0,
          cat: '💻',
          currency: 'USD',
          sym: '\$',
          date: now.subtract(const Duration(days: 1)).toIso8601String(),
        ),
      );

      await state.addTransaction(
        TransactionData(
          id: now.microsecondsSinceEpoch + 2,
          type: 'expense',
          desc: 'Grocery Store',
          amount: 42.75,
          cat: '🛒',
          currency: 'USD',
          sym: '\$',
          date: now.subtract(const Duration(days: 2)).toIso8601String(),
        ),
      );

      // 3. Create a dummy group
      final groupId = now.microsecondsSinceEpoch + 3;
      final g = GroupData(
        id: groupId,
        name: 'Weekend Roadtrip',
        emoji: '🚗',
        currency: 'USD',
        sym: '\$',
        members: ['You', 'Alice', 'Bob', 'Charlie'],
        expenses: [],
        settlements: [],
      );

      await state.addGroup(g);

      // Wait a bit for the state to settle if needed, or find the group from local list
      // actually state.addGroup usually adds to the local list immediately.
      final addedGroup = state.groups.firstWhere(
        (grp) => grp.id == groupId,
        orElse: () => g,
      );

      // 4. Add some group expenses
      final e1 = ExpenseData(
        id: now.microsecondsSinceEpoch + 4,
        desc: 'Fuel & Gas',
        amount: 60.0,
        cat: '🚗',
        paidBy: 'You',
        date: now.toIso8601String(),
        splits: {'You': 15.0, 'Alice': 15.0, 'Bob': 15.0, 'Charlie': 15.0},
        createdBy: AuthService.instance.uid,
        updatedBy: AuthService.instance.uid,
      );
      await state.addExpenseToGroup(addedGroup, e1);

      final e2 = ExpenseData(
        id: now.microsecondsSinceEpoch + 5,
        desc: 'Cabin Rental',
        amount: 200.0,
        cat: '🏠',
        paidBy: 'Alice',
        date: now.subtract(const Duration(days: 1)).toIso8601String(),
        splits: {'You': 50.0, 'Alice': 50.0, 'Bob': 50.0, 'Charlie': 50.0},
        createdBy: AuthService.instance.uid,
        updatedBy: AuthService.instance.uid,
      );
      await state.addExpenseToGroup(addedGroup, e2);

      _snack(
        'Demo data seeded successfully!',
        icon: Icons.check_circle_rounded,
        iconColor: _cGreen,
      );
    } catch (e) {
      debugPrint('[Settings] Seed error: $e');
      _snack(
        'Error seeding demo data: $e',
        icon: Icons.error_outline,
        iconColor: _cRed,
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Widget _buildTestRow({
    required IconData icon,
    required String title,
    required String status,
    required Color color,
    String? detail,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: TC.text(context),
                ),
              ),
              if (detail != null)
                Text(
                  detail,
                  style: TextStyle(fontSize: 12, color: TC.text3(context)),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  void _showFirebaseTestPanel() {
    HapticFeedback.lightImpact();
    bool isPinging = false;
    bool? pingResult;

    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final uid = AuthService.instance.uid;
            final isSignedIn = AuthService.instance.isSignedIn;
            final useCloud = ctx.read<AppState>().useCloud;
            final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;

            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: TC.border(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Firebase Test Tools',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: TC.text(context),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTestRow(
                      icon: Icons.person_rounded,
                      title: 'Auth Status',
                      status: isSignedIn ? 'Signed In' : 'Logged Out',
                      color: isSignedIn ? _cGreen : _cRed,
                      detail: uid ?? 'No UID',
                    ),
                    const SizedBox(height: 16),
                    _buildTestRow(
                      icon: Icons.cloud_done_rounded,
                      title: 'Firestore Sync',
                      status: useCloud ? 'Enabled' : 'Disabled',
                      color: useCloud ? _cGreen : _cOrange,
                    ),
                    const SizedBox(height: 16),
                    _buildTestRow(
                      icon: Icons.network_check_rounded,
                      title: 'Connectivity',
                      status: isPinging
                          ? 'Testing...'
                          : (pingResult == null
                                ? 'Not Tested'
                                : (pingResult! ? 'Success' : 'Failed')),
                      color: isPinging
                          ? _cBlue
                          : (pingResult == null
                                ? _cGrey
                                : (pingResult! ? _cGreen : _cRed)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isPinging
                            ? null
                            : () async {
                                setSheetState(() => isPinging = true);
                                final result = await FirestoreService.instance
                                    .ping();
                                if (ctx.mounted) {
                                  setSheetState(() {
                                    isPinging = false;
                                    pingResult = result;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cBlueL,
                          foregroundColor: _cBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isPinging
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _cBlue,
                                ),
                              )
                            : const Text(
                                'Run Ping Test',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 52, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TC.border(context), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                '←',
                style: TextStyle(
                  color: _cGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREFERENCES',
                  style: TC.geist(context,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: TC.primaryMd(context),
                      letterSpacing: 1.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'Settings',
                  style: TC.gloock(context,
                      fontSize: 28, letterSpacing: -0.8, height: 1),
                ),
                const SizedBox(height: 3),
                Text(
                  'Manage your app preferences',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TC.text3(context),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _snack('Search coming soon');
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TC.border(context), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.search, size: 18, color: TC.text2(context)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs) {
      return Scaffold(
        backgroundColor: TC.bg(context),
        body: const Center(
          child: CircularProgressIndicator(color: _cGreen, strokeWidth: 2),
        ),
      );
    }

    final state = context.read<AppState>();
    final isDark = context.select<AppState, bool>((s) => s.isDark);
    final locale = context.select<AppState, Locale>((s) => s.locale);

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            _buildHeader(context)
                .animate()
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // ACCOUNT CARD
            _AccountCard(onSignOut: () => _confirmSignOut(context))
                .animate(delay: 50.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // GENERAL
            const _SecTitle('General')
                .animate(delay: 80.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),
            _CardBox(
                  children: [
                    _Tile(
                      icon: const Text('☀️', style: TextStyle(fontSize: 18)),
                      iconBg: _cYellowL,
                      title: 'Appearance',
                      subtitle: isDark ? 'Dark mode' : 'Light mode',
                      trailing: _CustomToggle(
                        value: isDark,
                        onChanged: (v) {
                          state.toggleTheme();
                          AnalyticsService.logThemeToggled(v);
                        },
                      ),
                    ),
                    _Tile(
                      icon: const Text('🌐', style: TextStyle(fontSize: 18)),
                      iconBg: _cBlueL,
                      title: 'Language',
                      subtitle: _languageName(locale.languageCode),
                      onTap: () => _showLanguagePicker(context, state),
                      showDivider: false,
                    ),
                  ],
                )
                .animate(delay: 80.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // DATA & BACKUP
            const _SecTitle('Data & Backup')
                .animate(delay: 110.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),
            _CardBox(
                  children: [
                    _Tile(
                      icon: const Icon(
                        Icons.cloud_upload_outlined,
                        color: _cGreen,
                        size: 20,
                      ),
                      iconBg: _cGreenL,
                      title: 'Backup & Restore',
                      subtitle: 'Backup, restore and share your data',
                      onTap: _showBackupBottomSheet,
                    ),
                    _Tile(
                      icon: const Icon(
                        Icons.upload_file_outlined,
                        color: _cBlue,
                        size: 20,
                      ),
                      iconBg: _cBlueL,
                      title: 'Export Data',
                      subtitle: 'Export your data as PDF or CSV',
                      onTap: _exportToPdf,
                    ),
                    _Tile(
                      icon: const Icon(
                        Icons.download_rounded,
                        color: _cGreen,
                        size: 20,
                      ),
                      iconBg: _cGreenL,
                      title: 'Import from CSV',
                      subtitle: 'Bring in transactions from a bank/app export',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ImportCsvScreen()));
                      },
                    ),
                    _Tile(
                      icon: const Icon(
                        Icons.autorenew_rounded,
                        color: _cOrange,
                        size: 20,
                      ),
                      iconBg: _cOrangeL,
                      title: 'Auto Backup',
                      subtitle: 'Every 7 days · Keeps last 3 backups',
                      trailing: _CustomToggle(
                        value: _autoBackupEnabled,
                        onChanged: _toggleAuto,
                      ),
                      showDivider: false,
                    ),
                  ],
                )
                .animate(delay: 110.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // SECURITY
            const _SecTitle('Security')
                .animate(delay: 140.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),
            _CardBox(
                  children: [
                    _Tile(
                      icon: const Icon(
                        Icons.fingerprint_rounded,
                        color: _cPurple,
                        size: 20,
                      ),
                      iconBg: _cPurpleL,
                      title: 'Biometric Lock',
                      subtitle: 'Use fingerprint to unlock the app',
                      trailing: _CustomToggle(
                        value: _appLockEnabled,
                        onChanged: (v) => _toggleAppLock(v),
                      ),
                      showDivider: false,
                    ),
                  ],
                )
                .animate(delay: 140.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // REMINDERS
            const _SecTitle('Reminders')
                .animate(delay: 170.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),
            _CardBox(
                  children: [
                    _Tile(
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        color: _cRed,
                        size: 20,
                      ),
                      iconBg: _cRedL,
                      title: 'Reminder Alerts',
                      subtitle: 'Get notified for upcoming payments',
                      trailing: _CustomToggle(
                        value: true,
                        onChanged: (v) {
                          AppSettings.openAppSettings(
                            type: AppSettingsType.notification,
                          );
                        },
                      ),
                    ),
                    _Tile(
                      icon: const Icon(
                        Icons.timer_outlined,
                        color: _cRed,
                        size: 20,
                      ),
                      iconBg: _cRedL,
                      title: 'Notify Before',
                      subtitle: _notifyBeforeLabel(_notifyBeforeDays),
                      onTap: _showNotifyBeforePicker,
                      showDivider: false,
                    ),
                  ],
                )
                .animate(delay: 170.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // SUPPORT
            const _SecTitle('Support')
                .animate(delay: 200.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),
            _CardBox(
                  children: [
                    _Tile(
                      icon: const Icon(
                        Icons.support_agent_rounded,
                        color: _cGreen,
                        size: 20,
                      ),
                      iconBg: _cGreenL,
                      title: 'Contact Us',
                      subtitle: 'Questions, issues, or feature ideas',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContactUsScreen(),
                          ),
                        );
                      },
                    ),
                    _Tile(
                      icon: const Icon(Icons.star_rounded, size: 18),
                      iconBg: _cYellowL,
                      title: 'Rate App',
                      subtitle: 'Leave a review on the Play Store',
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final inAppReview = InAppReview.instance;
                        if (await inAppReview.isAvailable()) {
                          await inAppReview.requestReview();
                        } else {
                          // Fallback: open Play Store listing directly
                          await inAppReview.openStoreListing(
                            appStoreId:
                                '6744811929', // iOS App Store ID (update if needed)
                          );
                        }
                      },
                      showDivider: false,
                    ),
                  ],
                )
                .animate(delay: 200.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // DEVELOPER SECTION
            const _SecTitle('Developer', color: _cRed)
                .animate(delay: 230.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),
            _CardBox(
                  children: [
                    _Tile(
                      icon: const Text('🗑️', style: TextStyle(fontSize: 18)),
                      iconBg: _cRedL,
                      title: 'Reset All Data',
                      subtitle:
                          'Wipe all groups, wallets, reminders, and transactions',
                      titleColor: _cRed,
                      onTap: () => _confirmReset(
                        context,
                        state,
                        AppLocalizations.of(context),
                      ),
                    ),
                    _Tile(
                      icon: const Text('🧹', style: TextStyle(fontSize: 18)),
                      iconBg: _cOrangeL,
                      title: 'Clear Local Cache',
                      subtitle: 'Remove temporary app data',
                      onTap: _clearLogs,
                    ),
                    _Tile(
                      icon: const Text('📋', style: TextStyle(fontSize: 18)),
                      iconBg: _cBlueL,
                      title: 'Export Debug Logs',
                      subtitle: 'Share logs for troubleshooting',
                      onTap: _shareSupportLogs,
                    ),
                    _Tile(
                      icon: const Icon(Icons.local_fire_department_rounded, size: 18),
                      iconBg: _cYellowL,
                      title: 'Firebase Test Tools',
                      subtitle: 'Check sync, auth, and Firestore status',
                      onTap: _showFirebaseTestPanel,
                    ),
                    _Tile(
                      icon: const Text('🌱', style: TextStyle(fontSize: 18)),
                      iconBg: _cGreenL,
                      title: 'Seed Demo Data',
                      subtitle:
                          'Create sample groups, expenses, reminders, and wallets',
                      onTap: () => _seedDemoData(state),
                    ),
                    _Tile(
                      icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                      iconBg: _cBlueL,
                      title: 'Reset Onboarding',
                      subtitle: 'Show onboarding screens on next app launch',
                      showDivider: false,
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('onboarding_done');
                        await prefs.remove('onboarding_seen');
                        if (context.mounted) {
                          _snack(
                            'Onboarding reset — restart the app to see it',
                          );
                        }
                      },
                    ),
                  ],
                )
                .animate(delay: 230.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // ABOUT
            const _SecTitle('About')
                .animate(delay: 260.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),
            _CardBox(
                  children: [
                    _Tile(
                      icon: const Icon(
                        Icons.privacy_tip_outlined,
                        color: _cGreen,
                        size: 20,
                      ),
                      iconBg: _cGreenL,
                      title: 'Privacy Policy',
                      subtitle: 'How we handle your data',
                      onTap: () => _showPrivacyPolicy(context),
                    ),
                    _Tile(
                      icon: Icon(
                        Icons.info_outline_rounded,
                        color: TC.text3(context),
                        size: 20,
                      ),
                      iconBg: TC.bg(context),
                      title: 'App Version',
                      subtitle: 'SplitSmart v$_appVersion',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _cGreenL,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Up to date',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _cGreen,
                          ),
                        ),
                      ),
                      showDivider: false,
                    ),
                  ],
                )
                .animate(delay: 260.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // FOOTER
            Padding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
                  child: Center(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: TC.text3(context),
                          fontFamily: 'Nunito',
                        ),
                        children: const [
                          TextSpan(
                            text: '♥ ',
                            style: TextStyle(color: _cRed),
                          ),
                          TextSpan(text: 'Made with love by SplitSmart'),
                        ],
                      ),
                    ),
                  ),
                )
                .animate(delay: 290.ms)
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final VoidCallback onSignOut;
  const _AccountCard({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final isSignedIn = auth.isSignedIn;
    final name = auth.currentUser?.displayName ?? 'Guest User';
    final email = auth.email ?? 'Not signed in';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: TC.border(context)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {},
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSignedIn
                          ? const LinearGradient(
                              colors: [_cGreen, Color(0xFF1AAB7A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: !isSignedIn ? TC.card2(context) : null,
                      border: Border.all(color: _cGreenL, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: auth.photoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              auth.photoUrl!,
                              fit: BoxFit.cover,
                              width: 58,
                              height: 58,
                            ),
                          )
                        : Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: TC.text(context),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: TC.text2(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isSignedIn)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _cGreenL,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: _cGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Synced',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _cGreen,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: TC.card2(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: TC.text3(context),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Local Only',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: TC.text3(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: TC.text3(context), size: 18),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: TC.border(context),
            indent: 16,
            endIndent: 16,
          ),
          if (isSignedIn)
            InkWell(
              onTap: onSignOut,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _cRedL,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🚪', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _cRed,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: TC.text3(context),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardBox extends StatelessWidget {
  final List<Widget> children;
  const _CardBox({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: TC.border(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

class _SecTitle extends StatelessWidget {
  final String text;
  final Color? color;
  const _SecTitle(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 18, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color ?? TC.text3(context),
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Widget icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final Color? titleColor;

  const _Tile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: icon,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: titleColor ?? TC.text(context),
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: TC.text3(context),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ] else ...[
                    Icon(
                      Icons.chevron_right,
                      color: TC.text3(context),
                      size: 18,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (showDivider)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: TC.border(context),
                  indent: 51,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 46,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value ? _cGreen : const Color(0xFFD1D5DB),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              top: 3,
              left: value ? 23 : 3,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
