import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

class _SubscriptionsScreenState extends State<SubscriptionsScreen>
    with TickerProviderStateMixin {
  String _filter = 'All'; // All | monthly | weekly | yearly
  late AnimationController _headerCtrl;
  late AnimationController _listCtrl;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _listCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  List<SubscriptionData> _filtered(List<SubscriptionData> all) {
    if (_filter == 'All') return all;
    return all.where((s) => s.cycle == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>(); // for mutation calls only
    final all   = context.select<AppState, List<SubscriptionData>>((s) => s.subscriptions);
    final shown = _filtered(all);

    // Monthly totals per currency for header
    final monthlyCosts = state.subscriptionMonthlyCostByCurrency;
    final primaryCostEntry = monthlyCosts.entries.isEmpty
        ? null
        : monthlyCosts.entries.reduce(
            (a, b) => a.value >= b.value ? a : b);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: TC.card(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: TC.border(context)),
                      ),
                      alignment: Alignment.center,
                      child: Text('←',
                          style: TextStyle(fontSize: 18, color: TC.text(context))),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Subscriptions',
                        style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: TC.text(context),
                        )),
                  ),
                  // Add button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddSubscriptionScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.35),
                            blurRadius: 10, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Text('+',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18)),
                          SizedBox(width: 4),
                          Text('Add',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Hero cost header ─────────────────────────────────────────────
            FadeTransition(
              opacity: CurvedAnimation(
                  parent: _headerCtrl, curve: Curves.easeOut),
              child: _CostHeroCard(
                monthlyCosts: monthlyCosts,
                primaryEntry: primaryCostEntry,
                totalCount: all.length,
                activeCount: all.where((s) => s.isActive).length,
              ),
            ),

            const SizedBox(height: 16),

            // ── Filter chips ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'monthly', 'weekly', 'yearly'].map((f) {
                    final active = _filter == f;
                    final label  = f == 'monthly' ? 'Monthly'
                                 : f == 'weekly'  ? 'Weekly'
                                 : f == 'yearly'  ? 'Yearly' : 'All';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _filter = f);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: active ? AppColors.purple : TC.card(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active ? AppColors.purple : TC.border(context),
                              width: 1.5,
                            ),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: active ? Colors.white : TC.text2(context),
                              )),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: shown.isEmpty
                  ? _EmptySubsState(hasAny: all.isNotEmpty)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        return _SubscriptionCard(sub: shown[i])
                            .animate(delay: (i * 80).ms)
                            .slideY(begin: 0.2, curve: Curves.easeOutCubic, duration: 400.ms)
                            .fadeIn(curve: Curves.easeIn, duration: 400.ms);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero cost card ───────────────────────────────────────────────────────────

class _CostHeroCard extends StatefulWidget {
  final Map<String, double> monthlyCosts;
  final MapEntry<String, double>? primaryEntry;
  final int totalCount;
  final int activeCount;
  const _CostHeroCard({
    required this.monthlyCosts,
    required this.primaryEntry,
    required this.totalCount,
    required this.activeCount,
  });

  @override
  State<_CostHeroCard> createState() => _CostHeroCardState();
}

class _CostHeroCardState extends State<_CostHeroCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _countCtrl;
  late Animation<double> _countAnim;

  @override
  void initState() {
    super.initState();
    _countCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _countAnim = CurvedAnimation(
        parent: _countCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.primaryEntry;
    final cost  = entry?.value ?? 0.0;
    final sym   = entry != null
        ? (AppState.currencies.firstWhere((c) => c.code == entry.key,
                orElse: () => CurrencyData(entry.key, entry.key, '💰', entry.key))
            .sym)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.purple.withValues(alpha: 0.18),
              AppColors.blue.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('🔄',
                      style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL MONTHLY COST',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: TC.text3(context), letterSpacing: 1.5,
                        )),
                    Text('${widget.activeCount} active of ${widget.totalCount} subscriptions',
                        style: TextStyle(
                            fontSize: 11, color: TC.text2(context))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Count-up number
            AnimatedBuilder(
              animation: _countAnim,
              builder: (_, __) {
                final displayCost = cost * _countAnim.value;
                return RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: sym,
                        style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800,
                          color: AppColors.purple.withValues(alpha: 0.7),
                        ),
                      ),
                      TextSpan(
                        text: displayCost.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 44, fontWeight: FontWeight.w900,
                          color: AppColors.purple,
                        ),
                      ),
                      TextSpan(
                        text: ' /mo',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: TC.text2(context),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Per-currency breakdown if multiple
            if (widget.monthlyCosts.length > 1) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: widget.monthlyCosts.entries.map((e) {
                  final cur = AppState.currencies.firstWhere(
                    (c) => c.code == e.key,
                    orElse: () => CurrencyData(e.key, e.key, '💰', e.key),
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${cur.sym}${e.value.toStringAsFixed(2)} ${e.key}/mo',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: TC.text2(context)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Subscription card ────────────────────────────────────────────────────────

class _SubscriptionCard extends StatefulWidget {
  final SubscriptionData sub;
  const _SubscriptionCard({required this.sub});

  @override
  State<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<_SubscriptionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  Color get _accentColor {
    try {
      final hex = widget.sub.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.purple;
    }
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }

  void _showOptions() {
    HapticFeedback.mediumImpact();
    final sub = widget.sub;
    final springCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      transitionAnimationController: springCtrl,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: TC.border(context),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text(sub.name,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: TC.text(context))),
            Text('${sub.sym}${sub.amount.toStringAsFixed(2)} / ${sub.cycleLabel}',
                style: TextStyle(fontSize: 13, color: TC.text2(context))),
            const SizedBox(height: 12),
            ListTile(
              leading: Text(sub.isActive ? '⏸️' : '▶️',
                  style: const TextStyle(fontSize: 22)),
              title: Text(sub.isActive ? 'Pause subscription' : 'Resume subscription',
                  style: TextStyle(fontWeight: FontWeight.w600,
                      color: TC.text(context))),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                context.read<AppState>().toggleSubscriptionActive(sub).then((_) {
                  final updated = context
                      .read<AppState>()
                      .subscriptions
                      .firstWhere((s) => s.id == sub.id, orElse: () => sub);
                  if (updated.isActive) {
                    NotificationService.scheduleForSub(updated);
                  } else {
                    NotificationService.cancelForSub(sub.id);
                  }
                });
              },
            ),
            ListTile(
              leading: const Text('✏️', style: TextStyle(fontSize: 22)),
              title: Text('Edit subscription',
                  style: TextStyle(fontWeight: FontWeight.w600,
                      color: TC.text(context))),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddSubscriptionScreen(existing: sub),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Text('🗑', style: TextStyle(fontSize: 22)),
              title: const Text('Delete subscription',
                  style: TextStyle(fontWeight: FontWeight.w600,
                      color: AppColors.red)),
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
                _confirmDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.card(context),
        title: Text('Delete ${widget.sub.name}?',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: TC.text(context))),
        content: Text(
          'This will remove the subscription and cancel its reminders.',
          style: TextStyle(color: TC.text2(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: TC.text2(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              NotificationService.cancelForSub(widget.sub.id);
              context.read<AppState>().deleteSubscription(widget.sub);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub       = widget.sub;
    final accent    = _accentColor;
    final nextDate  = sub.nextBillingDate;
    final days      = sub.daysUntilBilling;
    final dueSoon   = sub.isDueSoon;
    final progress  = sub.cycleProgress;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp:   (_) { setState(() => _pressing = false); _showOptions(); },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedScale(
        scale: _pressing ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: sub.isActive ? 1.0 : 0.55,
          duration: const Duration(milliseconds: 200),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: dueSoon && sub.isActive
                    ? AppColors.amber.withValues(alpha: 0.5)
                    : TC.border(context),
                width: dueSoon && sub.isActive ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.18 : 0.05),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: emoji/name + badge ──────────────────────────────
                Row(
                  children: [
                    // Emoji in colored circle
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.25)),
                      ),
                      alignment: Alignment.center,
                      child: Text(sub.emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sub.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16,
                                color: TC.text(context),
                              )),
                          Row(
                            children: [
                              _CatBadge(label: sub.category, color: accent),
                              const SizedBox(width: 6),
                              if (!sub.isActive)
                                _CatBadge(
                                    label: 'Paused',
                                    color: TC.text3(context)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Due soon badge
                    if (dueSoon && sub.isActive)
                      _DueSoonBadge(days: days),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Animated progress bar ──────────────────────────────────
                AnimatedBuilder(
                  animation: _progressCtrl,
                  builder: (_, __) {
                    final barVal = _progressCtrl.value * progress;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: barVal,
                            backgroundColor: TC.border(context),
                            valueColor: AlwaysStoppedAnimation(accent),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              days == 0
                                  ? 'Billing today!'
                                  : '$days day${days == 1 ? '' : 's'} until billing',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: dueSoon ? AppColors.amber : TC.text2(context),
                              ),
                            ),
                            Text(
                              'Next: ${_fmtDate(nextDate)}',
                              style: TextStyle(
                                  fontSize: 12, color: TC.text2(context)),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 10),
                Divider(color: TC.border(context), height: 1),
                const SizedBox(height: 10),

                // ── Row 3: amount + cycle ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${sub.sym}${sub.amount.toStringAsFixed(2)} / ${sub.cycleLabel}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17,
                        color: accent,
                      ),
                    ),
                    Text(
                      '≈ ${sub.sym}${sub.monthlyEquivalent.toStringAsFixed(2)}/mo',
                      style: TextStyle(
                        fontSize: 12, color: TC.text2(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Due-soon pulsing badge ───────────────────────────────────────────────────

class _DueSoonBadge extends StatefulWidget {
  final int days;
  const _DueSoonBadge({required this.days});
  @override
  State<_DueSoonBadge> createState() => _DueSoonBadgeState();
}

class _DueSoonBadgeState extends State<_DueSoonBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final label = widget.days == 0 ? 'Due today!'
                : widget.days == 1 ? 'Due tomorrow'
                : 'Due soon';
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.amber
              .withValues(alpha: 0.12 + _pulse.value * 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.amber
                  .withValues(alpha: 0.4 + _pulse.value * 0.3)),
        ),
        child: Text(
          '⚠️ $label',
          style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800,
            color: AppColors.amber,
          ),
        ),
      ),
    );
  }
}

// ─── Category badge ───────────────────────────────────────────────────────────

class _CatBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _CatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: color)),
  );
}

// ─── Animated empty state ─────────────────────────────────────────────────────

class _EmptySubsState extends StatefulWidget {
  final bool hasAny;
  const _EmptySubsState({required this.hasAny});
  @override
  State<_EmptySubsState> createState() => _EmptySubsStateState();
}

class _EmptySubsStateState extends State<_EmptySubsState>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbit;
  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
  }
  @override
  void dispose() { _orbit.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final title    = widget.hasAny
        ? 'No subs in this filter'
        : 'No subscriptions yet';
    final subtitle = widget.hasAny
        ? 'Try a different cycle filter'
        : 'Tap + Add to track Netflix, Spotify…';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 110, height: 110,
            child: AnimatedBuilder(
              animation: _orbit,
              builder: (_, __) {
                final bob = math.sin(_orbit.value * math.pi * 2) * 6;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, bob),
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.purple.withValues(alpha: 0.25),
                              width: 2),
                        ),
                        alignment: Alignment.center,
                        child: const Text('🔄',
                            style: TextStyle(fontSize: 34)),
                      ),
                    ),
                    for (int i = 0; i < 3; i++)
                      _orbitDot(i),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: TC.text(context))),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(fontSize: 13, color: TC.text2(context))),
        ],
      ),
    );
  }

  Widget _orbitDot(int i) {
    final colors = [AppColors.purple, AppColors.blue, AppColors.green];
    final angle  = _orbit.value * math.pi * 2 + (i * math.pi * 2 / 3);
    final x      = math.cos(angle) * 48;
    final y      = math.sin(angle) * 48;
    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
          width: 8, height: 8,
          decoration:
              BoxDecoration(color: colors[i], shape: BoxShape.circle)),
    );
  }
}
