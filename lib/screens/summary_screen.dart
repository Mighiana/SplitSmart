import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../widgets/common_widgets.dart';

/// Full spending analytics / summary screen.
/// Reached via the Groups detail screen → "Summary" or directly.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _month;
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _prevMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
      _animCtrl.forward(from: 0);
    });
  }

  void _nextMonth() {
    if (_isCurrentMonth) return;
    HapticFeedback.lightImpact();
    setState(() {
      _month = DateTime(_month.year, _month.month + 1, 1);
      _animCtrl.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final transactions = context.select<AppState, List<TransactionData>>((s) => s.transactions);
    final txns = transactions.where((t) {
      final d = t.rawDate;
      return d != null && d.year == _month.year && d.month == _month.month;
    }).toList();

    final totalIncome  = txns.where((t) => t.type == 'income') .fold(0.0, (s, t) => s + t.amount);
    final totalExpense = txns.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
    final netBalance   = totalIncome - totalExpense;

    // Category breakdown (expenses only)
    final Map<String, double> catTotals = {};
    for (final t in txns.where((t) => t.type == 'expense')) {
      catTotals[t.cat] = (catTotals[t.cat] ?? 0) + t.amount;
    }
    final sorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Currency breakdown
    final Map<String, double> currencyExpense = {};
    for (final t in txns.where((t) => t.type == 'expense')) {
      currencyExpense[t.currency] = (currencyExpense[t.currency] ?? 0) + t.amount;
    }

    // Day-of-week breakdown
    final List<double> dayTotals = List.filled(7, 0);
    for (final t in txns.where((t) => t.type == 'expense')) {
      final d = t.rawDate;
      if (d != null) dayTotals[d.weekday % 7] += t.amount;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: TC.card(context), shape: BoxShape.circle,
                            border: Border.all(color: TC.border(context)),
                          ),
                          alignment: Alignment.center,
                          child: Text('←',
                              style: TextStyle(fontSize: 18, color: TC.text(context))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l.spendingAnalytics,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                                color: TC.text(context))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Month selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: TC.card(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TC.border(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _prevMonth,
                          child: Container(
                            width: 44, height: 44,
                            alignment: Alignment.center,
                            child: Text('‹',
                                style: TextStyle(fontSize: 24, color: TC.text(context), fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Column(
                          children: [
                            Text(AppDateUtils.monthLabel(_month, l.locale.languageCode),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            if (_isCurrentMonth)
                              Text(l.currentMonth,
                                  style: const TextStyle(fontSize: 10, color: AppColors.green)),
                          ],
                        ),
                        GestureDetector(
                          onTap: _nextMonth,
                          child: Container(
                            width: 44, height: 44,
                            alignment: Alignment.center,
                            child: Text('›',
                                style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w700,
                                  color: _isCurrentMonth ? TC.text3(context) : TC.text(context),
                                )),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          if (txns.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyState(
                  icon: '📊',
                  title: '${l.noDataFor} ${AppDateUtils.monthLabel(_month, l.locale.languageCode)}',
                  subtitle: l.addTransactionsSummary,
                ),
              ),
            )
          else ...[
            // ─── Overview Cards ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Big balance card
                    AnimatedBuilder(
                      animation: _anim,
                      builder: (_, __) => Opacity(
                        opacity: _anim.value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - _anim.value)),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: netBalance >= 0
                                    ? [const Color(0x2200D68F), const Color(0x0800D68F)]
                                    : [const Color(0x22FF4D6D), const Color(0x08FF4D6D)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: netBalance >= 0
                                    ? AppColors.green.withValues(alpha: 0.25)
                                    : AppColors.red.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  netBalance >= 0 ? l.positiveMonth : l.overspending,
                                  style: const TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${netBalance >= 0 ? '+' : ''}${netBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 42, fontWeight: FontWeight.w900,
                                    color: netBalance >= 0 ? AppColors.green : AppColors.red,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${l.netBalanceFor} ${AppDateUtils.monthLabel(_month, l.locale.languageCode)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.text3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Income / Expense row
                    Row(children: [
                      Expanded(child: _OverviewTile(
                        label: l.totalIncome, value: totalIncome,
                        color: AppColors.green, icon: '💚',
                        anim: _anim,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _OverviewTile(
                        label: l.totalSpent, value: totalExpense,
                        color: AppColors.red, icon: '💸',
                        anim: _anim,
                      )),
                    ]),
                    const SizedBox(height: 14),

                    // Savings rate
                    if (totalIncome > 0) ...[
                      _SavingsRateTile(
                          income: totalIncome, expense: totalExpense, anim: _anim),
                      const SizedBox(height: 20),
                    ],

                    // ─── Day of Week Bar Chart ────────────────────────────
                    _SectionHeader(l.spendByDay),
                    const SizedBox(height: 12),
                    _DayBarChart(dayTotals: dayTotals, anim: _anim, locale: l.locale.languageCode),
                    const SizedBox(height: 20),

                    // ─── Category breakdown ───────────────────────────────
                    if (sorted.isNotEmpty) ...[
                      _SectionHeader(l.catBreakdown),
                      const SizedBox(height: 12),
                      ...sorted.asMap().entries.map((entry) {
                        final i   = entry.key;
                        final cat = entry.value;
                        final pct = totalExpense > 0 ? cat.value / totalExpense : 0.0;
                        // Look up category label
                        final catData = AppState.expenseCategories
                            .where((c) => c.icon == cat.key)
                            .toList();
                        final label = catData.isNotEmpty ? catData.first.label : cat.key;
                        final colorHex = catData.isNotEmpty ? catData.first.color : '#4d9eff';
                        final barColor = _hexColor(colorHex);

                        return AnimatedBuilder(
                          animation: _anim,
                          builder: (_, __) {
                            final delay = (i * 0.1).clamp(0.0, 0.6);
                            final t = (((_anim.value - delay) / (1 - delay)).clamp(0.0, 1.0));
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(30 * (1 - t), 0),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: TC.card(context),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: TC.border(context)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(children: [
                                        Text(cat.key, style: const TextStyle(fontSize: 22)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(label,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600, fontSize: 14,
                                                  color: TC.text(context))),
                                        ),
                                        Text(
                                          '${(pct * 100).toStringAsFixed(1)}%',
                                          style: TextStyle(
                                              fontSize: 11, color: barColor, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          cat.value.toStringAsFixed(2),
                                          style: TextStyle(
                                              fontSize: 14, fontWeight: FontWeight.w800,
                                              color: TC.text(context)),
                                        ),
                                      ]),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct * t,
                                          backgroundColor: TC.border(context),
                                          valueColor: AlwaysStoppedAnimation(barColor),
                                          minHeight: 7,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                      const SizedBox(height: 20),
                    ],

                    // ─── Top Insights ─────────────────────────────────────
                    if (sorted.isNotEmpty) ...[
                      _SectionHeader(l.insights),
                      const SizedBox(height: 12),
                      _InsightCard(
                        icon: '🏆',
                        title: l.biggestCat,
                        value: '${sorted.first.key} — ${sorted.first.value.toStringAsFixed(2)}',
                        color: AppColors.amber,
                      ),
                      const SizedBox(height: 8),
                      _InsightCard(
                        icon: '📆',
                        title: l.transThisMonth,
                        value: '${txns.length} ${l.recorded}',
                        color: AppColors.blue,
                      ),
                      if (totalIncome > 0 && totalExpense > totalIncome) ...[
                        const SizedBox(height: 8),
                        _InsightCard(
                          icon: '⚠️',
                          title: l.overspendingAlert,
                          value: '${((totalExpense / totalIncome - 1) * 100).toStringAsFixed(0)}% more than earned',
                          color: AppColors.red,
                        ),
                      ],
                      if (totalIncome > 0 && totalExpense <= totalIncome * 0.5) ...[
                        const SizedBox(height: 8),
                        _InsightCard(
                          icon: '🌟',
                          title: '🌟 Great savings!',
                          value: 'Saving ${((1 - totalExpense / totalIncome) * 100).toStringAsFixed(0)}% of income this month',
                          color: AppColors.green,
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.blue;
    }
  }
}

// ─── Section Header Helper ────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title.toUpperCase(),
        style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: TC.text3(context), letterSpacing: 2,
        ));
  }
}

// ─── Overview Tile ────────────────────────────────────────────────────────────
class _OverviewTile extends StatelessWidget {
  final String label, icon;
  final double value;
  final Color color;
  final Animation<double> anim;
  const _OverviewTile({
    required this.label, required this.value,
    required this.color, required this.icon, required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 8),
              Text(value.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: color,
                  )),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 11, color: TC.text2(context))),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Savings Rate Tile ────────────────────────────────────────────────────────
class _SavingsRateTile extends StatelessWidget {
  final double income, expense;
  final Animation<double> anim;
  const _SavingsRateTile({
    required this.income, required this.expense, required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rate = ((income - expense) / income).clamp(0.0, 1.0);
    final pct  = (rate * 100).toStringAsFixed(0);
    final color = rate > 0.3 ? AppColors.green : rate > 0 ? AppColors.amber : AppColors.red;

    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TC.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.savingsRate,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: TC.text3(context), letterSpacing: 2)),
                  Text('$pct%',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rate * anim.value,
                  backgroundColor: TC.border(context),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                rate > 0.3
                    ? l.excellentSavings
                    : rate > 0.1
                        ? l.onTrack
                        : rate > 0
                            ? l.lowSavings
                            : l.spendingExceedsIncome,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Day-of-Week Bar Chart ────────────────────────────────────────────────────
class _DayBarChart extends StatelessWidget {
  final List<double> dayTotals; // length 7: Sun=0 … Sat=6
  final Animation<double> anim;
  final String locale;
  const _DayBarChart({required this.dayTotals, required this.anim, required this.locale});

  @override
  Widget build(BuildContext context) {
    final maxVal = dayTotals.reduce((a, b) => a > b ? a : b);
    // Generate short day names for Sun(0)..Sat(6) using intl
    final dayNames = List.generate(7, (i) {
      // Create a known Sunday (2024-01-07) and offset by i
      final d = DateTime(2024, 1, 7 + i);
      return DateFormat.E(locale).format(d);
    });


    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TC.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TC.border(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final val  = dayTotals[i];
            final pct  = maxVal > 0 ? val / maxVal : 0.0;
            final isToday = i == DateTime.now().weekday % 7;
            final barColor = isToday ? AppColors.green : AppColors.blue;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            height: (80 * pct * anim.value).clamp(2.0, 80.0),
                            decoration: BoxDecoration(
                              color: barColor.withValues(alpha: isToday ? 1.0 : 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(dayNames[i],
                        style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: isToday ? AppColors.green : TC.text3(context),
                        )),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Insight Card ─────────────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final String icon, title, value;
  final Color color;
  const _InsightCard({
    required this.icon, required this.title,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 12, color: TC.text2(context))),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ]),
    );
  }
}
