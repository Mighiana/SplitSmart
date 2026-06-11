import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../main.dart';
import '../utils/app_utils.dart';
import '../l10n/app_localizations.dart';
import 'transaction_type_screen.dart';
import 'personal_charts_screen.dart';
import '../utils/icon_map.dart';

// ─── Filter enum ────────────────────────────────────────────────────────────
enum _OvTab { all, personal, groups }

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  _OvTab _ovTab = _OvTab.all;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    final now = DateTime.now();
    final l = AppLocalizations.of(context);

    // Currency
    String? selectedCur = state.dashboardCurrency;
    if (selectedCur == null) {
      if (state.activeCurrencies.isNotEmpty) {
        selectedCur = state.activeCurrencies.first;
      } else {
        selectedCur = 'USD';
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.dashboardCurrency == null) {
          state.setDashboardCurrency(selectedCur!);
        }
      });
    }

    final curSym = AppState.currencies.firstWhere(
      (c) => c.code == selectedCur,
      orElse: () => const CurrencyData('', '', '', r'$'),
    ).sym;
    final curFlag = AppState.currencies.firstWhere(
      (c) => c.code == selectedCur,
      orElse: () => const CurrencyData('USD', 'US Dollar', '🇺🇸', r'$'),
    ).flag;

    // Date Range
    final DateTime startDate = state.overviewStartDate ?? DateTime(now.year, now.month, 1);
    final DateTime endDate = state.overviewEndDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Transactions for selected range
    final allTxs = state.allTransactionsWithGroupShares;
    final monthTxs = allTxs.where((t) {
      if (t.currency != selectedCur) return false;
      final d = t.rawDate;
      if (d == null) return false;
      if (_ovTab == _OvTab.personal && t.isGroupShare) return false;
      if (_ovTab == _OvTab.groups && !t.isGroupShare) return false;
      return d.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
             d.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();

    final expenses = monthTxs.where((t) => t.type.toLowerCase() == 'expense').toList();
    final incomes  = monthTxs.where((t) => t.type.toLowerCase() == 'income').toList();
    final totalExpense = expenses.fold(0.0, (s, t) => s + t.amount);
    final totalIncome  = incomes.fold(0.0,  (s, t) => s + t.amount);
    final saved = totalIncome - totalExpense;

    // Category breakdown
    final Map<String, double> catSpent = {};
    for (final t in expenses) {
      catSpent[t.cat] = (catSpent[t.cat] ?? 0) + t.amount;
    }
    final sortedCats = catSpent.entries.toList()..sort((a,b) => b.value.compareTo(a.value));

    // 4-segment trend data for the selected period
    final List<double> incomeData = [];
    final List<double> expenseData = [];
    final List<String> monthLabels = [];
    final int totalDays = endDate.difference(startDate).inDays + 1;
    final int segmentDays = (totalDays / 4).ceil();
    for (int i = 0; i < 4; i++) {
      final sDate = startDate.add(Duration(days: i * segmentDays));
      final eDate = (i == 3) ? endDate : sDate.add(Duration(days: segmentDays - 1));
      monthLabels.add('W');
      final segTxs = allTxs.where((t) {
        final d = t.rawDate;
        if (d == null || t.currency != selectedCur) return false;
        // Respect the All / Personal / Groups tab, same as monthTxs.
        if (_ovTab == _OvTab.personal && t.isGroupShare) return false;
        if (_ovTab == _OvTab.groups && !t.isGroupShare) return false;
        return d.compareTo(sDate) >= 0 &&
            d.compareTo(eDate.add(const Duration(days: 1))) < 0;
      });
      incomeData.add(segTxs.where((t) => t.type.toLowerCase() == 'income').fold(0.0, (s,t) => s+t.amount));
      expenseData.add(segTxs.where((t) => t.type.toLowerCase() == 'expense').fold(0.0, (s,t) => s+t.amount));
    }


    // Pace comparison: previous month up to the SAME day-of-month, so the chip
    // is honest mid-month (full-month comparisons always read "under" early).
    // Custom ranges fall back to the full previous period (-1 sentinel).
    double pacePrev = -1;
    final bool isDefaultMonth =
        state.overviewStartDate == null && state.overviewEndDate == null;
    if (isDefaultMonth) {
      final prevStart = DateTime(now.year, now.month - 1, 1);
      final prevLen = DateTime(now.year, now.month, 0).day;
      final cutDay = now.day > prevLen ? prevLen : now.day;
      final prevCut = DateTime(now.year, now.month - 1, cutDay, 23, 59, 59);
      pacePrev = allTxs.where((t) {
        if (t.currency != selectedCur) return false;
        if (t.type.toLowerCase() != 'expense') return false;
        if (_ovTab == _OvTab.personal && t.isGroupShare) return false;
        if (_ovTab == _OvTab.groups && !t.isGroupShare) return false;
        final d = t.rawDate;
        return d != null && !d.isBefore(prevStart) && !d.isAfter(prevCut);
      }).fold(0.0, (s, t) => s + t.amount);
    }
    final int currentSeg =
        isDefaultMonth ? ((now.day - 1) ~/ (segmentDays > 0 ? segmentDays : 8)).clamp(0, 3) : 3;

    String dateLabel = '';
    if (state.overviewStartDate != null && state.overviewEndDate != null) {
      if (state.overviewStartDate!.month == state.overviewEndDate!.month && 
          state.overviewStartDate!.year == state.overviewEndDate!.year &&
          state.overviewEndDate!.day >= 28) {
        dateLabel = _monthYear(state.overviewStartDate!);
      } else {
        dateLabel = '${_shortMonth(state.overviewStartDate!.month).toUpperCase()} ${state.overviewStartDate!.day} - ${_shortMonth(state.overviewEndDate!.month).toUpperCase()} ${state.overviewEndDate!.day}';
      }
    } else {
      dateLabel = _monthYear(startDate);
    }

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<AppState>().refresh(),
          color: TC.primary(context),
          backgroundColor: TC.card(context),
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            _buildHeader(context, isDark, curFlag, selectedCur, dateLabel)
                .animate()
                .fadeIn(duration: 280.ms)
                .slideY(begin: -0.08, end: 0, curve: Curves.easeOutCubic),
            _buildSpendingStory(context, isDark, totalExpense, curSym, dateLabel, state, selectedCur, startDate, endDate, sortedCats, expenseData, pacePrev, isDefaultMonth, currentSeg)
                .animate(delay: 150.ms)
                .fadeIn(duration: 340.ms)
                .slideY(begin: 0.12, end: 0, curve: Curves.easeOutBack),
            _buildTabs(context, isDark)
                .animate(delay: 220.ms)
                .fadeIn(duration: 280.ms)
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 14),
            _buildSpendingSummary(context, isDark, sortedCats, totalExpense, curSym, l, state, selectedCur, startDate, endDate)
                .animate(delay: 300.ms)
                .fadeIn(duration: 360.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutBack),
            const SizedBox(height: 2),
            _buildTwoCol(context, isDark, totalIncome, totalExpense, saved, curSym, incomeData, expenseData, monthLabels)
                .animate(delay: 380.ms)
                .fadeIn(duration: 360.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
            _buildCategoryBreakdown(context, isDark, sortedCats, totalExpense, curSym)
                .animate(delay: 460.ms)
                .fadeIn(duration: 360.ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
            if (totalExpense <= 0 && totalIncome <= 0) _buildGetStarted(context, isDark),
            const SizedBox(height: 16),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildSpendingStory(
    BuildContext context,
    bool isDark,
    double totalExpense,
    String sym,
    String dateLabel,
    AppState state,
    String? selectedCur,
    DateTime start,
    DateTime end,
    List<MapEntry<String, double>> sortedCats,
    List<double> weekBars,
    double pacePrev,
    bool isDefaultMonth,
    int currentSeg,
  ) {
    // Pace-aware delta: same-point-last-month for the default view, full
    // previous period for custom ranges.
    final prev = pacePrev >= 0
        ? pacePrev
        : _prevPeriodExpense(state, start, end, selectedCur);
    final diffPct = prev > 0 ? ((totalExpense - prev) / prev * 100) : null;
    final paceLabel =
        isDefaultMonth ? 'vs this time last month' : 'vs previous period';
    final top = sortedCats.isNotEmpty ? sortedCats.first : null;
    final topCat = top == null
        ? null
        : AppState.expenseCategories.firstWhere(
            (c) => c.icon == top.key,
            orElse: () => const CategoryItem('', 'Other', ''),
          );
    final topLabel = topCat?.label ?? 'Other';
    final story = totalExpense <= 0
        ? 'No spending recorded for this range yet.'
        : top == null
            ? 'Your spending is ready for review.'
            : topLabel == 'Other'
                // Everything is uncategorised — a "100% Other" stat is useless.
                ? 'Tip: set a category on your expenses to see where your money goes.'
                : '$topLabel is your top category at ${(top.value / totalExpense * 100).round()}% of spending.';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$dateLabel · Total spent',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: TC.text3(context),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$sym${AppCurrencyUtils.formatAmount(totalExpense, 0)}',
                      style:
                          TC.gloock(context, fontSize: 40, letterSpacing: -1.4),
                    ),
                    if (diffPct != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: diffPct >= 0
                              ? AppColors.red.withValues(alpha: 0.10)
                              : AppColors.greenDim,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              diffPct >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 13,
                              color: diffPct >= 0
                                  ? AppColors.red
                                  : AppColors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${diffPct >= 0 ? '+' : ''}${diffPct.round()}% $paceLabel',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: diffPct >= 0
                                    ? AppColors.red
                                    : AppColors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Weekly spending mini bars (current segment highlighted) —
              // taps through to the full charts screen.
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              MoneyChartsScreen(initialCurrency: selectedCur)));
                },
                child: Builder(builder: (context) {
                  final maxW = weekBars.fold(0.0, (m, v) => v > m ? v : m);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(weekBars.length, (i) {
                      final h = maxW <= 0
                          ? 10.0
                          : 12.0 + (weekBars[i] / maxW) * 56.0;
                      final isCur = i == currentSeg;
                      return Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 7),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              width: 14,
                              height: h,
                              decoration: BoxDecoration(
                                color: isCur
                                    ? TC.primary(context)
                                    : TC.primary(context)
                                        .withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('W${i + 1}',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: isCur
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isCur
                                        ? TC.primary(context)
                                        : TC.text3(context))),
                          ],
                        ),
                      );
                    }),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: totalExpense > 0 ? AppColors.greenDim : TC.card2(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  totalExpense > 0 ? Icons.lightbulb_rounded : Icons.info_outline_rounded,
                  color: AppColors.green,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    story,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TC.text2(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, String flag, String? selectedCur, String dateLabel) {
    return Container(
      color: TC.card(context),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SPENDING ANALYSIS',
              style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w700, color: TC.primaryMd(context), letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text('Overview', style: TC.gloock(context, fontSize: 32, letterSpacing: -0.8, height: 1.1)),
          const SizedBox(height: 3),
          Text('How you are spending your money', style: TextStyle(fontSize: 13, color: TC.text3(context), fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          Row(children: [
            GestureDetector(
              onTap: _pickCurrency,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.green, width: 1.5),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(selectedCur ?? 'USD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TC.text(context))),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more_rounded, size: 16, color: TC.text(context)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: GestureDetector(
                onTap: () => _pickMonth(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: TC.border(context), width: 1.5),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today_outlined, size: 13, color: TC.text(context)),
                    const SizedBox(width: 5),
                    Flexible(child: Text(dateLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TC.text(context)), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 3),
                    Icon(Icons.expand_more_rounded, size: 16, color: TC.text(context)),
                  ]),
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _pickCustomRange(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  border: Border.all(color: TC.border(context), width: 1.5),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.tune_rounded, size: 16, color: TC.text(context)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Tabs ────────────────────────────────────────────────────────────────
  Widget _buildTabs(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEEF0F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: _OvTab.values.map((tab) {
        final active = tab == _ovTab;
        final label = tab == _OvTab.all ? 'All' : tab == _OvTab.personal ? 'Personal' : 'Groups';
        return Expanded(child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); setState(() => _ovTab = tab); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? AppColors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: active ? [BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0,2))] : null,
            ),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: active ? Colors.white : TC.text3(context))),
          ),
        ));
      }).toList()),
    );
  }

  // ── Spending Summary ────────────────────────────────────────────────────
  Widget _buildSpendingSummary(BuildContext context, bool isDark, List<MapEntry<String,double>> cats, double total, String sym, AppLocalizations l, AppState state, String? selectedCur, DateTime start, DateTime end) {
    // Merge unrecognised category keys into "Other" so the donut covers 100%
    final knownIcons = AppState.expenseCategories.map((c) => c.icon).toSet();
    final List<MapEntry<String, double>> knownCats = [];
    double unknownTotal = 0.0;
    for (final e in cats) {
      if (knownIcons.contains(e.key) || e.key == 'Other') {
        knownCats.add(e);
      } else {
        unknownTotal += e.value;
      }
    }
    if (unknownTotal > 0) {
      final idx = knownCats.indexWhere((e) => e.key == 'Other');
      if (idx >= 0) {
        final old = knownCats[idx];
        knownCats[idx] = MapEntry('Other', old.value + unknownTotal);
      } else {
        knownCats.add(MapEntry('Other', unknownTotal));
      }
    }
    knownCats.sort((a, b) => b.value.compareTo(a.value));

    final bool hasMore = knownCats.length > 4;
    List<MapEntry<String, double>> displayCats;
    if (!hasMore) {
      displayCats = knownCats;
    } else {
      displayCats = knownCats.take(3).toList();
      final otherVal = knownCats.skip(3).fold(0.0, (s, e) => s + e.value);
      displayCats.add(MapEntry('Other', otherVal));
    }

    // Normalise slices so they ALWAYS sum to 1.0 — eliminates any white gap
    final sliceTotal = displayCats.fold(0.0, (s, e) => s + e.value);
    final visibleCats = displayCats.where((e) => e.value > 0).toList();
    // A lone "Other" ring looks dull/grey — tint a single slice with the brand
    // colour instead so the donut still reads as a chart.
    final donutSlices = sliceTotal > 0
        ? visibleCats
            .map((e) => _DonutSlice(
                value: e.value / sliceTotal,
                color: (visibleCats.length == 1 && e.key == 'Other')
                    ? TC.primary(context)
                    : _getCatColor(e.key)))
            .toList()
        : <_DonutSlice>[];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark?0.15:0.05), blurRadius: 10, offset: const Offset(0,3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Spending Summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: TC.text(context))),
            const SizedBox(height: 2),
            Text('Where your money went', style: TextStyle(fontSize: 12, color: TC.text3(context), fontWeight: FontWeight.w500)),
          ])),
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: TC.text3(context)),
            const SizedBox(width: 4),
            Text('Selected currency only', style: TextStyle(fontSize: 10, color: TC.text3(context), fontWeight: FontWeight.w600)),
          ]),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Donut
          SizedBox(width: 130, height: 130, child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(130,130), painter: _DonutPainter(
              slices: donutSlices,
              ringColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFD1D5DB),
              bgColor: TC.card(context),
            )),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$sym${AppCurrencyUtils.formatAmount(total, 0)}', style: TC.gloock(context, fontSize: 18, letterSpacing: -0.3)),
              Text('Total Spent', style: TextStyle(fontSize: 11, color: TC.text3(context), fontWeight: FontWeight.w600)),
            ]),
          ])),
          const SizedBox(width: 16),
          // Legend / Empty state
          Expanded(child: cats.isEmpty
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _WalletIllustration(),
                const SizedBox(height: 10),
                Text('No expenses yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TC.text(context))),
                const SizedBox(height: 4),
                Text('Add your first transaction\nto unlock insights', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: TC.text3(context), height: 1.5)),
              ])
            : Column(children: displayCats.map((e) {
                final pct = total > 0 ? (e.value/total*100) : 0.0;
                final catName = e.key == 'Other' ? 'Other' : AppState.expenseCategories.firstWhere((x) => x.icon == e.key, orElse: () => const CategoryItem('','Other','')).label;
                final cc = _getCatColor(e.key);
                final iconWidget = e.key == 'Other'
                  ? Icon(Icons.more_horiz, size: 14, color: cc)
                  : Icon(iconForEmoji(e.key), size: 15, color: cc);
                return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
                  Container(width: 28, height: 28, decoration: BoxDecoration(color: cc.withValues(alpha:0.15), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center,
                    child: iconWidget),
                  const SizedBox(width: 8),
                  Expanded(child: Text(catName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TC.text(context)), maxLines:1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 4),
                  SizedBox(width: 30, child: Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: TC.text3(context)), textAlign: TextAlign.right)),
                  const SizedBox(width: 4),
                  SizedBox(width: 56, child: Text('$sym${AppCurrencyUtils.formatAmount(e.value, 0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.text(context)), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]));
              }).toList()),
          ),
        ]),
        // See All button – visible only when user has > 4 categories
        if (hasMore) ...[  
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MoneyChartsScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.greenDim,
              ),
              alignment: Alignment.center,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.bar_chart_rounded, color: AppColors.green, size: 15),
                const SizedBox(width: 6),
                Text('See all ${knownCats.length} categories',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(total <= 0 ? Icons.trending_flat_rounded : (total <= _prevPeriodExpense(state, start, end, selectedCur) ? Icons.trending_down_rounded : Icons.trending_up_rounded), color: AppColors.green, size: 16),
            const SizedBox(width: 7),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(total <= 0 ? 'No spending recorded for this period' : _spendComparisonText(state, start, end, total, selectedCur), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
              if (total <= 0) Text('Start by adding an expense or income', style: TextStyle(fontSize: 11, color: TC.text3(context))),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.green, size: 14),
          ]),
        ),
      ]),
    );
  }

  // ── Two column: Income vs Expense + Monthly Trend ───────────────────────
  Widget _buildTwoCol(BuildContext context, bool isDark, double income, double expense, double saved, String sym,
      List<double> incData, List<double> expData, List<String> labels) {
    final maxVal = [...incData, ...expData].fold(0.0, (m,v) => v > m ? v : m);
    final incRatio = (income + expense) > 0 ? (income / (income + expense)) : 0.0;
    final expRatio = (income + expense) > 0 ? (expense / (income + expense)) : 0.0;
    void openCharts() {
      HapticFeedback.selectionClick();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MoneyChartsScreen()));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Income vs Expense
        Expanded(child: GestureDetector(onTap: openCharts, child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark?0.15:0.05), blurRadius: 10, offset: const Offset(0,3))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Income vs Expense', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: TC.text(context))),
              const SizedBox(height: 12),
              Row(children: [
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Expanded(child: Text('Income', style: TextStyle(fontSize: 12, color: TC.text(context)))),
                Text('$sym${AppCurrencyUtils.formatAmount(income, 0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: TC.text(context))),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: incRatio.clamp(0.0,1.0), minHeight: 7,
                backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation(AppColors.green),
              )),
              const SizedBox(height: 8),
              Row(children: [
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Expanded(child: Text('Expense', style: TextStyle(fontSize: 12, color: TC.text(context)))),
                Text('$sym${AppCurrencyUtils.formatAmount(expense, 0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: TC.text(context))),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: expRatio.clamp(0.0,1.0), minHeight: 7,
                backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation(AppColors.red),
              )),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: (income <= 0 && expense <= 0)
                ? const Row(children: [
                    Icon(Icons.insights_rounded, color: AppColors.green, size: 14),
                    SizedBox(width: 5),
                    Expanded(child: Text('Nothing to compare yet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.green))),
                  ])
                : Row(children: [
                    const Icon(Icons.trending_up_rounded, color: AppColors.green, size: 13),
                    const SizedBox(width: 5),
                    Expanded(child: Text(
                      saved >= 0 ? 'Saved $sym${AppCurrencyUtils.formatAmount(saved.abs(), 0)}' : 'Over by $sym${AppCurrencyUtils.formatAmount(saved.abs(), 0)}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: saved >= 0 ? AppColors.green : AppColors.red),
                    )),
                  ]),
            ),
          ]),
        ))),
        const SizedBox(width: 12),
        // Monthly Trend
        Expanded(child: GestureDetector(onTap: openCharts, child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark?0.15:0.05), blurRadius: 10, offset: const Offset(0,3))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Monthly Trend', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: TC.text(context)))),
                Icon(Icons.bar_chart_rounded, size: 15, color: TC.primary(context)),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 15, color: TC.text3(context)),
              ]),
              Text('Tap for detailed charts', style: TextStyle(fontSize: 11, color: TC.text3(context), fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Row(children: [
                Container(width: 14, height: 2, decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(1))),
                const SizedBox(width: 4),
                Text('In', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: TC.text3(context))),
                const SizedBox(width: 8),
                Container(width: 14, height: 2, decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(1))),
                const SizedBox(width: 4),
                Text('Out', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: TC.text3(context))),
              ]),
              const SizedBox(height: 8),
              SizedBox(height: 110, child: CustomPaint(
                painter: _TrendPainter(income: incData, expense: expData, labels: labels, maxVal: maxVal, isDark: isDark),
                size: const Size(double.infinity, 110),
              )),
            ]),
            if (maxVal <= 0)
              Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
                Icon(Icons.bar_chart_rounded, color: TC.text3(context), size: 14),
                const SizedBox(width: 5),
                Expanded(child: Text('No trend data yet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: TC.text3(context)))),
              ]))
            else
              const SizedBox.shrink(),
          ]),
        ))),
      ])),
    );
  }

  // ── Category Breakdown ──────────────────────────────────────────────────
  Widget _buildCategoryBreakdown(BuildContext context, bool isDark, List<MapEntry<String,double>> cats, double total, String sym) {
    if (cats.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark?0.15:0.05), blurRadius: 10, offset: const Offset(0,3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Category Breakdown', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: TC.text(context))),
        const SizedBox(height: 2),
        Text('Detailed breakdown of your spending', style: TextStyle(fontSize: 12, color: TC.text3(context), fontWeight: FontWeight.w500)),
        const SizedBox(height: 14),
        ...cats.take(4).map((e) {
          final pct = total > 0 ? (e.value / total) : 0.0;
          final cc = _getCatColor(e.key);
          final catName = AppState.expenseCategories.firstWhere((x) => x.icon == e.key, orElse: () => const CategoryItem('','Other','')).label;
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cc.withValues(alpha: 0.28), cc.withValues(alpha: 0.10)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cc.withValues(alpha: 0.40), width: 1.5),
                boxShadow: [BoxShadow(color: cc.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: e.key == 'Other'
                  ? Icon(Icons.more_horiz_rounded, size: 18, color: cc)
                  : Icon(iconForEmoji(e.key), size: 18, color: cc),
            ),
            const SizedBox(width: 10),
            Flexible(
              flex: 2,
              child: Text(catName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.text(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: pct.clamp(0.0,1.0), minHeight: 7,
                backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation(cc),
              )),
            ),
            const SizedBox(width: 6),
            SizedBox(width: 54, child: Text('$sym${AppCurrencyUtils.formatAmount(e.value, 0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: TC.text(context)), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            SizedBox(width: 30, child: Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: TC.text3(context)), textAlign: TextAlign.right)),
          ]));
        }),
        if (cats.length > 4)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MoneyChartsScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.green.withValues(alpha: 0.12), AppColors.green.withValues(alpha: 0.04)],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.45)),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.bar_chart_rounded, color: AppColors.green, size: 15),
                const SizedBox(width: 6),
                Text(
                  'See all ${cats.length} categories',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green),
                ),
              ]),
            ),
          )
      ]),
    );
  }


  // ── Helpers ─────────────────────────────────────────────────────────────
  void _pickCurrency() {
    final state = context.read<AppState>();
    final curs = state.activeCurrencies.toList();
    if (curs.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Select Currency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: TC.text(context))),
              const SizedBox(height: 12),
              ...state.activeCurrencies.map((c) {
                final cd = AppState.currencies.firstWhere((cur) => cur.code == c, orElse: () => const CurrencyData('', '', '', r'$'));
                return ListTile(
                  leading: Text(cd.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(c, style: TextStyle(fontWeight: FontWeight.w700, color: TC.text(context))),
                  trailing: state.dashboardCurrency == c ? const Icon(Icons.check_circle_rounded, color: AppColors.green) : null,
                  onTap: () { state.setDashboardCurrency(c); Navigator.pop(context); },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }


  void _pickMonth(BuildContext context) {
    int selectedYear = DateTime.now().year;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: TC.border(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Title + year selector row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Month',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: TC.text(context),
                        ),
                      ),
                      // Year prev / label / next
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setSheetState(() => selectedYear--),
                            child: Icon(Icons.chevron_left_rounded, color: TC.text2(context)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            selectedYear.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.green,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              if (selectedYear < DateTime.now().year) {
                                setSheetState(() => selectedYear++);
                              }
                            },
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: selectedYear >= DateTime.now().year
                                  ? TC.border(context)
                                  : TC.text2(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Month grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (_, index) {
                      final month = index + 1;
                      final isSelected = DateTime.now().month == month &&
                          DateTime.now().year == selectedYear;
                      return GestureDetector(
                        onTap: () {
                          final start = DateTime(selectedYear, month, 1);
                          final end = DateTime(selectedYear, month + 1, 0);
                          context.read<AppState>().setOverviewDateRange(start, end);
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.green : TC.card(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.green : TC.border(context),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _shortMonth(month),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.white : TC.text(context),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _pickCustomRange(BuildContext context) async {
    final state = context.read<AppState>();
    final initialRange = DateTimeRange(
      start: state.overviewStartDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1),
      end: state.overviewEndDate ?? DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
    );

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.green,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      state.setOverviewDateRange(picked.start, picked.end);
    }
  }

  Color _getCatColor(String cat) {
    if (cat == 'Other') return const Color(0xFF9CA3AF);
    return AppState.getCategoryColor(cat);
  }

  String _shortMonth(int m) {
    const ms = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return ms[(m-1).clamp(0,11)];
  }

  String _monthYear(DateTime d) {
    const ms = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return ms[(d.month-1).clamp(0,11)].toUpperCase();
  }

  double _prevPeriodExpense(AppState state, DateTime start, DateTime end, String? cur) {
    final duration = end.difference(start);
    final prevStart = start.subtract(duration).subtract(const Duration(days: 1));
    final prevEnd = start.subtract(const Duration(days: 1));
    
    return state.allTransactionsWithGroupShares.where((t) {
      if (t.currency != cur || t.type.toLowerCase() != 'expense') return false;
      final d = t.rawDate;
      return d != null && 
             d.isAfter(prevStart.subtract(const Duration(seconds: 1))) && 
             d.isBefore(prevEnd.add(const Duration(days: 1)));
    }).fold(0.0, (s, t) => s + t.amount);
  }

  String _spendComparisonText(AppState state, DateTime start, DateTime end, double currentExpense, String? cur) {
    final prevExp = _prevPeriodExpense(state, start, end, cur);
    if (prevExp <= 0) return 'No data for previous period';
    final diff = ((currentExpense - prevExp) / prevExp * 100).abs();
    if (currentExpense <= prevExp) {
      return 'You spent ${diff.toStringAsFixed(0)}% less compared to previous period';
    } else {
      return 'You spent ${diff.toStringAsFixed(0)}% more compared to previous period';
    }
  }
}

// ─── Get Started Section ────────────────────────────────────────────────────
extension on _HomeTabState {
  Widget _buildGetStarted(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Get Started', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: TC.text(context))),
        const SizedBox(height: 3),
        Text('Take control of your finances in a few steps', style: TextStyle(fontSize: 13, color: TC.text3(context))),
        const SizedBox(height: 14),
        Row(children: [
          _gsBtn(context, isDark, Icons.receipt_long_rounded, 'Add Expense', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionTypeScreen()));
          }),
          const SizedBox(width: 10),
          _gsBtn(context, isDark, Icons.savings_rounded, 'Add Income', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionTypeScreen()));
          }),
        ]),
      ]),
    );
  }

  Widget _gsBtn(BuildContext context, bool isDark, IconData icon, String label, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: TC.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TC.border(context), width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.green, size: 22),
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.text(context)), textAlign: TextAlign.center),
        ]),
      ),
    ));
  }
}

// ─── Wallet Illustration (empty state) ──────────────────────────────────────
class _WalletIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90, height: 80,
      child: Stack(children: [
        // Wallet body
        Positioned(left: 8, top: 20, child: Container(
          width: 62, height: 48, decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4D4D4), width: 1.5),
          ),
        )),
        // Wallet flap
        Positioned(left: 25, top: 10, child: Container(
          width: 28, height: 22, decoration: BoxDecoration(
            color: Colors.white, shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD4D4D4), width: 1.5),
          ),
        )),
        // Toggle pill
        Positioned(left: 20, top: 38, child: Container(
          width: 28, height: 14, decoration: BoxDecoration(
            color: AppColors.green, borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.centerRight,
          child: Container(
            width: 11, height: 11, margin: const EdgeInsets.only(right: 1.5),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        )),
        // Plus badge
        Positioned(right: 6, bottom: 2, child: Container(
          width: 22, height: 22, decoration: const BoxDecoration(
            color: AppColors.green, shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.add, color: Colors.white, size: 14),
        )),
        // Sparkle
        Positioned(right: 14, top: 2, child: Text('✦', style: TextStyle(
          fontSize: 12, color: AppColors.green.withValues(alpha: 0.7),
        ))),
        // Mini pie
        Positioned(left: 0, top: 0, child: Container(
          width: 18, height: 18, decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDDDDDD), width: 2.5),
          ),
        )),
      ]),
    );
  }
}

// ─── Donut Painter ──────────────────────────────────────────────────────────
class _DonutSlice {
  final double value;
  final Color color;
  _DonutSlice({required this.value, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSlice> slices;
  final Color ringColor;
  final Color bgColor;
  _DonutPainter({required this.slices, required this.ringColor, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 18..strokeCap = StrokeCap.butt;
    final rect = Rect.fromLTWH(9, 9, size.width-18, size.height-18);

    // Always draw the full grey background ring first
    paint.color = ringColor;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);

    if (slices.isEmpty) return;

    // Count active slices for gap logic
    final activeSlices = slices.where((s) => s.value > 0).toList();
    if (activeSlices.isEmpty) return;

    // Total gap in radians (2 degrees per slice gap)
    const gapAngle = 0.035;
    final totalGap = activeSlices.length > 1 ? gapAngle * activeSlices.length : 0.0;
    final totalSweep = 2 * math.pi - totalGap;

    double start = -math.pi / 2;
    for (int i = 0; i < activeSlices.length; i++) {
      final s = activeSlices[i];
      final sweep = s.value * totalSweep;
      paint.color = s.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep + (activeSlices.length > 1 ? gapAngle : 0.0);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─── Trend Painter ──────────────────────────────────────────────────────────
class _TrendPainter extends CustomPainter {
  final List<double> income;
  final List<double> expense;
  final List<String> labels;
  final double maxVal;
  final bool isDark;

  _TrendPainter({required this.income, required this.expense, required this.labels, required this.maxVal, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const pad = EdgeInsets.fromLTRB(20, 8, 4, 20);
    final W = size.width - pad.left - pad.right;
    final H = size.height - pad.top - pad.bottom;
    final n = labels.length;
    final mv = maxVal <= 0 ? 1.0 : maxVal;

    double toX(int i) => pad.left + (n <= 1 ? W/2 : i * W / (n-1));
    double toY(double v) => pad.top + H - (v/mv)*H;

    // Grid
    final gridPaint = Paint()..color = (isDark ? Colors.white : Colors.black).withValues(alpha:0.06)..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = pad.top + H - (i/3)*H;
      canvas.drawLine(Offset(pad.left, y), Offset(pad.left+W, y), gridPaint);
    }

    // Labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < n; i++) {
      tp.text = TextSpan(text: labels[i], style: TextStyle(fontSize: 8, color: isDark ? Colors.white38 : Colors.black38));
      tp.layout();
      tp.paint(canvas, Offset(toX(i) - tp.width/2, size.height - 14));
    }

    void drawLine(List<double> data, Color color) {
      if (data.isEmpty) return;
      final pts = [for (int i = 0; i < data.length; i++) Offset(toX(i), toY(data[i]))];

      // Smooth curve through the points (horizontal-tangent cubic).
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        final p0 = pts[i - 1], p1 = pts[i];
        final midX = (p0.dx + p1.dx) / 2;
        line.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }

      // Soft gradient area fill under the curve.
      final baseY = pad.top + H;
      final fill = Path.from(line)
        ..lineTo(pts.last.dx, baseY)
        ..lineTo(pts.first.dx, baseY)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
          ).createShader(Rect.fromLTWH(pad.left, pad.top, W, H)),
      );

      // The line itself.
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );

      // A single dot on the latest point only (cleaner than dotting every node).
      final last = pts.last;
      canvas.drawCircle(last, 3.5, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawCircle(last, 3.5, Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke);
    }

    drawLine(income, AppColors.green);
    drawLine(expense, AppColors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}


