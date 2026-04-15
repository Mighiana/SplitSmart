import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../main.dart';
import '../widgets/common_widgets.dart';

// ─── Premium Chart Screen ─────────────────────────────────────────────────────
class MoneyChartsScreen extends StatefulWidget {
  final String? initialCurrency;
  const MoneyChartsScreen({super.key, this.initialCurrency});

  @override
  State<MoneyChartsScreen> createState() => _MoneyChartsScreenState();
}

class _MoneyChartsScreenState extends State<MoneyChartsScreen>
    with SingleTickerProviderStateMixin {
  bool _showIncome = false; // false = expenses, true = income
  String? _currency;
  int _touchedDonutIndex = -1;
  late AnimationController _donutCtrl;
  late Animation<double> _donutAnim;

  @override
  void initState() {
    super.initState();
    _donutCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _donutAnim = CurvedAnimation(parent: _donutCtrl, curve: Curves.easeOutCubic);
    _donutCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (widget.initialCurrency != null && widget.initialCurrency != 'ALL') {
        setState(() => _currency = widget.initialCurrency);
      } else if (state.wallets.isNotEmpty) {
        setState(() => _currency = state.wallets.keys.first);
      } else if (state.transactions.isNotEmpty) {
        setState(() => _currency = state.transactions.first.currency);
      } else {
        setState(() => _currency = 'EUR');
      }
    });
  }

  @override
  void dispose() {
    _donutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    if (_currency == null) {
      return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor);
    }

    final curData = AppState.currencies.firstWhere(
        (c) => c.code == _currency,
        orElse: () => const CurrencyData('USD', 'US Dollar', '🇺🇸', '\$'));
    final sym = curData.sym;

    final now = DateTime.now();
    final months = <DateTime>[];
    for (int i = 5; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i, 1));
    }

    final typeStr = _showIncome ? 'income' : 'expense';
    final primaryColor =
        _showIncome ? const Color(0xFF00D68F) : const Color(0xFFFF4D6D);
    final gradientStart =
        _showIncome ? const Color(0xFF00D68F) : const Color(0xFFFF6B8A);
    final gradientEnd =
        _showIncome ? const Color(0xFF00B377) : const Color(0xFFD90429);

    // ── Monthly data ──────────────────────────────────────────────────────────
    final actuals = <double>[];
    double totalActual = 0;
    double currentMonthActual = 0;
    double previousMonthActual = 0;

    final allTxns = state.allTransactionsWithGroupShares;
    for (int i = 0; i < months.length; i++) {
      final m = months[i];
      final val = allTxns
          .where((t) {
            final dt = t.rawDate;
            return dt != null &&
                t.type == typeStr &&
                t.currency == _currency &&
                dt.year == m.year &&
                dt.month == m.month;
          })
          .fold(0.0, (s, t) => s + t.amount);
      actuals.add(val);
      totalActual += val;
      if (i == 5) currentMonthActual = val;
      if (i == 4) previousMonthActual = val;
    }

    // ── Category breakdown ────────────────────────────────────────────────────
    final periodTxns = allTxns.where((t) {
      final dt = t.rawDate;
      return dt != null &&
          t.type == typeStr &&
          t.currency == _currency &&
          dt.year == now.year &&
          dt.month == now.month;
    }).toList();

    final Map<String, double> catTotals = {};
    for (final t in periodTxns) {
      catTotals[t.cat] = (catTotals[t.cat] ?? 0) + t.amount;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Budget
    final budgetKey = _showIncome ? 'all_income' : 'all';
    final monthlyBudget = state.getBudgetLimit(budgetKey, _currency!);
    final pct = monthlyBudget > 0
        ? (currentMonthActual / monthlyBudget * 100)
        : 0.0;

    // Change %
    final changePct = previousMonthActual > 0
        ? ((currentMonthActual - previousMonthActual) / previousMonthActual * 100)
        : 0.0;
    final isUp = changePct >= 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Gradient Header ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1a1a2e), const Color(0xFF0c0c0e)]
                      : [const Color(0xFFf0f4f8), const Color(0xFFe8ecf4)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // ── Nav bar ──────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                            icon: Icon(Icons.arrow_back_ios_new,
                                color: TC.text(context), size: 20),
                          ),
                          Expanded(
                            child: Text('Financial Overview',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: TC.text(context),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                          ),
                          PopupMenuButton<String>(
                            icon: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: TC.card(context),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: TC.border(context)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(curData.flag,
                                      style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 4),
                                  Text(_currency!,
                                      style: TextStyle(
                                          color: TC.text(context),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                  Icon(Icons.keyboard_arrow_down,
                                      color: TC.text3(context), size: 16),
                                ],
                              ),
                            ),
                            color: TC.card(context),
                            onSelected: (val) {
                              setState(() => _currency = val);
                              _donutCtrl.reset();
                              _donutCtrl.forward();
                            },
                            itemBuilder: (_) {
                              final available = <String>{};
                              available.addAll(state.wallets.keys);
                              for (final g in state.activeGroups) {
                                available.add(g.currency);
                              }
                              for (final t in state.allTransactionsWithGroupShares) {
                                available.add(t.currency);
                              }
                              return available
                                  .map((c) {
                                    final cd = AppState.currencies.firstWhere(
                                        (x) => x.code == c,
                                        orElse: () =>
                                            CurrencyData(c, c, '💱', c));
                                    return PopupMenuItem(
                                      value: c,
                                      child: Text('${cd.flag} ${cd.code}',
                                          style: TextStyle(
                                              color: TC.text(context))),
                                    );
                                  })
                                  .toList();
                            },
                          ),
                        ],
                      ),
                    ),

                    // ── Toggle pill ──────────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: TC.card(context),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: TC.border(context)),
                      ),
                      child: Row(
                        children: [
                          _TogglePill(
                            label: 'Expenses',
                            active: !_showIncome,
                            color: const Color(0xFFFF4D6D),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _showIncome = false);
                              _donutCtrl.reset();
                              _donutCtrl.forward();
                            },
                          ),
                          _TogglePill(
                            label: 'Income',
                            active: _showIncome,
                            color: const Color(0xFF00D68F),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _showIncome = true);
                              _donutCtrl.reset();
                              _donutCtrl.forward();
                            },
                          ),
                        ],
                      ),
                    ),

                    // ── Hero metric ──────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                      child: Column(
                        children: [
                          Text(
                            _showIncome
                                ? 'Total Income This Month'
                                : 'Total Spent This Month',
                            style: TextStyle(
                                fontSize: 13, color: TC.text2(context)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$sym${AppCurrencyUtils.formatAmount(currentMonthActual, 0)}',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: TC.text(context),
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (isUp
                                      ? (_showIncome
                                          ? AppColors.green
                                          : AppColors.red)
                                      : (_showIncome
                                          ? AppColors.red
                                          : AppColors.green))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isUp
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 14,
                                  color: isUp
                                      ? (_showIncome
                                          ? AppColors.green
                                          : AppColors.red)
                                      : (_showIncome
                                          ? AppColors.red
                                          : AppColors.green),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${changePct.abs().toStringAsFixed(1)}% vs last month',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isUp
                                        ? (_showIncome
                                            ? AppColors.green
                                            : AppColors.red)
                                        : (_showIncome
                                            ? AppColors.red
                                            : AppColors.green),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 400.ms).slideY(begin: 0.05),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stat cards row ──────────────────────────────────────────────
                  Row(
                    children: [
                      _StatCard(
                        label: 'Previous Month',
                        value: '$sym${AppCurrencyUtils.formatAmount(previousMonthActual, 0)}',
                        icon: Icons.calendar_month,
                        color: const Color(0xFF4D9EFF),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: monthlyBudget > 0
                            ? 'Budget Used'
                            : '6-Mo Average',
                        value: monthlyBudget > 0
                            ? '${pct.toStringAsFixed(0)}%'
                            : '$sym${AppCurrencyUtils.formatAmount(totalActual / 6, 0)}',
                        icon: monthlyBudget > 0
                            ? Icons.speed
                            : Icons.analytics_outlined,
                        color: monthlyBudget > 0
                            ? (pct > 90
                                ? AppColors.red
                                : (pct > 70
                                    ? AppColors.amber
                                    : AppColors.green))
                            : AppColors.purple,
                        isDark: isDark,
                      ),
                    ],
                  )
                      .animate()
                      .fade(delay: 150.ms, duration: 400.ms)
                      .slideY(begin: 0.05),

                  const SizedBox(height: 20),

                  // ── Trend Chart ────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: TC.card(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: TC.border(context)),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.show_chart,
                                  color: primaryColor, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('6-Month Trend',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: TC.text(context))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 200,
                          child: _GradientAreaChart(
                            months: months,
                            values: actuals,
                            primaryColor: primaryColor,
                            gradientStart: gradientStart,
                            gradientEnd: gradientEnd,
                            isDark: isDark,
                            context: context,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fade(delay: 250.ms, duration: 500.ms)
                      .slideY(begin: 0.08),

                  const SizedBox(height: 20),

                  // ── Donut Breakdown ────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: TC.card(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: TC.border(context)),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.donut_large,
                                  color: primaryColor, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('Category Breakdown',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: TC.text(context))),
                            ),
                            Text('This Month',
                                style: TextStyle(
                                    fontSize: 11, color: TC.text3(context))),
                          ],
                        ),
                        const SizedBox(height: 24),
                        AnimatedBuilder(
                          animation: _donutAnim,
                          builder: (_, __) {
                            return SizedBox(
                              width: 180,
                              height: 180,
                              child: CustomPaint(
                                painter: _AnimatedDonutPainter(
                                  slices: sortedCats
                                      .map((e) => _DonutSlice(
                                            value: currentMonthActual > 0
                                                ? e.value / currentMonthActual
                                                : 0,
                                            color: _getCatColor(e.key),
                                          ))
                                      .toList(),
                                  progress: _donutAnim.value,
                                  ringColor: TC.border(context),
                                  bgColor: TC.card(context),
                                  touchedIndex: _touchedDonutIndex,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Category legend
                        ...sortedCats.asMap().entries.map((entry) {
                          final i = entry.key;
                          final cat = entry.value;
                          final catPct = currentMonthActual > 0
                              ? (cat.value / currentMonthActual * 100)
                              : 0.0;
                          final color = _getCatColor(cat.key);
                          final catInfo =
                              AppState.expenseCategories.firstWhere(
                            (c) => c.icon == cat.key,
                            orElse: () =>
                                AppState.incomeCategories.firstWhere(
                              (c) => c.icon == cat.key,
                              orElse: () =>
                                  const CategoryItem('?', 'Other', '#9999aa'),
                            ),
                          );

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _touchedDonutIndex =
                                    _touchedDonutIndex == i ? -1 : i;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: _touchedDonutIndex == i
                                    ? color.withValues(alpha: isDark ? 0.15 : 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _touchedDonutIndex == i
                                      ? color.withValues(alpha: 0.4)
                                      : TC.border(context),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(cat.key,
                                        style: const TextStyle(fontSize: 16)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(catInfo.label,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: TC.text(context))),
                                        const SizedBox(height: 3),
                                        // Mini progress bar
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value:
                                                (catPct / 100).clamp(0.0, 1.0),
                                            backgroundColor: TC.border(context),
                                            valueColor:
                                                AlwaysStoppedAnimation(color),
                                            minHeight: 4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${catPct.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: color),
                                      ),
                                      Text(
                                        '$sym${AppCurrencyUtils.formatAmount(cat.value, 0)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: TC.text2(context)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                              .animate(delay: (i * 60).ms)
                              .slideX(begin: 0.08, duration: 300.ms)
                              .fadeIn(duration: 300.ms);
                        }),

                        if (sortedCats.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Text(
                                    _showIncome
                                        ? '💰'
                                        : '📊',
                                    style: const TextStyle(fontSize: 40)),
                                const SizedBox(height: 12),
                                Text(
                                  'No ${_showIncome ? 'income' : 'expenses'} this month',
                                  style: TextStyle(
                                      color: TC.text2(context), fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  )
                      .animate()
                      .fade(delay: 350.ms, duration: 500.ms)
                      .slideY(begin: 0.08),

                  // ── Budget CTA ────────────────────────────────────────────────
                  if (monthlyBudget == 0)
                    GestureDetector(
                      onTap: () => _openBudgetSheet(
                          context, state, budgetKey, _currency!, sym),
                      child: Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                              primaryColor.withValues(alpha: isDark ? 0.05 : 0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: primaryColor, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Set a Monthly Budget',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: TC.text(context)),
                                  ),
                                  Text(
                                    'Track your ${_showIncome ? 'income goals' : 'spending limits'}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: TC.text2(context)),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: primaryColor, size: 20),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fade(delay: 450.ms)
                        .slideY(begin: 0.05),

                  if (monthlyBudget > 0)
                    GestureDetector(
                      onTap: () => _openBudgetSheet(
                          context, state, budgetKey, _currency!, sym),
                      child: Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: TC.card(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: TC.border(context)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.speed,
                                    color: primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Text('Monthly Budget',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: TC.text(context))),
                                const Spacer(),
                                Text(
                                  '$sym${AppCurrencyUtils.formatAmount(monthlyBudget, 0)}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: TC.text2(context)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (pct / 100).clamp(0.0, 1.0),
                                backgroundColor: TC.border(context),
                                valueColor: AlwaysStoppedAnimation(
                                  pct > 90
                                      ? AppColors.red
                                      : pct > 70
                                          ? AppColors.amber
                                          : AppColors.green,
                                ),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${pct.toStringAsFixed(0)}% used',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: TC.text3(context))),
                                Text('Tap to edit',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fade(delay: 450.ms)
                        .slideY(begin: 0.05),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openBudgetSheet(BuildContext context, AppState state,
      String budgetKey, String currency, String sym) {
    final currentAmount = state.getBudgetLimit(budgetKey, currency);
    String valStr = currentAmount > 0 ? currentAmount.toStringAsFixed(0) : '0';
    bool isWeekly = false; // default monthly

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setBState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: TC.border(context),
                          borderRadius: BorderRadius.circular(2)),
                      margin: const EdgeInsets.only(bottom: 24)),
                  Text('Set Budget Target',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: TC.text(context))),
                  const SizedBox(height: 16),
                  // Weekly / Monthly toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: TC.border(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setBState(() => isWeekly = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isWeekly ? AppColors.green : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text('Monthly', style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: !isWeekly ? Colors.white : TC.text2(context),
                              )),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setBState(() => isWeekly = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isWeekly ? AppColors.green : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text('Weekly', style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: isWeekly ? Colors.white : TC.text2(context),
                              )),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(sym,
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: TC.text2(context))),
                        const SizedBox(width: 4),
                        Text(valStr,
                            style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: TC.text(context))),
                      ],
                    ),
                  ),
                  Text(
                    isWeekly ? 'per week' : 'per month',
                    style: TextStyle(fontSize: 12, color: TC.text3(context)),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.8,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final i in [
                        '1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0',
                        'del'
                      ])
                        if (i == '')
                          const SizedBox()
                        else
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setBState(() {
                                if (i == 'del') {
                                  if (valStr.length > 1)
                                    valStr = valStr.substring(
                                        0, valStr.length - 1);
                                  else
                                    valStr = '0';
                                } else {
                                  if (valStr == '0')
                                    valStr = i;
                                  else
                                    valStr += i;
                                }
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                  color: TC.border(context),
                                  borderRadius: BorderRadius.circular(16)),
                              alignment: Alignment.center,
                              child: i == 'del'
                                  ? Icon(Icons.backspace,
                                      color: TC.text(context))
                                  : Text(i,
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: TC.text(context))),
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      double v = double.tryParse(valStr) ?? 0;
                      // If weekly, convert to monthly equivalent for storage (×4.33)
                      final monthlyVal = isWeekly ? v * 4.33 : v;
                      state.setBudgetLimit(budgetKey, currency, monthlyVal);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.center,
                      child: const Text('Save Target →',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

// ─── Toggle Pill ──────────────────────────────────────────────────────────────
class _TogglePill extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _TogglePill(
      {required this.label,
      required this.active,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : TC.text2(context),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TC.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TC.border(context)),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: TC.text(context))),
            const SizedBox(height: 2),
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: TC.text3(context))),
          ],
        ),
      ),
    );
  }
}

// ─── Gradient Area Chart ──────────────────────────────────────────────────────
class _GradientAreaChart extends StatelessWidget {
  final List<DateTime> months;
  final List<double> values;
  final Color primaryColor, gradientStart, gradientEnd;
  final bool isDark;
  final BuildContext context;

  const _GradientAreaChart({
    required this.months,
    required this.values,
    required this.primaryColor,
    required this.gradientStart,
    required this.gradientEnd,
    required this.isDark,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    double maxVal = 0;
    for (final v in values) {
      if (v > maxVal) maxVal = v;
    }
    if (maxVal == 0) maxVal = 10;
    maxVal = maxVal * 1.25;

    const shortMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxVal,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => TC.card(context),
            getTooltipItems: (touchedSpots) {
              return touchedSpots
                  .map((spot) => LineTooltipItem(
                        AppCurrencyUtils.formatAmount(spot.y, 0),
                        TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ))
                  .toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal / 4 > 0 ? maxVal / 4 : 1,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: TC.border(context), strokeWidth: 1, dashArray: [5, 5]),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (val, meta) {
                if (val == 0 || val > maxVal * 0.95)
                  return const SizedBox.shrink();
                String str = val.toStringAsFixed(0);
                if (val >= 1000) {
                  str = '${(val / 1000).toStringAsFixed(1)}k';
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(str,
                      style: TextStyle(
                          color: TC.text3(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, meta) {
                int idx = val.toInt();
                if (idx < 0 || idx >= months.length)
                  return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    shortMonths[months[idx].month - 1],
                    style: TextStyle(
                        color: TC.text3(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: values
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            curveSmoothness: 0.35,
            gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: index == values.length - 1 ? 5 : 3,
                color: index == values.length - 1
                    ? primaryColor
                    : TC.card(context),
                strokeWidth: 2.5,
                strokeColor: primaryColor,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  gradientStart.withValues(alpha: isDark ? 0.25 : 0.15),
                  gradientEnd.withValues(alpha: 0.01),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }
}

Color _getCatColor(String catEmoji) {
  return AppState.getCategoryColor(catEmoji);
}

class _DonutSlice {
  final double value;
  final Color color;
  const _DonutSlice({required this.value, required this.color});
}

class _AnimatedDonutPainter extends CustomPainter {
  final List<_DonutSlice> slices;
  final double progress;
  final Color ringColor, bgColor;
  final int touchedIndex;

  const _AnimatedDonutPainter({
    required this.slices,
    required this.progress,
    required this.ringColor,
    required this.bgColor,
    this.touchedIndex = -1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 4;
    const strokeW = 24.0;
    const gap = 0.025;

    if (slices.isEmpty) {
      final paint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW;
      canvas.drawCircle(center, outerR - strokeW / 2, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final sweepAngle = (slice.value * 2 * math.pi - gap) * progress;
      if (sweepAngle <= 0) {
        startAngle += slice.value * 2 * math.pi * progress;
        continue;
      }
      final isSelected = i == touchedIndex;
      final sw = isSelected ? strokeW + 6 : strokeW;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerR - strokeW / 2),
        startAngle + gap / 2,
        sweepAngle,
        false,
        paint,
      );
      startAngle += slice.value * 2 * math.pi * progress;
    }

    canvas.drawCircle(
        center,
        outerR - strokeW,
        Paint()
          ..color = bgColor
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_AnimatedDonutPainter old) => true;
}
