import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import 'add_transaction_screen.dart';
import 'activity_screen.dart';
import 'settings_screen.dart';
import '../services/auth_service.dart';
import 'saving_goals_screen.dart';
import 'planner_screen.dart';
import 'personal_charts_screen.dart';
import '../widgets/common_widgets.dart';
import '../utils/icon_map.dart';


class MoneyTab extends StatefulWidget {
  const MoneyTab({super.key});

  @override
  State<MoneyTab> createState() => _MoneyTabState();
}

class _MoneyTabState extends State<MoneyTab> {
  Color get _kGreen => TC.primary(context);
  Color get _kGreenLight => TC.primaryPale(context);
  Color get _kText => TC.text(context);
  Color get _kTextMuted => TC.text2(context);
  Color get _kBg => TC.bg(context);
  Color get _kWhite => TC.surface(context);
  Color get _kBorder => TC.border(context);

  final DateTime _spendingMonth = DateTime.now();

  Timer? _greetTimer;
  int _hour = DateTime.now().hour;
  String _userName = 'User';
  String? _localPhotoPath;
  bool _hideBalance = false;
  // Start collapsed when the app opens — the user can tap to expand.
  bool _balanceCollapsed = true;
  bool _emailVerifyDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadName();
    _checkName();
    _checkTour();
    _greetTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final newHour = DateTime.now().hour;
      if (newHour != _hour && mounted) setState(() => _hour = newHour);
    });
  }

  // Tour removed — was described as inaccurate. Keeping method stub to avoid
  // breaking any remaining call sites.
  Future<void> _checkTour() async {}


  @override
  void dispose() {
    _greetTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_first_name');
    final pic = prefs.getString('user_profile_pic_path');
    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _userName = name;
        if (pic != null && pic.isNotEmpty) _localPhotoPath = pic;
      });
    }
  }

  Future<void> _checkName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_first_name');
    if (name == null || name.isEmpty) {
      if (!mounted) return;
      final TextEditingController ctrl = TextEditingController();
      final newName = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('Welcome!'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Enter your name'),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (newName != null && newName.isNotEmpty) {
        await prefs.setString('user_first_name', newName);
        setState(() => _userName = newName);
      }
    }
  }

  Future<void> _pickProfilePic() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile_pic_path', image.path);
        setState(() => _localPhotoPath = image.path);
      }
    } catch (e) {
      // ignore
    }
  }

  String get _greetingText {
    if (_hour < 12) return 'Good morning,';
    if (_hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.select<AppState, Map<String, double>>((s) => s.wallets);
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? activeCur = state.homeCurrency;
    // Fall back if the saved home currency no longer has a wallet (e.g. deleted).
    if ((activeCur == null || !wallets.containsKey(activeCur)) && wallets.keys.isNotEmpty) {
      activeCur = wallets.keys.first;
      final fallback = activeCur;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.homeCurrency != fallback) {
          state.setHomeCurrency(fallback);
        }
      });
    }

    final overallBalance = activeCur != null ? (wallets[activeCur] ?? 0.0) : 0.0;
    final safeActiveCur = activeCur ?? '';
    final CurrencyData? activeCurData = activeCur != null
        ? AppState.currencies.firstWhere(
            (c) => c.code == activeCur,
            orElse: () => CurrencyData(safeActiveCur, safeActiveCur, '💱', safeActiveCur),
          )
        : null;
    final sym = activeCurData?.sym ?? '\$' ;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : _kBg,
      body: SafeArea(
        bottom: false,
        child: (state.isLoading && wallets.isEmpty && state.transactions.isEmpty)
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 28),
                children: const [
                  SkeletonList(count: 2, itemHeight: 96),
                  SizedBox(height: 20),
                  SkeletonList(count: 4),
                ],
              )
            : RefreshIndicator(
        onRefresh: () => state.refresh(),
        color: TC.primary(context),
        backgroundColor: TC.card(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  children: [
                    _buildHeader(context, state, isDark)
                        .animate().fadeIn(duration: 280.ms).slideY(begin: 0.12, end: 0, curve: Curves.easeOut),
                    _buildEmailVerifyBanner(context),
                    _buildNetPositionCard(context, overallBalance, sym, activeCur, isDark, state),
                    _buildActionButtons(context, activeCur)
                        .animate().fadeIn(delay: 120.ms, duration: 320.ms).slideY(begin: 0.14, end: 0, delay: 120.ms, curve: Curves.easeOut),
                    _buildQuickStats(context, isDark, state, sym, activeCur)
                        .animate().fadeIn(delay: 200.ms, duration: 360.ms).slideY(begin: 0.14, end: 0, delay: 200.ms, curve: Curves.easeOut),
                    _buildMonthlyDonut(context, isDark, state, sym, activeCur)
                        .animate().fadeIn(delay: 240.ms, duration: 380.ms).slideY(begin: 0.14, end: 0, delay: 240.ms, curve: Curves.easeOut),
                    _buildSmartInsight(context, isDark, state, sym, activeCur)
                        .animate().fadeIn(delay: 280.ms, duration: 400.ms).slideY(begin: 0.14, end: 0, delay: 280.ms, curve: Curves.easeOut),
                    _buildRecentTransactions(context, isDark, state, sym, activeCur)
                        .animate().fadeIn(delay: 440.ms, duration: 480.ms).slideY(begin: 0.14, end: 0, delay: 440.ms, curve: Curves.easeOut),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// Soft-gate banner nudging email/password users to verify. Dismissible and
  /// non-blocking — the account keeps working either way.
  Widget _buildEmailVerifyBanner(BuildContext context) {
    final auth = AuthService.instance;
    if (_emailVerifyDismissed ||
        !auth.isEmailPasswordUser ||
        auth.isEmailVerified) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TC.wnPale(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.wn(context).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.mark_email_unread_outlined, size: 20, color: TC.wn(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verify your email',
                    style: TC.geist(context,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: TC.text(context))),
                const SizedBox(height: 2),
                Text('Confirm ${auth.email ?? 'your email'} to secure your account.',
                    style: TC.geist(context,
                        fontSize: 11, color: TC.text2(context))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        try {
                          await auth.sendEmailVerification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Verification email sent')),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not send — try again later')),
                            );
                          }
                        }
                      },
                      child: Text('Resend',
                          style: TC.geist(context,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: TC.primary(context))),
                    ),
                    const SizedBox(width: 18),
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final ok = await auth.reloadEmailVerified();
                        if (ok && mounted) {
                          setState(() {});
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Not verified yet — check your inbox')),
                          );
                        }
                      },
                      child: Text("I've verified",
                          style: TC.geist(context,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: TC.text2(context))),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _emailVerifyDismissed = true),
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.close_rounded, size: 18, color: TC.text3(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState state, bool isDark) {
    final fbName = AuthService.instance.currentUser?.displayName;
    final name = (fbName != null && fbName.isNotEmpty) ? fbName : _userName;
    final photoUrl = AuthService.instance.currentUser?.photoURL;
    final bool hasFbPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final bool hasLocalPhoto = _localPhotoPath != null && _localPhotoPath!.isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickProfilePic,
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8A7060), Color(0xFF4A3828)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: const Color(0xFFE0D5CC), width: 2),
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.hardEdge,
                    child: hasFbPhoto
                        ? Image.network(photoUrl, fit: BoxFit.cover, width: 52, height: 52)
                        : hasLocalPhoto 
                            ? Image.file(File(_localPhotoPath!), fit: BoxFit.cover, width: 52, height: 52)
                            : Text(name.isNotEmpty ? name[0].toUpperCase() : '🧔', style: const TextStyle(fontSize: 24, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 13),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greetingText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : _kTextMuted,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$name 👋',
                        style: TC.gloock(
                          context,
                          fontSize: 22,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : _kText,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              _buildHeaderBtn(context, '🌙', isDark, onTap: () {
                HapticFeedback.lightImpact();
                state.toggleTheme();
              }),
              const SizedBox(width: 10),
              _buildHeaderBtn(context, '⚙️', isDark, onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              }),
            ],
          ),
        ],
      ),
    ).animate().fade().slideY(begin: -0.1, end: 0, curve: Curves.easeOutBack);
  }

  Widget _buildHeaderBtn(BuildContext context, String icon, bool isDark, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : _kWhite,
          shape: BoxShape.circle,
          border: Border.all(color: isDark ? const Color(0xFF333333) : _kBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(icon, style: const TextStyle(fontSize: 17)),
      ),
    );
  }

  Widget _buildNetPositionCard(BuildContext context, double personalBal, String sym, String? activeCur, bool isDark, AppState state) {
    final flag = activeCur != null ? AppState.currencies.firstWhere(
      (c) => c.code == activeCur,
      orElse: () => CurrencyData(activeCur, activeCur, '💱', ''),
    ).flag : '🇺🇸';

    final double groupsBal = activeCur != null ? state.getGroupWalletBalance(activeCur) : 0.0;
    final double net = personalBal + groupsBal;
    final String groupsLabel = groupsBal < 0 ? 'owed' : groupsBal > 0 ? 'to collect' : 'settled';

    String money(double v) => '$sym${AppCurrencyUtils.formatAmount(v.abs(), v.abs() >= 1000 ? 0 : 2)}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: TC.cardGradient(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: TC.primaryGlow(context),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _hideBalance = !_hideBalance);
                      },
                      child: Row(
                        children: [
                          Text(
                            'NET POSITION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white.withValues(alpha: 0.70),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Icon(
                            _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.white.withValues(alpha: 0.70),
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _showAccountsSheet(context, context.read<AppState>()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '$flag ${activeCur ?? "USD"}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 14),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _balanceCollapsed = !_balanceCollapsed);
                          },
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _balanceCollapsed
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _hideBalance
                    ? Text(
                        '••••',
                        style: TC.gloock(context,
                            fontSize: 42, letterSpacing: -1.0, color: Colors.white),
                      )
                    : CountUpText(
                        value: net,
                        builder: (ctx, v) => Text(
                          '${v < 0 ? '-' : ''}${money(v)}',
                          style: TC.gloock(ctx,
                              fontSize: 42,
                              letterSpacing: -1.0,
                              color: Colors.white),
                        ),
                      ),
                if (!_balanceCollapsed) ...[
                  const SizedBox(height: 4),
                  Text(
                    _hideBalance
                        ? 'Personal + Groups'
                        : groupsBal == 0
                            ? 'Across your personal & group wallets'
                            : 'Groups ${money(groupsBal)} $groupsLabel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _netSubCard('👤', 'PERSONAL', _hideBalance ? '••••' : money(personalBal), personalBal < 0)),
                      const SizedBox(width: 12),
                      Expanded(child: _netSubCard('👥', 'GROUPS', _hideBalance ? '••••' : '${groupsBal < 0 ? '-' : ''}${money(groupsBal)}', groupsBal < 0)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().scale(curve: Curves.easeOutBack, duration: 600.ms);
  }

  Widget _netSubCard(String emoji, String label, String amount, bool negative) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TC.gloock(
              context,
              fontSize: 20,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, bool isDark, AppState state, String sym, String? activeCur) {
    // Goals overall %
    final goals = state.savingGoals;
    double savedSum = 0, targetSum = 0;
    for (final g in goals) {
      savedSum += g.savedAmount;
      targetSum += g.targetAmount;
    }
    final int goalsPct = targetSum > 0 ? (savedSum / targetSum * 100).round().clamp(0, 100) : 0;

    // Overdue reminders
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = state.reminders.where((r) =>
        !r.isCompleted &&
        DateTime(r.date.year, r.date.month, r.date.day).isBefore(today)).length;

    // Spent this month (active currency)
    final sm = _spendingMonth;
    double spent = 0;
    for (final tx in state.allTransactionsWithGroupShares) {
      if (tx.currency == activeCur && tx.type == 'expense') {
        final d = DateTime.tryParse(tx.date);
        if (d != null && d.year == sm.year && d.month == sm.month) spent += tx.amount;
      }
    }
    final String spentStr = spent >= 1000
        ? '$sym${(spent / 1000).toStringAsFixed(1)}k'
        : '$sym${AppCurrencyUtils.formatAmount(spent, 0)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Snapshot',
                    style: TC.gloock(context, fontSize: 17, color: TC.text(context))),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PlannerScreen()));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('See all',
                          style: TC.geist(context, fontSize: 12, fontWeight: FontWeight.w600, color: TC.primaryMd(context))),
                      Icon(Icons.chevron_right, size: 16, color: TC.primaryMd(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(child: _statTile(context, isDark, '🏆', '$goalsPct%', 'Goals', TC.primary(context), () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingGoalsScreen()));
              })),
              const SizedBox(width: 10),
              Expanded(child: _statTile(context, isDark, '🔔', '$overdue', 'Overdue', overdue > 0 ? TC.wn(context) : TC.text3(context), () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlannerScreen()));
              })),
              const SizedBox(width: 10),
              Expanded(child: _statTile(context, isDark, '🧾', spentStr, 'Spent', TC.er(context), () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen()));
              })),
            ],
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1, end: 0, curve: Curves.easeOutBack, duration: 600.ms);
  }

  Widget _statTile(BuildContext context, bool isDark, String emoji, String value, String label, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: TC.card(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TC.gloock(context, fontSize: 19, letterSpacing: -0.5, color: accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: TC.text3(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String? activeCur) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransactionScreen(
                  fixedCurrency: activeCur,
                  initialType: 'expense',
                )));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: _kGreen.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Add Expense',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransactionScreen(
                  fixedCurrency: activeCur,
                  initialType: 'income',
                )));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : _kWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kGreen, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_downward_rounded, color: _kGreen, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Add Income',
                      style: TextStyle(color: _kGreen, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1, end: 0, curve: Curves.easeOutBack, duration: 600.ms);
  }

  Widget _buildSectionHeader(String title, String action, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : _kText,
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kGreen,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, color: _kGreen, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyDonut(BuildContext context, bool isDark, AppState state, String sym, String? activeCur) {
    final now = _spendingMonth;
    // Categories the app knows about; anything else collapses into "Other" so
    // non-standard emojis don't each become their own mystery slice.
    final knownCats = <String>{
      for (final c in AppState.expenseCategories) c.icon,
      for (final c in AppState.incomeCategories) c.icon,
    };
    final catSpends = <String, double>{};
    for (var tx in state.allTransactionsWithGroupShares) {
      if (tx.currency == activeCur && tx.type == 'expense') {
        final d = DateTime.tryParse(tx.date);
        if (d != null && d.year == now.year && d.month == now.month) {
          final cat = knownCats.contains(tx.cat) ? tx.cat : '💰'; // 💰 = Other
          catSpends[cat] = (catSpends[cat] ?? 0) + tx.amount;
        }
      }
    }
    final total = catSpends.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();

    final sorted = catSpends.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final otherSum = sorted.skip(5).fold(0.0, (a, b) => a + b.value);

    final slices = <_HomeDonutSlice>[];
    final legend = <Widget>[];
    String catLabel(String emoji) => AppState.expenseCategories
        .firstWhere((c) => c.icon == emoji,
            orElse: () => CategoryItem(emoji, emoji, '#9E9E9E'))
        .label;

    for (final e in top) {
      final c = AppState.getCategoryColor(e.key);
      final lbl = catLabel(e.key);
      // Unknown/legacy categories with no proper label render as "Other".
      final display = lbl == e.key ? 'Other' : lbl;
      slices.add(_HomeDonutSlice(e.value / total, c));
      legend.add(_donutLegendRow(context, c, iconForEmoji(e.key), display,
          '$sym${AppCurrencyUtils.formatAmount(e.value, 0)}',
          '${(e.value / total * 100).round()}%'));
    }
    if (otherSum > 0) {
      // Keep the ring honest with a neutral remainder slice, but instead of a
      // growing "Other" line, offer "See all" → full breakdown of EVERY category.
      const c = Color(0xFF9BB5B0);
      slices.add(_HomeDonutSlice(otherSum / total, c));
      legend.add(
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MoneyChartsScreen(initialCurrency: activeCur),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.more_horiz_rounded, size: 16, color: c),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('See all categories',
                      style: TC.geist(context,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: TC.primary(context))),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: TC.primary(context)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
        border: isDark ? Border.all(color: TC.border(context)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This Month',
                      style: TC.gloock(context, fontSize: 17, color: TC.text(context))),
                  Text(_monthName(now),
                      style: TC.geist(context, fontSize: 11, color: TC.text3(context))),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // Donut "See all" → the full charts/analysis screen.
                  final cur = context.read<AppState>().homeCurrency;
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              MoneyChartsScreen(initialCurrency: cur)));
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('See all',
                        style: TC.geist(context, fontSize: 12, fontWeight: FontWeight.w600, color: TC.primaryMd(context))),
                    Icon(Icons.chevron_right, size: 16, color: TC.primaryMd(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 116, height: 116,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(116, 116),
                      painter: _HomeDonutPainter(slices, TC.bg2(context)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$sym${AppCurrencyUtils.formatAmount(total, 0)}',
                            style: TC.gloock(context, fontSize: 18, color: TC.text(context)),
                          ),
                        ),
                        Text('spent',
                            style: TC.geist(context, fontSize: 10, color: TC.text3(context))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(child: Column(children: legend)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _donutLegendRow(BuildContext context, Color color, IconData icon, String label, String amount, String pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TC.geist(context,
                    fontSize: 12, fontWeight: FontWeight.w500, color: TC.text(context))),
          ),
          const SizedBox(width: 6),
          Text(pct,
              style: TC.geist(context, fontSize: 11, color: TC.text3(context))),
          const SizedBox(width: 8),
          Text(amount,
              style: TC.gloock(context, fontSize: 13, color: TC.text(context))),
        ],
      ),
    );
  }

  String _monthName(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  Widget _buildSmartInsight(BuildContext context, bool isDark, AppState state, String sym, String? activeCur) {
    final now = _spendingMonth;
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    double thisTotal = 0, lastTotal = 0;
    int thisCount = 0, lastCount = 0;
    final catSpends = <String, double>{};
    for (var tx in state.allTransactionsWithGroupShares) {
      if (tx.currency != activeCur || tx.type != 'expense') continue;
      final d = tx.rawDate ?? DateTime.tryParse(tx.date);
      if (d == null) continue;
      if (d.year == now.year && d.month == now.month) {
        thisTotal += tx.amount;
        thisCount++;
        catSpends[tx.cat] = (catSpends[tx.cat] ?? 0) + tx.amount;
      } else if (d.year == lastMonth.year && d.month == lastMonth.month) {
        lastTotal += tx.amount;
        lastCount++;
      }
    }

    // Priority: month-over-month trend > top category > onboarding nudge.
    String insightText;
    final overdue = state.reminders.where((r) =>
        !r.isCompleted &&
        DateTime(r.date.year, r.date.month, r.date.day)
            .isBefore(DateTime(now.year, now.month, now.day))).length;

    if (thisTotal <= 0 && lastTotal <= 0) {
      insightText = 'Add an expense and I’ll start spotting trends for you.';
    } else if (overdue > 0) {
      insightText = 'You have $overdue overdue ${overdue == 1 ? 'bill' : 'bills'}. Tap Overdue to settle them.';
    } else if (lastTotal > 0 && thisTotal > 0) {
      final diff = ((thisTotal - lastTotal) / lastTotal * 100).round();
      if (diff <= -5) {
        insightText = 'You’re spending ${diff.abs()}% less than last month. Nice work! 🎉';
      } else if (diff >= 5) {
        insightText = 'You’re spending $diff% more than last month so far.';
      } else {
        insightText = 'Your spending is about the same as last month.';
      }
    } else if (catSpends.isNotEmpty && thisTotal > 0) {
      final topCat = catSpends.entries.reduce((a, b) => a.value > b.value ? a : b);
      final catData = AppState.expenseCategories.firstWhere((c) => c.icon == topCat.key, orElse: () => const CategoryItem('💰', 'Other', '#9E9E9E'));
      final pct = (topCat.value / thisTotal * 100).round();
      insightText = '${catData.label} is your top category — $pct% of spending.';
    } else {
      insightText = 'No spending yet this month.';
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showInsightProof(context, state, sym, now, lastMonth, thisTotal,
            lastTotal, thisCount, lastCount, catSpends, insightText);
      },
      child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF152A20) : const Color(0xFFF7FBF8),
        border: Border.all(color: isDark ? const Color(0xFF1E4D35) : const Color(0xFFD4EDDB), width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: -2, left: 0,
            child: Text('✦', style: TextStyle(color: Color(0xFFF5C518), fontSize: 14)),
          ),
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A3B2A) : _kGreenLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kGreen.withValues(alpha: 0.2), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.insights_rounded, color: _kGreen, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Insight',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : _kText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      insightText,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : _kTextMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: _kGreen, size: 20),
            ],
          ),
        ],
      ),
      ),
    ).animate().fade().slideY(begin: 0.1, end: 0, curve: Curves.easeOutBack, duration: 600.ms);
  }

  /// "Show your work" sheet for the Smart Insight — the raw numbers behind
  /// the sentence so the user can verify the calculation.
  void _showInsightProof(
      BuildContext context,
      AppState state,
      String sym,
      DateTime thisMonth,
      DateTime lastMonth,
      double thisTotal,
      double lastTotal,
      int thisCount,
      int lastCount,
      Map<String, double> catSpends,
      String insightText) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final diff = lastTotal > 0
        ? ((thisTotal - lastTotal) / lastTotal * 100)
        : null;
    final topCats = catSpends.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Text(label,
                style: TC.geist(context,
                    fontSize: 12.5, color: TC.text3(context))),
            const Spacer(),
            Text(value,
                style: TC.geist(context,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: color ?? TC.text(context))),
          ]),
        );

    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Icon(Icons.insights_rounded,
                    size: 20, color: TC.primary(context)),
                const SizedBox(width: 8),
                Text('How this was calculated',
                    style: TC.gloock(context,
                        fontSize: 18, color: TC.text(context))),
              ]),
              const SizedBox(height: 6),
              Text(insightText,
                  style: TC.geist(context,
                      fontSize: 12.5, color: TC.text2(context), height: 1.4)),
              const SizedBox(height: 12),
              Divider(color: TC.border(context), height: 1),
              const SizedBox(height: 6),
              row('${months[thisMonth.month - 1]} spending ($thisCount txns)',
                  '$sym${AppCurrencyUtils.formatAmount(thisTotal, 2)}'),
              row('${months[lastMonth.month - 1]} spending ($lastCount txns)',
                  '$sym${AppCurrencyUtils.formatAmount(lastTotal, 2)}'),
              if (diff != null)
                row(
                    'Change: ($sym${AppCurrencyUtils.formatAmount(thisTotal, 0)} − $sym${AppCurrencyUtils.formatAmount(lastTotal, 0)}) ÷ $sym${AppCurrencyUtils.formatAmount(lastTotal, 0)}',
                    '${diff >= 0 ? '+' : ''}${diff.round()}%',
                    color: diff >= 0 ? TC.er(context) : TC.ok(context)),
              if (topCats.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('TOP CATEGORIES THIS MONTH',
                    style: TC.geist(context,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: TC.text3(context))),
                const SizedBox(height: 4),
                ...topCats.take(4).map((e) {
                  final pct = thisTotal > 0
                      ? (e.value / thisTotal * 100).round()
                      : 0;
                  final label = AppState.labelForKey(e.key);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Icon(iconForEmoji(e.key),
                          size: 15,
                          color: colorForEmoji(e.key,
                              fallback: TC.primary(context))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label,
                            style: TC.geist(context,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: TC.text(context))),
                      ),
                      Text(
                          '$sym${AppCurrencyUtils.formatAmount(e.value, 2)} · $pct%',
                          style: TC.geist(context,
                              fontSize: 12.5, color: TC.text2(context))),
                    ]),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, bool isDark, AppState state, String sym, String? activeCur) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : _kWhite;
    final textColor = isDark ? Colors.white : _kText;

    // Show ALL currencies' transactions — user may have PKR, USD, etc.
    final allTxns = state.allTransactionsWithGroupShares.toList();
    allTxns.sort((a, b) {
      final da = a.rawDate;
      final db = b.rawDate;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    final recentTxns = allTxns.take(4).toList();

    return Column(
      children: [
        _buildSectionHeader('Recent Transactions', 'See all', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen()));
        }, isDark),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: recentTxns.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No recent transactions',
                      style: TextStyle(color: _kTextMuted, fontSize: 14),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < recentTxns.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : _kBorder),
                        ),
                      _buildRealTxItem(context, recentTxns[i], isDark, textColor),
                    ],
                  ],
                ),
        ),
      ],
    ).animate().fade().slideY(begin: 0.1, end: 0, curve: Curves.easeOutBack, duration: 600.ms);
  }

  Widget _buildRealTxItem(BuildContext context, TransactionData t, bool isDark, Color textColor) {
    final isInc = t.type == 'income';
    final catData = AppState.expenseCategories.firstWhere(
      (c) => c.icon == t.cat,
      orElse: () => AppState.incomeCategories.firstWhere(
        (c) => c.icon == t.cat,
        orElse: () => const CategoryItem('?', 'Other', '#9999aa'),
      ),
    );

    final String amtStr = '${isInc ? '+' : '-'}${t.sym}${AppCurrencyUtils.formatAmount(t.amount, 2)}';

    // Short, clean date (the stored value can be a full ISO timestamp).
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = t.rawDate != null
        ? '${months[t.rawDate!.month - 1]} ${t.rawDate!.day}'
        : t.date;

    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: (isInc ? const Color(0xFF4CAF50) : const Color(0xFFE57373)).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(iconForEmoji(t.cat), size: 20,
              color: isInc ? const Color(0xFF4CAF50) : const Color(0xFFE57373)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.desc.trim().isNotEmpty ? t.desc : catData.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      t.isGroupShare ? 'Group • $dateStr' : dateStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: _kTextMuted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: TC.primaryPale(context),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      t.currency,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: TC.primaryMd(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(
          amtStr,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isInc ? _kGreen : textColor,
          ),
        ),
      ],
    );
  }


  void _showAccountsSheet(BuildContext parentCtx, AppState state) {
    showModalBottomSheet(
      context: parentCtx,
      backgroundColor: TC.card(parentCtx),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        final wallets = state.wallets;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(parentCtx), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Your Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(parentCtx))),
                    const Spacer(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _showAddAccountSheet(parentCtx, state);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.green.withValues(alpha: 0.3))),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add, color: AppColors.green, size: 16), SizedBox(width: 4), Text('Add Account', style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w700))]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (wallets.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    const Text('💳', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text('No accounts yet', style: TextStyle(fontSize: 14, color: TC.text2(parentCtx))),
                    const SizedBox(height: 4),
                    Text('Tap "Add Account" to create one', style: TextStyle(fontSize: 12, color: TC.text3(parentCtx))),
                  ]),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(parentCtx).size.height * 0.4),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: wallets.entries.map((e) {
                    final curData = AppState.currencies.firstWhere((c) => c.code == e.key, orElse: () => CurrencyData(e.key, e.key, '💱', e.key));
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(sheetCtx);
                        state.setHomeCurrency(e.key);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: TC.card2(parentCtx), borderRadius: BorderRadius.circular(16), border: Border.all(color: TC.border(parentCtx))),
                        child: Row(
                          children: [
                            Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(curData.flag, style: const TextStyle(fontSize: 22))),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${curData.code} Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(parentCtx))),
                              Text(curData.name, style: TextStyle(fontSize: 11, color: TC.text3(parentCtx))),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('${curData.sym}${AppCurrencyUtils.formatAmount(e.value.abs(), 0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: e.value >= 0 ? AppColors.green : AppColors.red)),
                              Text(e.value >= 0 ? 'Balance' : 'Deficit', style: TextStyle(fontSize: 10, color: TC.text3(parentCtx))),
                            ]),
                            const SizedBox(width: 4),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                showDialog(
                                  context: parentCtx,
                                  builder: (dCtx) => AlertDialog(
                                    backgroundColor: TC.card(parentCtx),
                                    title: Text('Delete ${curData.code} account?',
                                        style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(parentCtx))),
                                    content: Text(
                                        'This removes your ${curData.code} account. Your other accounts stay, and past records are kept. This cannot be undone.',
                                        style: TextStyle(color: TC.text2(parentCtx))),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dCtx),
                                        child: Text('Cancel', style: TextStyle(color: TC.text3(parentCtx))),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(dCtx);
                                          final wasActive = state.homeCurrency == e.key;
                                          await state.deleteWallet(e.key);
                                          if (wasActive && state.wallets.isNotEmpty) {
                                            state.setHomeCurrency(state.wallets.keys.first);
                                          }
                                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                        },
                                        child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.delete_outline_rounded, color: TC.text3(parentCtx), size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showAddAccountSheet(BuildContext parentCtx, AppState state) {
    final sheetBgColor = TC.card(parentCtx);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!parentCtx.mounted) return;
      final existing = state.wallets.keys.toSet();
      final available = AppState.currencies.where((c) => !existing.contains(c.code)).toList();
      showModalBottomSheet(
        context: parentCtx,
        backgroundColor: sheetBgColor,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetCtx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(parentCtx), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Add New Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(parentCtx)))),
                const SizedBox(height: 4),
                Text('Select a currency for your new account', style: TextStyle(fontSize: 12, color: TC.text3(parentCtx))),
                const SizedBox(height: 16),
                if (available.isEmpty)
                  Padding(padding: const EdgeInsets.all(32), child: Text('All currencies already have accounts', style: TextStyle(color: TC.text2(parentCtx), fontSize: 14))),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(parentCtx).size.height * 0.5),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: available.length,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemBuilder: (_, i) {
                      final c = available[i];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(sheetCtx);
                          _showBudgetSetupSheet(parentCtx, state, c);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: TC.card2(parentCtx), borderRadius: BorderRadius.circular(14), border: Border.all(color: TC.border(parentCtx))),
                          child: Row(children: [
                            Text(c.flag, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${c.code} - ${c.name}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TC.text(parentCtx))),
                              Text('Symbol: ${c.sym}', style: TextStyle(fontSize: 11, color: TC.text3(parentCtx))),
                            ])),
                            const Icon(Icons.add_circle_outline, color: AppColors.green, size: 22),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    });
  }

  void _showBudgetSetupSheet(BuildContext parentCtx, AppState state, CurrencyData c) {
    final sheetBgColor = TC.card(parentCtx);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!parentCtx.mounted) return;
      double amount = 0;
      bool isWeekly = false;

      showModalBottomSheet(
        context: parentCtx,
        backgroundColor: sheetBgColor,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetCtx) {
          return StatefulBuilder(builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    const SizedBox(height: 8),
                    Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Setup Account Budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context)))),
                    const SizedBox(height: 4),
                    Text('Optional budget for your ${c.code} account', style: TextStyle(fontSize: 12, color: TC.text3(context))),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: TC.card2(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: TC.border(context))),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isWeekly = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(color: !isWeekly ? AppColors.green : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                  alignment: Alignment.center,
                                  child: Text('Monthly', style: TextStyle(color: !isWeekly ? Colors.white : TC.text2(context), fontWeight: FontWeight.w700, fontSize: 13)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isWeekly = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(color: isWeekly ? AppColors.green : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                  alignment: Alignment.center,
                                  child: Text('Weekly', style: TextStyle(color: isWeekly ? Colors.white : TC.text2(context), fontWeight: FontWeight.w700, fontSize: 13)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: '${c.sym} ',
                          prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.green),
                          border: InputBorder.none,
                          filled: true,
                          fillColor: TC.card2(context),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onChanged: (v) => amount = double.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () {
                          state.createWallet(c.code, 0);
                          if (amount > 0) {
                            final mBudget = isWeekly ? amount * 4.33 : amount;
                            state.setBudgetLimit('_overall', c.code, mBudget);
                          }
                          final code = c.code;
                          final currCtx = parentCtx;
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(currCtx).showSnackBar(SnackBar(content: Text('${c.flag} $code account created!'), backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                          
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (!currCtx.mounted) return;
                            showDialog(
                              context: currCtx,
                              builder: (dlCtx) => AlertDialog(
                                backgroundColor: TC.surface(currCtx),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('Set a Saving Goal?', style: TextStyle(color: TC.text(currCtx), fontWeight: FontWeight.w800)),
                                content: Text('Would you like to set a saving goal (like a car or new house) for your $code account?', style: TextStyle(color: TC.text2(currCtx))),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dlCtx), child: Text('Not Now', style: TextStyle(color: TC.text3(currCtx)))),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(dlCtx);
                                      Navigator.push(currCtx, MaterialPageRoute(builder: (_) => SavingGoalsScreen(initialCurrency: code)));
                                    },
                                    child: const Text('Add Goal', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            );
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                          alignment: Alignment.center,
                          child: const Text('Create Account', style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
          });
        },
      );
    });
  }
}

// ─── Home monthly-spending donut ──────────────────────────────────────────────
class _HomeDonutSlice {
  final double fraction; // 0..1
  final Color color;
  _HomeDonutSlice(this.fraction, this.color);
}

class _HomeDonutPainter extends CustomPainter {
  final List<_HomeDonutSlice> slices;
  final Color trackColor;
  _HomeDonutPainter(this.slices, this.trackColor);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const stroke = 16.0;
    final inner = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(inner, 0, 6.28318, false, track);

    double start = -1.5708; // -90°
    const gap = 0.04;
    for (final s in slices) {
      final sweep = s.fraction * 6.28318;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = s.color;
      final drawSweep = (sweep - gap).clamp(0.02, 6.28318);
      canvas.drawArc(inner, start + gap / 2, drawSweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _HomeDonutPainter old) =>
      old.slices != slices || old.trackColor != trackColor;
}
