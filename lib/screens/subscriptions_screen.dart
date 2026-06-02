import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';
import '../utils/app_utils.dart';
import 'add_subscription_screen.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  String _catFilter = 'All';

  String _sym(String code) => AppState.currencies
      .firstWhere((c) => c.code == code,
          orElse: () => CurrencyData(code, code, '💰', code))
      .sym;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = state.subscriptions;

    // Monthly totals per currency → dominant currency drives the hero & chart.
    final monthlyCosts = state.subscriptionMonthlyCostByCurrency;
    String? domCur;
    double domTotal = 0;
    monthlyCosts.forEach((cur, sum) {
      if (sum >= domTotal) { domTotal = sum; domCur = cur; }
    });
    final sym = domCur != null ? _sym(domCur!) : '';
    final activeCount = all.where((s) => s.isActive).length;
    final domSubs = domCur != null ? all.where((s) => s.currency == domCur).toList() : <SubscriptionData>[];

    // Category breakdown (dominant currency, monthly-equivalent).
    final catTotals = <String, double>{};
    for (final s in domSubs) {
      catTotals[s.category] = (catTotals[s.category] ?? 0) + s.monthlyEquivalent;
    }
    final sortedCats = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final cats = <String>['All', ...{for (final s in all) s.category}];
    final shown = _catFilter == 'All' ? all : all.where((s) => s.category == _catFilter).toList();
    final pausedCount = all.where((s) => !s.isActive).length;

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        bottom: false,
        child: all.isEmpty
            ? Column(children: [_header(context), const Expanded(child: _EmptySubsState())])
            : ListView(
                padding: const EdgeInsets.only(bottom: 32),
                physics: const BouncingScrollPhysics(),
                children: [
                  _header(context),
                  _summaryHero(context, sym, domTotal, activeCount)
                      .animate().fadeIn(duration: 360.ms).slideY(begin: 0.1, curve: Curves.easeOut),
                  if (sortedCats.isNotEmpty)
                    _categoryBreakdown(context, sym, domTotal, sortedCats)
                        .animate().fadeIn(delay: 80.ms, duration: 440.ms),
                  _filterChips(context, cats),
                  ...List.generate(shown.length, (i) {
                    return _subCard(context, state, shown[i])
                        .animate(delay: (i * 50).ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.12, curve: Curves.easeOutCubic);
                  }),
                  if (pausedCount > 0) _insightBanner(context, pausedCount).animate().fadeIn(delay: 120.ms),
                ],
              ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: TC.bg2(context), borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: Text('←', style: TextStyle(fontSize: 16, color: TC.text(context))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MONTHLY COMMITMENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: TC.primaryMd(context))),
                const SizedBox(height: 3),
                Text('Subscriptions', style: TC.gloock(context, fontSize: 24, color: TC.text(context), letterSpacing: -0.3)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: TC.primary(context),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [BoxShadow(color: TC.primaryGlow(context), blurRadius: 16, offset: const Offset(0, 5))],
              ),
              child: const Text('+ Add', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Summary hero ─────────────────────────────────────────────────────────
  Widget _summaryHero(BuildContext context, String sym, double total, int activeCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: TC.primaryPale(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: TC.primary(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: TC.primaryGlow(context), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                alignment: Alignment.center,
                child: const Text('💳', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL MONTHLY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: TC.text3(context))),
                    const SizedBox(height: 3),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: '$sym${total.toStringAsFixed(2)}', style: TC.gloock(context, fontSize: 30, color: TC.text(context), letterSpacing: -1)),
                          TextSpan(text: '/mo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: TC.text3(context))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(color: TC.surface(context), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _heroStat(context, 'Per Year', '$sym${(total * 12).toStringAsFixed(0)}'),
                _heroDivider(context),
                _heroStat(context, 'Active', '$activeCount'),
                _heroDivider(context),
                _heroStat(context, 'Per Day', '$sym${(total / 30).toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(BuildContext context, String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: TC.text3(context))),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TC.gloock(context, fontSize: 15, color: TC.text(context))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroDivider(BuildContext context) => Container(width: 1, height: 38, color: TC.border(context));

  // ─── Category breakdown ─────────────────────────────────────────────────────
  Widget _categoryBreakdown(BuildContext context, String sym, double total, List<MapEntry<String, double>> cats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TC.surface(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1))],
        border: isDark ? Border.all(color: TC.border(context)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by Category', style: TC.gloock(context, fontSize: 16, color: TC.text(context))),
          const SizedBox(height: 10),
          ...List.generate(cats.length, (i) {
            final e = cats[i];
            final pct = total > 0 ? ((e.value / total) * 100).round() : 0;
            return Padding(
              padding: EdgeInsets.only(bottom: i < cats.length - 1 ? 10 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: TC.text(context))),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: '$sym${e.value.toStringAsFixed(2)} ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TC.text(context))),
                            TextSpan(text: '($pct%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: TC.text3(context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 4,
                      backgroundColor: TC.bg2(context),
                      valueColor: AlwaysStoppedAnimation(TC.primary(context)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Filter chips ─────────────────────────────────────────────────────────
  Widget _filterChips(BuildContext context, List<String> cats) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: cats.map((c) {
            final active = _catFilter == c;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); setState(() => _catFilter = c); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? TC.primary(context) : TC.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? TC.primary(context) : TC.border(context)),
                  ),
                  child: Text(c, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : TC.text2(context))),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Subscription card ──────────────────────────────────────────────────────
  Widget _subCard(BuildContext context, AppState state, SubscriptionData s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renews = DateFormat('MMM d').format(s.nextBillingDate);
    return GestureDetector(
      onTap: () => _showOptions(context, state, s),
      child: AnimatedOpacity(
        opacity: s.isActive ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: TC.surface(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1))],
            border: isDark ? Border.all(color: TC.border(context)) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: TC.bg2(context), borderRadius: BorderRadius.circular(15)),
                alignment: Alignment.center,
                child: Text(s.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TC.text(context)))),
                        if (!s.isActive) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: TC.wnPale(context), borderRadius: BorderRadius.circular(20)),
                            child: Text('PAUSED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: TC.wn(context))),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('${s.category} · ${_cycleName(s.cycle)}', style: TextStyle(fontSize: 11, color: TC.text3(context))),
                    const SizedBox(height: 4),
                    Text('Renews $renews', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: TC.wn(context))),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${s.sym}${s.amount.toStringAsFixed(2)}', style: TC.gloock(context, fontSize: 18, color: TC.text(context), letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: s.isActive ? TC.okPale(context) : TC.bg2(context), borderRadius: BorderRadius.circular(20)),
                    child: Text(s.isActive ? 'active' : 'paused', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: s.isActive ? TC.ok(context) : TC.text3(context))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cycleName(String cycle) {
    switch (cycle) {
      case BillingCycle.weekly: return 'Weekly';
      case BillingCycle.yearly: return 'Yearly';
      default: return 'Monthly';
    }
  }

  // ─── Insight banner ───────────────────────────────────────────────────────
  Widget _insightBanner(BuildContext context, int pausedCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(color: TC.wnPale(context), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$pausedCount paused subscription${pausedCount > 1 ? 's' : ''}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TC.wn(context))),
                const SizedBox(height: 2),
                Text('Resume or remove them to keep your list tidy.', style: TextStyle(fontSize: 11, color: TC.text2(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Options sheet (pause / edit / delete) ──────────────────────────────────
  void _showOptions(BuildContext context, AppState state, SubscriptionData sub) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(sub.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: TC.text(context))),
            Text('${sub.sym}${sub.amount.toStringAsFixed(2)} / ${sub.cycleLabel}', style: TextStyle(fontSize: 13, color: TC.text2(context))),
            const SizedBox(height: 12),
            ListTile(
              leading: Text(sub.isActive ? '⏸️' : '▶️', style: const TextStyle(fontSize: 22)),
              title: Text(sub.isActive ? 'Pause subscription' : 'Resume subscription', style: TextStyle(fontWeight: FontWeight.w600, color: TC.text(context))),
              onTap: () async {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                final appState = context.read<AppState>();
                await appState.toggleSubscriptionActive(sub);
                if (!mounted) return;
                final updated = appState.subscriptions.firstWhere((s) => s.id == sub.id, orElse: () => sub);
                if (updated.isActive) {
                  NotificationService.scheduleForSub(updated);
                } else {
                  NotificationService.cancelForSub(sub.id);
                }
              },
            ),
            ListTile(
              leading: const Text('✏️', style: TextStyle(fontSize: 22)),
              title: Text('Edit subscription', style: TextStyle(fontWeight: FontWeight.w600, color: TC.text(context))),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddSubscriptionScreen(existing: sub)));
              },
            ),
            ListTile(
              leading: const Text('🗑', style: TextStyle(fontSize: 22)),
              title: const Text('Delete subscription', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.red)),
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
                _confirmDelete(context, state, sub);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState state, SubscriptionData sub) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.card(context),
        title: Text('Delete ${sub.name}?', style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
        content: Text('This will remove the subscription and cancel its reminders.', style: TextStyle(color: TC.text2(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: TC.text2(context)))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              NotificationService.cancelForSub(sub.id);
              state.deleteSubscription(sub);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ────────────────────────────────────────────────────────────
class _EmptySubsState extends StatelessWidget {
  const _EmptySubsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: TC.primaryPale(context),
              shape: BoxShape.circle,
              border: Border.all(color: TC.primary(context).withValues(alpha: 0.25), width: 2),
            ),
            alignment: Alignment.center,
            child: const Text('💳', style: TextStyle(fontSize: 34)),
          ),
          const SizedBox(height: 20),
          Text('No subscriptions yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: TC.text(context))),
          const SizedBox(height: 6),
          Text('Tap + Add to track Netflix, Spotify…', style: TextStyle(fontSize: 13, color: TC.text2(context))),
        ],
      ),
    );
  }
}
