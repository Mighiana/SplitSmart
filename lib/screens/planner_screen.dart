import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import 'reminders_screen.dart';
import 'subscriptions_screen.dart';
import 'saving_goals_screen.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  // Per-goal accent palette (SavingGoal has no colour field).
  static const _goalPalette = [
    Color(0xFF3B82F6), // blue
    Color(0xFFD97706), // amber
    Color(0xFF059669), // green
    Color(0xFF8B5CF6), // purple
    Color(0xFFE85A6A), // red
  ];

  String _sym(String code) => AppState.currencies
      .firstWhere((c) => c.code == code,
          orElse: () => CurrencyData(code, code, '💰', code))
      .sym;

  String _goalEmoji(String title) {
    final t = title.toLowerCase();
    if (t.contains('car') || t.contains('vehicle')) return '🚗';
    if (t.contains('home') || t.contains('house')) return '🏠';
    if (t.contains('trip') ||
        t.contains('travel') ||
        t.contains('vacation') ||
        t.contains('japan') ||
        t.contains('italy')) {
      return '✈️';
    }
    if (t.contains('emergency')) return '🏦';
    if (t.contains('macbook') ||
        t.contains('laptop') ||
        t.contains('pc') ||
        t.contains('computer')) {
      return '💻';
    }
    if (t.contains('ps5') ||
        t.contains('xbox') ||
        t.contains('game') ||
        t.contains('console')) {
      return '🎮';
    }
    if (t.contains('phone') || t.contains('gadget') || t.contains('tech')) {
      return '📱';
    }
    return '🎯';
  }

  String _monthYear(DateTime d) =>
      '${DateFormat('MMM').format(d)} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final goals = state.savingGoals;
    final subs = state.subscriptions;
    final reminders = state.reminders;

    final activeGoals =
        goals.where((g) => g.savedAmount < g.targetAmount).toList();

    // Total saved — grouped by currency, display the dominant one.
    final savedByCur = <String, double>{};
    for (final g in goals) {
      savedByCur[g.currency] = (savedByCur[g.currency] ?? 0) + g.savedAmount;
    }
    final savedPrimary = savedByCur.entries.isEmpty
        ? null
        : savedByCur.entries.reduce((a, b) => a.value >= b.value ? a : b);

    // Monthly subscription cost — dominant currency.
    final monthlyCosts = state.subscriptionMonthlyCostByCurrency;
    final subsPrimary = monthlyCosts.entries.isEmpty
        ? null
        : monthlyCosts.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final overdue = reminders
        .where((r) =>
            !r.isCompleted &&
            DateTime(r.date.year, r.date.month, r.date.day).isBefore(today))
        .toList();
    final upcoming = reminders.where((r) => !r.isCompleted).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            _header(context)
                .animate()
                .fade(duration: 280.ms)
                .slideY(begin: -0.12, end: 0, curve: Curves.easeOutBack),
            _heroCard(context, savedPrimary, activeGoals.length,
                    subsPrimary, overdue.length)
                .animate(delay: 80.ms)
                .fade(duration: 360.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutBack),
            _goalsSection(context, goals, activeGoals)
                .animate(delay: 160.ms)
                .fade(duration: 360.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
            _subsSection(context, subs, subsPrimary)
                .animate(delay: 240.ms)
                .fade(duration: 360.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
            _remindersSection(context, upcoming, overdue.length)
                .animate(delay: 320.ms)
                .fade(duration: 360.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────
  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FINANCIAL PLANNING',
                  style: TC.geist(context,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: TC.primaryMd(context),
                      letterSpacing: 1.5),
                ),
                const SizedBox(height: 3),
                Text('Planner',
                    style: TC.gloock(context,
                        fontSize: 34, letterSpacing: -0.8)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showAddSheet(context),
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: TC.primary(context),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: TC.primaryGlow(context),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text('Add',
                      style: TC.geist(context,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero snapshot card ──────────────────────────────────────────────────
  Widget _heroCard(
    BuildContext context,
    MapEntry<String, double>? savedPrimary,
    int activeGoals,
    MapEntry<String, double>? subsPrimary,
    int overdueCount,
  ) {
    final subsSym = subsPrimary != null ? _sym(subsPrimary.key) : '';
    final subsTotal = subsPrimary?.value ?? 0;

    const greenTint = Color(0xE686EFAC); // rgba(134,239,172,.9)
    const redTint = Color(0xE6FCA5A5); // rgba(252,165,165,.9)

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: TC.cardGradient(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: TC.primaryGlow(context),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PLANNER SNAPSHOT',
              style: TC.geist(context,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.8)),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _heroStat(context, 'Active Goals', '$activeGoals', greenTint),
                _heroDivider(),
                _heroStat(
                    context,
                    'Monthly Subs',
                    '$subsSym${AppCurrencyUtils.formatAmount(subsTotal, 0)}',
                    redTint),
                _heroDivider(),
                _heroStat(context, 'Overdue', '$overdueCount',
                    overdueCount > 0 ? redTint : greenTint),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(
      BuildContext context, String label, String value, Color valueColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: Column(
          children: [
            Text(label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TC.geist(context,
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.45),
                    letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text(value,
                style: TC.gloock(context, fontSize: 17, color: valueColor)),
          ],
        ),
      ),
    );
  }

  Widget _heroDivider() => Container(
      width: 1, height: 44, color: Colors.white.withValues(alpha: 0.14));

  // ─── Section header ──────────────────────────────────────────────────────
  Widget _sectionHeader(
      BuildContext context, String title, String link, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: TC.gloock(context, fontSize: 21, letterSpacing: -0.2)),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Text(link,
                style: TC.geist(context,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: TC.primaryMd(context))),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco(BuildContext context) => BoxDecoration(
        color: TC.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TC.border(context)),
        boxShadow: [
          BoxShadow(
            color: TC.shadow(context),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _divider(BuildContext context) =>
      Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 18), color: TC.border2(context));

  // ─── Saving Goals section ────────────────────────────────────────────────
  Widget _goalsSection(BuildContext context, List<SavingGoal> goals,
      List<SavingGoal> activeGoals) {
    void openGoals() => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SavingGoalsScreen()));

    final preview = goals.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
              context, 'Saving Goals', 'See all ${goals.length} →', openGoals),
          if (preview.isEmpty)
            _emptyTile(context, '🎯', 'No saving goals yet', openGoals)
          else
            Container(
              decoration: _cardDeco(context),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < preview.length; i++) ...[
                    _goalRow(context, preview[i], openGoals),
                    if (i < preview.length - 1) _divider(context),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _goalRow(BuildContext context, SavingGoal g, VoidCallback onTap) {
    final pct = g.targetAmount > 0
        ? ((g.savedAmount / g.targetAmount) * 100).round().clamp(0, 100)
        : 0;
    final color = _goalPalette[g.id % _goalPalette.length];
    final sym = _sym(g.currency);
    final deadline =
        g.targetDate != null ? _monthYear(g.targetDate!) : 'No date';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(_goalEmoji(g.title),
                      style: const TextStyle(fontSize: 17)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TC.geist(context,
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 1),
                      Text('🗓 $deadline',
                          style: TC.geist(context,
                              fontSize: 10, color: TC.text3(context))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$pct%', style: TC.gloock(context, fontSize: 16)),
                    const SizedBox(height: 1),
                    Text(
                        '$sym${AppCurrencyUtils.formatAmount(g.savedAmount, 0)} / $sym${AppCurrencyUtils.formatAmount(g.targetAmount, 0)}',
                        style: TC.geist(context,
                            fontSize: 10, color: TC.text3(context))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _progressBar(context, pct / 100, color),
          ],
        ),
      ),
    );
  }

  Widget _progressBar(BuildContext context, double frac, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 6,
        color: TC.bg2(context),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: frac.clamp(0.0, 1.0),
          child: Container(color: color),
        ),
      ),
    );
  }

  // ─── Subscriptions section ───────────────────────────────────────────────
  Widget _subsSection(BuildContext context, List<SubscriptionData> subs,
      MapEntry<String, double>? subsPrimary) {
    void openSubs() => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SubscriptionsScreen()));

    final preview = subs.take(3).toList();
    final sym = subsPrimary != null ? _sym(subsPrimary.key) : '';
    final total = subsPrimary?.value ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
              context, 'Subscriptions', 'See all ${subs.length} →', openSubs),
          // Monthly cost banner
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: TC.primaryPale(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total monthly cost',
                    style: TC.geist(context,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: TC.text2(context))),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$sym${AppCurrencyUtils.formatAmount(total, 2)}',
                        style: TC.gloock(context,
                            fontSize: 20, color: TC.primary(context))),
                    Text('/mo',
                        style: TC.geist(context,
                            fontSize: 12, color: TC.text3(context))),
                  ],
                ),
              ],
            ),
          ),
          if (preview.isEmpty)
            _emptyTile(context, '💳', 'No subscriptions yet', openSubs)
          else
            Container(
              decoration: _cardDeco(context),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < preview.length; i++) ...[
                    _subRow(context, preview[i], openSubs),
                    if (i < preview.length - 1) _divider(context),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _subRow(
      BuildContext context, SubscriptionData s, VoidCallback onTap) {
    final renew = DateFormat('MMM d').format(s.nextBillingDate);
    final cycle = s.cycleLabel == 'week'
        ? 'Weekly'
        : s.cycleLabel == 'year'
            ? 'Yearly'
            : 'Monthly';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: TC.bg2(context),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(s.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TC.geist(context,
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('$cycle · Renews $renew',
                      style: TC.geist(context,
                          fontSize: 11, color: TC.text3(context))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${s.sym}${AppCurrencyUtils.formatAmount(s.amount, 2)}',
                    style: TC.gloock(context, fontSize: 15)),
                const SizedBox(height: 3),
                _statusTag(context, s.isActive ? 'active' : 'paused',
                    s.isActive ? TC.ok(context) : TC.text3(context),
                    s.isActive ? TC.okPale(context) : TC.bg2(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Reminders section ───────────────────────────────────────────────────
  Widget _remindersSection(
      BuildContext context, List<ReminderData> upcoming, int overdueCount) {
    void openReminders() => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RemindersScreen()));

    final preview = upcoming.take(3).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(context, 'Reminders', 'See all →', openReminders),
          if (overdueCount > 0)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                openReminders();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: TC.erPale(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '$overdueCount overdue payment${overdueCount > 1 ? 's' : ''}',
                              style: TC.geist(context,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: TC.er(context))),
                          const SizedBox(height: 2),
                          Text('Tap to view and pay now',
                              style: TC.geist(context,
                                  fontSize: 11, color: TC.text2(context))),
                        ],
                      ),
                    ),
                    Text('›',
                        style: TextStyle(
                            fontSize: 18, color: TC.er(context))),
                  ],
                ),
              ),
            ),
          if (preview.isEmpty)
            _emptyTile(context, '🔔', 'No upcoming reminders', openReminders)
          else
            Container(
              decoration: _cardDeco(context),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < preview.length; i++) ...[
                    _reminderRow(context, preview[i], today, openReminders),
                    if (i < preview.length - 1) _divider(context),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _reminderRow(BuildContext context, ReminderData r, DateTime today,
      VoidCallback onTap) {
    final due = DateTime(r.date.year, r.date.month, r.date.day);
    final diff = due.difference(today).inDays;
    final Color dot = diff < 0
        ? TC.er(context)
        : diff <= 3
            ? TC.wn(context)
            : TC.blue(context);
    final dueLabel = DateFormat('MMM d').format(r.date);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TC.geist(context,
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Due $dueLabel',
                      style: TC.geist(context,
                          fontSize: 11, color: TC.text3(context))),
                ],
              ),
            ),
            if (r.amountStr.isNotEmpty)
              Text(r.amountStr, style: TC.gloock(context, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  // ─── Shared atoms ────────────────────────────────────────────────────────
  Widget _statusTag(
      BuildContext context, String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label.toUpperCase(),
          style: TC.geist(context,
              fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _emptyTile(
      BuildContext context, String emoji, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: _cardDeco(context),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 8),
            Text(label,
                style: TC.geist(context,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TC.text3(context))),
          ],
        ),
      ),
    );
  }

  // ─── "+ Add" picker ──────────────────────────────────────────────────────
  void _showAddSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: TC.border(context),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Text('Add to Planner',
                  style: TC.gloock(context, fontSize: 20)),
              const SizedBox(height: 16),
              _addOption(context, sheetCtx, '🎯', 'New Saving Goal',
                  () => const SavingGoalsScreen()),
              const SizedBox(height: 10),
              _addOption(context, sheetCtx, '🔄', 'New Subscription',
                  () => const SubscriptionsScreen()),
              const SizedBox(height: 10),
              _addOption(context, sheetCtx, '🔔', 'New Reminder',
                  () => const RemindersScreen()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addOption(BuildContext context, BuildContext sheetCtx, String emoji,
      String label, Widget Function() builder) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(sheetCtx);
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => builder()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: TC.card2(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TC.border(context)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TC.geist(context,
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right_rounded,
                color: TC.text3(context), size: 22),
          ],
        ),
      ),
    );
  }
}
