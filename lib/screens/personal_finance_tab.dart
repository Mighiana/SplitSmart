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
  bool _balanceCollapsed = false;

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
    if (activeCur == null && wallets.keys.isNotEmpty) {
      activeCur = wallets.keys.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.homeCurrency == null) {
          state.setHomeCurrency(activeCur!);
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
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  children: [
                    _buildHeader(context, state, isDark)
                        .animate().fadeIn(duration: 280.ms).slideY(begin: 0.12, end: 0, curve: Curves.easeOut),
                    _buildNetPositionCard(context, overallBalance, sym, activeCur, isDark, state),
                    _buildActionButtons(context, activeCur)
                        .animate().fadeIn(delay: 120.ms, duration: 320.ms).slideY(begin: 0.14, end: 0, delay: 120.ms, curve: Curves.easeOut),
                    _buildQuickStats(context, isDark, state, sym, activeCur)
                        .animate().fadeIn(delay: 200.ms, duration: 360.ms).slideY(begin: 0.14, end: 0, delay: 200.ms, curve: Curves.easeOut),
                    _buildSmartInsight(context, isDark, state, sym, activeCur)
                        .animate().fadeIn(delay: 280.ms, duration: 400.ms).slideY(begin: 0.14, end: 0, delay: 280.ms, curve: Curves.easeOut),
                    _buildUpcomingImportant(context, isDark, state, sym)
                        .animate().fadeIn(delay: 360.ms, duration: 440.ms).slideY(begin: 0.14, end: 0, delay: 360.ms, curve: Curves.easeOut),
                    _buildRecentTransactions(context, isDark, state, sym, activeCur)
                        .animate().fadeIn(delay: 440.ms, duration: 480.ms).slideY(begin: 0.14, end: 0, delay: 440.ms, curve: Curves.easeOut),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                Text(
                  _hideBalance ? '••••' : '${net < 0 ? '-' : ''}${money(net)}',
                  style: TC.gloock(
                    context,
                    fontSize: 42,
                    letterSpacing: -1.0,
                    color: Colors.white,
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
    final int goalsPct = targetSum > 0 ? (savedSum / targetSum * 100).round() : 0;

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
      child: Row(
        children: [
          Expanded(child: _statTile(context, isDark, '🏆', '$goalsPct%', 'Goals', TC.primary(context), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingGoalsScreen()));
          })),
          const SizedBox(width: 10),
          Expanded(child: _statTile(context, isDark, '🔔', '$overdue', 'Overdue', overdue > 0 ? TC.wn(context) : TC.text3(context), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PlannerScreen()));
          })),
          const SizedBox(width: 10),
          Expanded(child: _statTile(context, isDark, '📊', spentStr, 'Spent', TC.er(context), () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen()));
          })),
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

  Widget _buildUpcomingImportant(BuildContext context, bool isDark, AppState state, String sym) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : _kWhite;
    final textColor = isDark ? Colors.white : _kText;

    // First reminder
    final uncompletedReminders = state.reminders.where((r) => !r.isCompleted).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final firstReminder = uncompletedReminders.isNotEmpty ? uncompletedReminders.first : null;

    // First subscription
    final activeSubs = state.subscriptions.where((s) => s.isActive).toList()
      ..sort((a, b) => a.daysUntilBilling.compareTo(b.daysUntilBilling));
    final firstSub = activeSubs.isNotEmpty ? activeSubs.first : null;

    // First goal
    final ongoingGoals = state.savingGoals.where((g) => g.savedAmount < g.targetAmount).toList()
      ..sort((a, b) {
        final aProgress = a.targetAmount > 0 ? (a.savedAmount / a.targetAmount) : 0;
        final bProgress = b.targetAmount > 0 ? (b.savedAmount / b.targetAmount) : 0;
        return bProgress.compareTo(aProgress); // Highest progress first
      });
    final firstGoal = ongoingGoals.isNotEmpty ? ongoingGoals.first : null;

    final hasAny = firstReminder != null || firstSub != null || firstGoal != null;

    return Column(
      children: [
        _buildSectionHeader('Coming Up', 'View all', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlannerScreen()));
        }, isDark),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: !hasAny 
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Nothing upcoming right now',
                    style: TextStyle(color: _kTextMuted, fontSize: 14),
                  ),
                ),
              )
            : Column(
                children: [
                  if (firstReminder != null) ...[
                    _buildUpItem(
                      icon: '🔔', iconBg: const Color(0xFFFFF7ED),
                      name: firstReminder.title,
                      sub: _formatDaysDiff(firstReminder.date),
                      rightWidget: firstReminder.amountStr.isNotEmpty
                          ? Text(firstReminder.amountStr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor))
                          : null,
                      textColor: textColor,
                    ),
                  ],
                  if (firstReminder != null && (firstSub != null || firstGoal != null))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : _kBorder),
                    ),
                  if (firstSub != null) ...[
                    _buildUpItem(
                      icon: firstSub.emoji,
                      iconBg: Color(int.tryParse(firstSub.colorHex.replaceFirst('#', 'FF')) ?? 0xFF1E88E5).withValues(alpha: 0.15),
                      name: firstSub.name,
                      sub: firstSub.daysUntilBilling == 0 ? 'Today' : firstSub.daysUntilBilling == 1 ? 'Tomorrow' : 'In ${firstSub.daysUntilBilling} days',
                      rightWidget: Text('${firstSub.sym}${AppCurrencyUtils.formatAmount(firstSub.amount, 2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                      textColor: textColor,
                    ),
                  ],
                  if (firstSub != null && firstGoal != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : _kBorder),
                    ),
                  if (firstGoal != null) ...[
                    Builder(
                      builder: (ctx) {
                        final pct = firstGoal.targetAmount > 0 ? (firstGoal.savedAmount / firstGoal.targetAmount) : 0.0;
                        final left = firstGoal.targetAmount - firstGoal.savedAmount;
                        return _buildUpItem(
                          icon: '🎯', iconBg: const Color(0xFFE0F2F1),
                          name: firstGoal.title,
                          sub: '${(pct * 100).toStringAsFixed(0)}% completed',
                          hasBar: true,
                          barPct: pct,
                          rightWidget: Text('$sym${AppCurrencyUtils.formatAmount(left, 0)} left', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                          textColor: textColor,
                        );
                      }
                    ),
                  ],
                ],
              ),
        ),
      ],
    ).animate().fade().slideY(begin: 0.1, end: 0, curve: Curves.easeOutBack, duration: 600.ms);
  }

  String _formatDaysDiff(DateTime date) {
    final now = _spendingMonth;
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 0) return 'In $diff days';
    return '${diff.abs()} days ago';
  }

  Widget _buildUpItem({required String icon, required Color iconBg, bool isTextIcon = false, Color? iconColor, required String name, required String sub, bool hasBar = false, double barPct = 0.0, Widget? rightWidget, required Color textColor}) {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isTextIcon 
              ? Text(icon, style: TextStyle(color: iconColor, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Georgia'))
              : Text(icon, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 12, color: _kTextMuted)),
              if (hasBar) ...[
                const SizedBox(height: 6),
                Container(
                  height: 4, width: double.infinity,
                  decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: barPct.clamp(0.0, 1.0),
                    child: Container(decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(2))),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (rightWidget != null) ...[
          const SizedBox(width: 8),
          Row(
            children: [
              rightWidget,
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 16),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSmartInsight(BuildContext context, bool isDark, AppState state, String sym, String? activeCur) {
    // Calculate real insight: highest spending category this month
    final now = _spendingMonth;
    final catSpends = <String, double>{};
    for (var tx in state.allTransactionsWithGroupShares) {
      if (tx.currency == activeCur && tx.type == 'expense') {
        final d = DateTime.tryParse(tx.date);
        if (d != null && d.year == now.year && d.month == now.month) {
          catSpends[tx.cat] = (catSpends[tx.cat] ?? 0) + tx.amount;
        }
      }
    }
    
    String insightText = 'No spending insights yet this month.';
    
    if (catSpends.isNotEmpty) {
      final topCat = catSpends.entries.reduce((a, b) => a.value > b.value ? a : b);
      final topSpend = topCat.value;
      final catData = AppState.expenseCategories.firstWhere((c) => c.icon == topCat.key, orElse: () => const CategoryItem('💰', 'Other', '#9E9E9E'));
      insightText = 'You spent $sym${AppCurrencyUtils.formatAmount(topSpend, 0)} on ${catData.label} this month.';
    }

    return Container(
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
    ).animate().fade().slideY(begin: 0.1, end: 0, curve: Curves.easeOutBack, duration: 600.ms);
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
    
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: (isInc ? const Color(0xFF4CAF50) : const Color(0xFFE57373)).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(t.cat, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(catData.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(t.isGroupShare ? 'Group Expense • ${t.date}' : t.date, style: TextStyle(fontSize: 12, color: _kTextMuted)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DCE98).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      t.currency,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2DCE98)),
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
                                        'This removes your ${curData.code} wallet and its transactions. Your other accounts stay. This cannot be undone.',
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
