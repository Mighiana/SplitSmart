import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';


import '../main.dart';
import '../providers/app_state.dart';
import '../services/backup_service.dart';
import '../utils/app_utils.dart';
import '../l10n/app_localizations.dart';
import 'package:app_settings/app_settings.dart';
import 'archived_groups_screen.dart';
import '../services/export_service.dart';
import '../services/security_service.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';
// ─── Settings Screen ──────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (_) {
      // Keep fallback version if package info is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<AppState, bool>((s) => s.isDark);
    final locale = context.select<AppState, Locale>((s) => s.locale);
    final state = context.read<AppState>();
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TC.card(context),
              shape: BoxShape.circle,
              border: Border.all(color: TC.border(context)),
            ),
            alignment: Alignment.center,
            child: Text(
              '←',
              style: TextStyle(fontSize: 16, color: TC.text(context)),
            ),
          ),
        ),
        title: Text(
          l.settings,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: TC.text(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.settingsHeader,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.green,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.preferences,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: TC.text(context),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.customizeWorkspace,
              style: TextStyle(fontSize: 13, color: TC.text2(context), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 28),

            // ── Account ───────────────────────────────────────────────────
            _SectionTitle(l.account),
            _AccountCard(),

            // ── Appearance ─────────────────────────────────────────────────
            _SectionTitle(l.appearance),
            _SettingCard(
              icon: isDark ? '🌙' : '☀️',
              title: isDark ? l.darkMode : l.lightMode,
              subtitle: l.switchTheme,
              trailing: Switch(
                value: isDark,
                activeThumbColor: AppColors.green,
                activeTrackColor: AppColors.greenDim,
                onChanged: (_) {
                  HapticFeedback.lightImpact();
                  state.toggleTheme();
                  AnalyticsService.logThemeToggled(!isDark);
                },
              ),
            ),

            // ── Language ───────────────────────────────────────────────────
            _SectionTitle(l.language),
            _TappableSettingCard(
              icon: _languageFlag(locale.languageCode),
              title: _languageName(locale.languageCode),
              subtitle: l.chooseLanguage,
              onTap: () => _showLanguagePicker(context, state),
            ),

            // ── Data Backup ────────────────────────────────────────────────
            _SectionTitle(l.dataBackup),
            const _BackupSection(),

            // ── Notifications ──────────────────────────────────────────────
            _SectionTitle(l.notifications),
            _TappableSettingCard(
              icon: '🔔',
              title: l.notificationSettings,
              subtitle: l.manageReminders,
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                HapticFeedback.lightImpact();
                AppSettings.openAppSettings(type: AppSettingsType.notification);
              },
            ),

            // ── Storage ────────────────────────────────────────────────────
            _SectionTitle(l.storage),
            _SettingCard(
              icon: AuthService.instance.isSignedIn ? '☁️' : '💿',
              title: AuthService.instance.isSignedIn ? l.cloudSync : l.database,
              subtitle: AuthService.instance.isSignedIn
                  ? l.cloudSyncSub
                  : l.databaseSub,
            ),

            // ── About ──────────────────────────────────────────────────────
            _SectionTitle(l.about),
            _SettingCard(
              icon: '💚',
              title: l.appName,
              subtitle: l.version,
            ),
            _SettingCard(
              icon: '📵',
              title: l.offline,
              subtitle: l.offlineSub,
            ),
            const _PrivacyLockCard(),

            // ── Features ───────────────────────────────────────────────────
            _SectionTitle(l.features),
            _SettingCard(
              icon: '👥',
              title: l.groupSplitting,
              subtitle: l.groupSplittingSub,
            ),
            _SettingCard(
              icon: '💰',
              title: l.moneyManager,
              subtitle: l.moneyManagerSub,
            ),
            _SettingCard(
              icon: '🌍',
              title: l.currencies,
              subtitle: l.currenciesSub,
            ),
            _SettingCard(
              icon: '📤',
              title: l.exportShare,
              subtitle: l.exportShareSub,
            ),
            _TappableSettingCard(
              icon: '📦',
              title: l.archiveGroups,
              subtitle: l.archiveGroupsSub,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivedGroupsScreen()));
              },
            ),
            _SettingCard(
              icon: '✏️',
              title: l.editExpenses,
              subtitle: l.editExpensesSub,
            ),

            // ── Support ───────────────────────────────────────────────────
            _SectionTitle(l.support),
            _TappableSettingCard(
              icon: '🐞',
              title: l.reportIssue,
              subtitle: l.reportIssueSub,
              onTap: _shareSupportLogs,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 20),
                    onPressed: _clearLogs,
                    tooltip: 'Clear Logs',
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.text3, size: 18),
                ],
              ),
            ),

            // ── Developer ──────────────────────────────────────────────────
            _SectionTitle(l.developer),
            _TappableSettingCard(
              icon: '🗑',
              title: l.resetData,
              subtitle: l.resetDataSub,
              danger: true,
              onTap: () => _confirmReset(context, state, l),
            ),

            // ── Legal ──────────────────────────────────────────────────
            _SectionTitle(l.legal),
            _TappableSettingCard(
              icon: '🔒',
              title: l.privacyPolicy,
              subtitle: l.privacyPolicySub,
              onTap: () async {
                HapticFeedback.lightImpact();
                // BLOCK-2 FIX: Open local dialog instead of 404 URL until a real policy is hosted.
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: TC.bg(context),
                    title: Text(l.privacyPolicy, style: TextStyle(color: TC.text(context), fontWeight: FontWeight.bold)),
                    content: Text('Your data is securely stored locally on your device and synced via Firebase. We do not sell or share your personal data with third parties.', style: TextStyle(color: TC.text2(context))),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                );
              },
            ),
            _TappableSettingCard(
              icon: 'ℹ️',
              title: l.appVersion,
              subtitle: 'SplitSmart v$_appVersion',
              onTap: () {
                HapticFeedback.lightImpact();
              },
            ),

            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const Text('💚', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(
                    l.madeWithLove,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.text2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SplitSmart v$_appVersion',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 600.ms).scale(begin: const Offset(0.8, 0.8)),
          ].animate(interval: 50.ms).fade(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
        ),
      ),
    );
  }

  Future<void> _shareSupportLogs() async {
    HapticFeedback.lightImpact();
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = p.join(directory.path, 'app_errors.log');
      final file = File(path);

      if (!await file.exists() || (await file.length()) == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('No error logs found — your app is running cleanly.')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final logContent = await file.readAsString();
      final deviceInfo = '--- Support Info ---\n'
          'App Version: $_appVersion\n'
          'Date: ${DateTime.now()}\n'
          'Platform: Android\n'
          '--------------------\n\n';
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'SplitSmart_Support_Logs.txt'));
      await tempFile.writeAsString(deviceInfo + logContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          subject: 'SplitSmart Support Logs v$_appVersion',
        ),
      );
      AnalyticsService.logSupportLogsShared();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing logs: $e')),
      );
    }
  }

  Future<void> _clearLogs() async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TC.card(context),
        title: Text('Clear Logs?', style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w700)),
        content: Text('This will permanently delete all error logs from this device.', style: TextStyle(color: TC.text2(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: TC.text2(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Logs cleared successfully.')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing logs: $e'), behavior: SnackBarBehavior.floating),
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
        content: Text(
          l.resetBody,
          style: TextStyle(color: TC.text2(context)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Text(
              l.cancel,
              style: TextStyle(color: TC.text2(context)),
            ),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              await state.resetAllData();
            },
            child: Text(
              l.reset,
              style: const TextStyle(color: AppColors.red),
            ),
          ),
        ],
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

  String _languageFlag(String code) => _languages.firstWhere(
        (l) => l['code'] == code,
        orElse: () => _languages.first,
      )['flag']!;

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
                            ? AppColors.greenDim
                            : TC.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.green
                              : TC.border(context),
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
                                        ? AppColors.green
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
                              color: AppColors.green,
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
}

// ─── Data Backup Section ──────────────────────────────────────────────────────

class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  bool _autoEnabled = false;
  bool _loadingPrefs = true;
  bool _isWorking = false;
  DateTime? _lastBackup;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final enabled = await BackupService.isAutoBackupEnabled();
    final last = await BackupService.lastAutoBackupDate();
    if (!mounted) return;
    setState(() {
      _autoEnabled = enabled;
      _lastBackup = last;
      _loadingPrefs = false;
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _snack(String msg, {Color? color, SnackBarAction? action, IconData? icon, Color? iconColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? AppColors.green, size: 20),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: action,
        duration: const Duration(seconds: 4),
      ),
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
        'Backup saved!\n${file.path}',
        icon: Icons.check_circle_rounded,
        action: SnackBarAction(
          label: 'Share',
          textColor: AppColors.green,
          onPressed: () => BackupService.shareBackup(file, context),
        ),
      );
      AnalyticsService.logBackupCreated();
    } catch (e) {
      _snack('Backup failed: $e', icon: Icons.error_outline, iconColor: AppColors.red);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _shareBackup() async {
    if (_isWorking) return;
    HapticFeedback.lightImpact();
    setState(() => _isWorking = true);
    try {
      final file = await BackupService.createBackup();
      if (!mounted) return;
      await BackupService.shareBackup(file, context);
      AnalyticsService.logBackupShared();
    } catch (e) {
      _snack('Share failed: $e', icon: Icons.error_outline, iconColor: AppColors.red);
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
            _PreviewRow('💾', 'Database Size', '${preview.dbSizeKb} KB'),
            _PreviewRow('📦', 'Total Files', '${preview.fileCount} (including receipts)'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.redDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current data will be permanently replaced.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.red,
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
            child: Text(
              'Cancel',
              style: TextStyle(color: TC.text2(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Restore',
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isWorking = true);
    try {
      final appState = context.read<AppState>();
      final ok = await BackupService.restoreFromFile(file, appState);
      if (!mounted) return;
      if (ok) {
        _snack('Restore complete! All data recovered.', icon: Icons.check_circle_rounded);
        AnalyticsService.logBackupRestored();
      } else {
        _snack('Restore failed. File may be corrupted.', icon: Icons.error_outline, iconColor: AppColors.red);
      }
    } catch (e) {
      _snack('Restore error: $e', icon: Icons.error_outline, iconColor: AppColors.red);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _exportToPdf() async {
    if (_isWorking) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    HapticFeedback.lightImpact();

    final appState = context.read<AppState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
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
              title: const Text('All App Data', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Export all combined groups, wallets, and transactions.'),
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
              title: const Text('Specific Group', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Export only expenses and members of one group.'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                _showGroupSelectionForPdf(appState);
              },
            ),
            const SizedBox(height: 12),
          ],
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
          title: Text('Select Group', style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: appState.groups.length,
              itemBuilder: (context, index) {
                final g = appState.groups[index];
                return ListTile(
                  leading: EmojiBox(emoji: g.emoji, size: 36),
                  title: Text(g.name, style: TextStyle(color: TC.text(context))),
                  subtitle: Text(g.isArchived ? 'Archived' : 'Active', style: TextStyle(color: TC.text2(context), fontSize: 12)),
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

  Future<void> _toggleAuto(bool value) async {
    HapticFeedback.lightImpact();
    await BackupService.setAutoBackupEnabled(value);
    if (!mounted) return;
    setState(() => _autoEnabled = value);
    _snack(
      value
          ? 'Auto-backup ON — runs every 7 days'
          : 'Auto-backup disabled',
      icon: value ? Icons.check_circle_rounded : Icons.notifications_off_rounded,
      iconColor: value ? AppColors.green : AppColors.red,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.green,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final l = AppLocalizations.of(context);
    return Column(
      children: [
        _BackupActionCard(
          icon: '💾',
          title: l.backupNow,
          subtitle: l.backupNowSub,
          color: AppColors.green,
          isWorking: _isWorking,
          onTap: _backupNow,
        ),
        const SizedBox(height: 8),
        _BackupActionCard(
          icon: '♻️',
          title: l.restoreBackup,
          subtitle: l.restoreBackupSub,
          color: AppColors.blue,
          isWorking: _isWorking,
          onTap: _restore,
        ),
        const SizedBox(height: 8),
        _BackupActionCard(
          icon: '📤',
          title: l.shareBackup,
          subtitle: l.shareBackupSub,
          color: AppColors.purple,
          isWorking: _isWorking,
          onTap: _shareBackup,
        ),
        const SizedBox(height: 8),
        _BackupActionCard(
          icon: '📄',
          title: l.exportPdf,
          subtitle: l.exportPdfSub,
          color: AppColors.blue,
          isWorking: _isWorking,
          onTap: _exportToPdf,
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: TC.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TC.border(context)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('🔁', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.autoBackup,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: TC.text(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.autoBackupSub,
                          style: TextStyle(
                            fontSize: 12,
                            color: TC.text2(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoEnabled,
                    activeThumbColor: AppColors.green,
                    activeTrackColor: AppColors.greenDim,
                    onChanged: _toggleAuto,
                  ),
                ],
              ),
              if (_lastBackup != null || _autoEnabled) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const SizedBox(width: 36),
                    const SizedBox(width: 14),
                    Text(
                      _lastBackup != null
                          ? 'Last backup: ${_fmtDate(_lastBackup!)}'
                          : 'No auto-backup yet',
                      style: TextStyle(
                        fontSize: 11,
                        color: _lastBackup != null
                            ? AppColors.green
                            : TC.text3(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─── Backup Action Card ───────────────────────────────────────────────────────

class _BackupActionCard extends StatefulWidget {
  final String icon, title, subtitle;
  final Color color;
  final bool isWorking;
  final VoidCallback onTap;

  const _BackupActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isWorking,
    required this.onTap,
  });

  @override
  State<_BackupActionCard> createState() => _BackupActionCardState();
}

class _BackupActionCardState extends State<_BackupActionCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.isWorking ? null : widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: TC.text2(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isWorking)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: widget.color,
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: widget.color,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Restore Preview Row ──────────────────────────────────────────────────────

class _PreviewRow extends StatelessWidget {
  final String icon, label, value;
  const _PreviewRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: TC.text2(context)),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: TC.text(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared widget helpers ────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 28),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.green,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final String icon, title, subtitle;
  final Widget? trailing;

  const _SettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.border(context)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: TC.text(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: TC.text2(context),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _TappableSettingCard extends StatefulWidget {
  final String icon, title, subtitle;
  final bool danger;
  final VoidCallback onTap;
  final Widget? trailing;

  const _TappableSettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.trailing,
  });

  @override
  State<_TappableSettingCard> createState() => _TappableSettingCardState();
}

class _TappableSettingCardState extends State<_TappableSettingCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.danger ? AppColors.redDim : TC.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.danger
                  ? AppColors.red.withValues(alpha: 0.3)
                  : TC.border(context),
            ),
          ),
          child: Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: widget.danger
                            ? AppColors.red
                            : TC.text(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: TC.text2(context),
                      ),
                    ),
                  ],
                ),
              ),
              widget.trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: widget.danger ? AppColors.red : TC.text3(context),
                    size: 18,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Privacy Lock Card ───────────────────────────────────────────────────────

class _PrivacyLockCard extends StatefulWidget {
  const _PrivacyLockCard();

  @override
  State<_PrivacyLockCard> createState() => _PrivacyLockCardState();
}

class _PrivacyLockCardState extends State<_PrivacyLockCard> {
  bool _enabled = false;
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final s = await SecurityService.canAuthenticate();
    final e = await SecurityService.isAppLockEnabled();
    if (mounted) {
      setState(() {
        _supported = s;
        _enabled = e;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    HapticFeedback.lightImpact();
    if (value) {
      // Must authenticate to enable it
      final success = await SecurityService.authenticate();
      if (!success) return; 
    }
    await SecurityService.setAppLockEnabled(value);
    if (value) AnalyticsService.logAppLockEnabled();
    setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.purpleDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🔒', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biometric Lock',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: TC.text(context),
                  ),
                ),
                Text(
                  'Require face/fingerprint to open app',
                  style: TextStyle(
                    fontSize: 12,
                    color: TC.text2(context),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: _toggle,
            activeThumbColor: AppColors.bg,
            activeTrackColor: AppColors.purple,
            inactiveThumbColor: TC.text2(context),
            inactiveTrackColor: Theme.of(context).scaffoldBackgroundColor,
          ),
        ],
      ),
    );
  }
}

// ─── Account Card ─────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final isSignedIn = auth.isSignedIn;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.border(context)),
      ),
      child: isSignedIn
          ? Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.greenDim,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.green.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: auth.photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                auth.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    (auth.currentUser?.displayName ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.green,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                (auth.currentUser?.displayName ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.currentUser?.displayName ?? 'User',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: TC.text(context),
                            ),
                          ),
                          if (auth.email != null)
                            Text(
                              auth.email!,
                              style: TextStyle(
                                fontSize: 12,
                                color: TC.text2(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.greenDim,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '● Synced',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Sign Out button
                GestureDetector(
                  onTap: () => _confirmSignOut(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.redDim,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.red.withValues(alpha: 0.2),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppColors.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TC.card2(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_outline_rounded,
                      color: TC.text3(context), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guest Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: TC.text(context),
                        ),
                      ),
                      Text(
                        'Data stored locally only',
                        style: TextStyle(
                          fontSize: 12,
                          color: TC.text2(context),
                        ),
                      ),
                    ],
                  ),
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
            child: Text('Cancel',
                style: TextStyle(color: TC.text2(context))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.signOut();
              if (context.mounted) {
                // Navigate back to root to trigger auth gate
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('Sign Out',
                style: TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
