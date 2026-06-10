import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../utils/icon_map.dart';
import 'reminders_screen.dart';
import 'subscriptions_screen.dart';
import 'saving_goals_screen.dart';
import 'budget_screen.dart';
import 'new_budget_screen.dart';

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

  Color _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return _goalPalette.first;
    final v = int.tryParse(hex.replaceAll('#', ''), radix: 16);
    return v == null ? _goalPalette.first : Color(0xFF000000 | v);
  }

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
    final budgets = state.budgets;

    final overdue = reminders
        .where((r) =>
            !r.isCompleted &&
            DateTime(r.date.year, r.date.month, r.date.day).isBefore(today))
        .toList();
    final upcoming = reminders.where((r) => !r.isCompleted).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Monthly subscription cost — dominant currency.
    final monthlyCosts = state.subscriptionMonthlyCostByCurrency;
    final subsPrimary = monthlyCosts.entries.isEmpty
        ? null
        : monthlyCosts.entries.reduce((a, b) => a.value >= b.value ? a : b);

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
            _quickActions(context)
                .animate(delay: 40.ms)
                .fade(duration: 320.ms)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            _bentoRow(context, state, budgets, upcoming, overdue.length)
                .animate(delay: 80.ms)
                .fade(duration: 340.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
            _goalsCarousel(context, goals)
                .animate(delay: 160.ms)
                .fade(duration: 360.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
            _subsSection(context, subs, subsPrimary)
                .animate(delay: 240.ms)
                .fade(duration: 360.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }

  // ─── Bento tiles: Budgets + Reminders ────────────────────────────────────
  Widget _bentoRow(
      BuildContext context,
      AppState state,
      List<Budget> budgets,
      List<ReminderData> upcoming,
      int overdueCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _budgetBentoTile(context, state, budgets)),
          const SizedBox(width: 12),
          Expanded(child: _reminderBentoTile(context, upcoming, overdueCount)),
        ],
      ),
    );
  }

  Widget _bentoShell(BuildContext context,
      {required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 128,
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(context),
        child: child,
      ),
    );
  }

  Widget _budgetBentoTile(
      BuildContext context, AppState state, List<Budget> budgets) {
    final top = budgets.isEmpty ? null : budgets.first;
    double frac = 0;
    Color barColor = TC.primary(context);
    if (top != null && top.amount > 0) {
      final spent = state.budgetSpent(top);
      frac = (spent / top.amount).clamp(0.0, 1.0);
      barColor = spent > top.amount
          ? TC.er(context)
          : (frac >= 0.8 ? TC.wn(context) : TC.primary(context));
    }
    return _bentoShell(
      context,
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const BudgetScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: TC.primaryPale(context), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(iconForEmoji('📊'),
                  size: 17, color: TC.primary(context)),
            ),
            const Spacer(),
            if (top == null)
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: TC.text3(context))
            else
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  value: frac,
                  strokeWidth: 4.5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: TC.bg2(context),
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
          ]),
          const Spacer(),
          Text('Budgets',
              style: TC.gloock(context, fontSize: 16, color: TC.text(context))),
          const SizedBox(height: 3),
          Text(
              top == null
                  ? 'Set spending limits'
                  : '${budgets.length} active · ${(frac * 100).round()}% used',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TC.geist(context, fontSize: 11, color: TC.text3(context))),
        ],
      ),
    );
  }

  Widget _reminderBentoTile(
      BuildContext context, List<ReminderData> upcoming, int overdueCount) {
    final next = upcoming.isEmpty ? null : upcoming.first;
    return _bentoShell(
      context,
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const RemindersScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: TC.blue(context).withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(Icons.notifications_rounded,
                  size: 17, color: TC.blue(context)),
            ),
            const Spacer(),
            if (overdueCount > 0)
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: TC.erPale(context),
                      borderRadius: BorderRadius.circular(20)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('$overdueCount overdue',
                        style: TC.geist(context,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: TC.er(context))),
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: TC.text3(context)),
          ]),
          const Spacer(),
          Text('Reminders',
              style: TC.gloock(context, fontSize: 16, color: TC.text(context))),
          const SizedBox(height: 3),
          Text(
              next == null
                  ? 'Nothing due'
                  : '${next.title} · ${DateFormat('MMM d').format(next.date)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TC.geist(context, fontSize: 11, color: TC.text3(context))),
        ],
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
        ],
      ),
    );
  }

  // ─── Quick actions pill bar ──────────────────────────────────────────────
  Widget _quickActions(BuildContext context) {
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 7),
                Text(label,
                    style: TC.geist(context,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      decoration: BoxDecoration(
        color: TC.primary(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: TC.primaryGlow(context),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          action(Icons.donut_small_rounded, 'New Budget', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NewBudgetScreen()));
          }),
          Container(
              width: 1,
              height: 22,
              color: Colors.white.withValues(alpha: 0.25)),
          action(Icons.notifications_rounded, 'New Reminder', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RemindersScreen()));
          }),
        ],
      ),
    );
  }

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

  // ─── Saving Goals — horizontal carousel ──────────────────────────────────
  Widget _goalsCarousel(BuildContext context, List<SavingGoal> goals) {
    void openGoals() => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SavingGoalsScreen()));

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _sectionHeader(context, 'Saving Goals',
                'See all ${goals.length} →', openGoals),
          ),
          if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _illustratedEmpty(
                context,
                icons: const [
                  Icons.home_rounded,
                  Icons.track_changes_rounded,
                  Icons.directions_car_rounded,
                  Icons.park_rounded,
                ],
                message: 'Create your first goal to track your savings',
                cta: 'Create Goal →',
                onTap: openGoals,
              ),
            )
          else
            SizedBox(
              height: 158,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: goals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _goalCard(context, goals[i], openGoals),
              ),
            ),
        ],
      ),
    );
  }

  Widget _goalCard(BuildContext context, SavingGoal g, VoidCallback onTap) {
    final frac =
        g.targetAmount > 0 ? (g.savedAmount / g.targetAmount).clamp(0.0, 1.0) : 0.0;
    final pct = (frac * 100).round();
    final color = g.color != null
        ? _colorFromHex(g.color)
        : _goalPalette[g.id % _goalPalette.length];
    final sym = _sym(g.currency);
    final deadline =
        g.targetDate != null ? _monthYear(g.targetDate!) : 'No date';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 156,
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Progress ring with the goal icon inside.
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: frac,
                        strokeWidth: 3.6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: TC.bg2(context),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                      Center(
                        child: Icon(iconForEmoji(g.icon ?? _goalEmoji(g.title)),
                            size: 17, color: color),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text('$pct%',
                    style: TC.gloock(context, fontSize: 17, color: color)),
              ],
            ),
            const Spacer(),
            Text(g.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TC.geist(context,
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(
                '$sym${AppCurrencyUtils.formatAmount(g.savedAmount, 0)} of $sym${AppCurrencyUtils.formatAmount(g.targetAmount, 0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TC.geist(context, fontSize: 10.5, color: TC.text3(context))),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.event_rounded, size: 10, color: TC.text3(context)),
              const SizedBox(width: 3),
              Text(deadline,
                  style: TC.geist(context,
                      fontSize: 10, color: TC.text3(context))),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── Subscriptions — next renewals ───────────────────────────────────────
  Widget _subsSection(BuildContext context, List<SubscriptionData> subs,
      MapEntry<String, double>? subsPrimary) {
    void openSubs() => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SubscriptionsScreen()));

    // Soonest active renewals first; paused ones only if nothing is active.
    final active = subs.where((s) => s.isActive).toList()
      ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    final preview = (active.isEmpty ? subs : active).take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text('Subscriptions',
                    style: TC.gloock(context, fontSize: 21, letterSpacing: -0.2)),
                if (subsPrimary != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: TC.primaryPale(context),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        '≈ ${_sym(subsPrimary.key)}${AppCurrencyUtils.formatAmount(subsPrimary.value, 0)}/mo',
                        style: TC.geist(context,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: TC.primary(context))),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    openSubs();
                  },
                  child: Text('See all ${subs.length} →',
                      style: TC.geist(context,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: TC.primaryMd(context))),
                ),
              ],
            ),
          ),
          if (preview.isEmpty)
            _illustratedEmpty(
              context,
              icons: const [
                Icons.tv_rounded,
                Icons.music_note_rounded,
                Icons.credit_card_rounded,
                Icons.cloud_rounded,
                Icons.sports_esports_rounded,
              ],
              title: 'Discover & Centralize',
              message: 'Manage all your subscriptions in one place',
              cta: 'Add Subscription',
              onTap: openSubs,
            )
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = s.nextBillingDate;
    final days =
        DateTime(next.year, next.month, next.day).difference(today).inDays;
    final renewLabel = days <= 0
        ? 'Renews today'
        : days == 1
            ? 'Renews tomorrow'
            : days <= 14
                ? 'Renews in $days days'
                : 'Renews ${DateFormat('MMM d').format(next)}';
    final urgent = days <= 3;

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
              child: Icon(iconForEmoji(s.emoji), size: 20, color: TC.primary(context)),
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
                  Text(renewLabel,
                      style: TC.geist(context,
                          fontSize: 11,
                          fontWeight: urgent ? FontWeight.w600 : FontWeight.w400,
                          color:
                              urgent ? TC.wn(context) : TC.text3(context))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${s.sym}${AppCurrencyUtils.formatAmount(s.amount, 2)}',
                style: TC.gloock(context, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  // ─── Shared atoms ────────────────────────────────────────────────────────
  /// Illustrated empty state: a row of muted icons (the middle one accented),
  /// optional title, message, and a primary CTA.
  Widget _illustratedEmpty(
    BuildContext context, {
    required List<IconData> icons,
    String? title,
    required String message,
    required String cta,
    required VoidCallback onTap,
  }) {
    final mid = icons.length ~/ 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: _cardDeco(context),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < icons.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Icon(
                  icons[i],
                  size: i == mid ? 42 : 30,
                  color: i == mid
                      ? TC.primary(context)
                      : TC.primary(context).withValues(alpha: 0.30),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (title != null) ...[
            Text(title,
                style:
                    TC.gloock(context, fontSize: 17, color: TC.text(context))),
            const SizedBox(height: 4),
          ],
          Text(message,
              textAlign: TextAlign.center,
              style: TC.geist(context,
                  fontSize: 13, color: TC.text2(context), height: 1.4)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              onTap();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                color: TC.primary(context),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: TC.primaryGlow(context),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Text(cta,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

}

