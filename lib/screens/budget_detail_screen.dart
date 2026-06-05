import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import 'new_budget_screen.dart';

/// Budget detail (Phase B) — period summary + spend-forecast trend chart.
class BudgetDetailScreen extends StatelessWidget {
  final Budget budget;
  const BudgetDetailScreen({super.key, required this.budget});

  String _sym(String code) => AppState.currencies
      .firstWhere((c) => c.code == code,
          orElse: () => CurrencyData(code, code, '💰', code))
      .sym;

  String _periodTitle(DateTime start) {
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    switch (budget.period) {
      case 'weekly':
        return 'WEEK OF ${start.day} ${months[start.month - 1]}';
      case 'yearly':
        return 'YEAR ${start.year}';
      default:
        return '${months[start.month - 1]} ${start.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Use the live copy of the budget (in case it was edited)
    final b = state.budgets.firstWhere((x) => x.id == budget.id, orElse: () => budget);
    final sym = _sym(b.currency);

    // ── Period window ──
    final now = DateTime.now();
    late DateTime start, end;
    switch (b.period) {
      case 'weekly':
        final s = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(s.year, s.month, s.day);
        end = start.add(const Duration(days: 6));
        break;
      case 'yearly':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0);
    }
    final totalDays = end.difference(start).inDays + 1;
    int todayIndex = now.difference(start).inDays;
    if (todayIndex < 0) todayIndex = 0;
    if (todayIndex > totalDays - 1) todayIndex = totalDays - 1;

    // ── Per-day spend buckets ──
    final daily = List<double>.filled(totalDays, 0);
    for (final t in state.allTransactionsWithGroupShares) {
      if (t.type.toLowerCase() != 'expense') continue;
      if (t.currency != b.currency) continue;
      if (b.categories.isNotEmpty) {
        final matchesParent = b.categories.contains(t.cat);
        final matchesSub = t.subcat != null && b.categories.contains(t.subcat);
        if (!matchesParent && !matchesSub) continue;
      }
      final d = t.rawDate ?? DateTime.tryParse(t.date);
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      final idx = day.difference(start).inDays;
      if (idx >= 0 && idx < totalDays) daily[idx] += t.amount;
    }

    // Cumulative actual up to today
    final cum = List<double>.filled(totalDays, 0);
    double run = 0;
    for (var i = 0; i <= todayIndex; i++) {
      run += daily[i];
      cum[i] = run;
    }
    final spent = cum[todayIndex];
    final limit = b.amount;
    final remaining = limit - spent;
    final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final over = spent > limit;

    // Forecast (linear from average daily rate so far)
    final elapsed = todayIndex + 1;
    final dailyRate = elapsed > 0 ? spent / elapsed : 0.0;
    final forecastTotal = spent + dailyRate * (totalDays - 1 - todayIndex);
    final willOverspend = forecastTotal > limit && limit > 0;
    double crossing = totalDays.toDouble(); // index where forecast hits limit
    if (willOverspend && dailyRate > 0) {
      crossing = todayIndex + (limit - spent) / dailyRate;
      if (crossing < todayIndex) crossing = todayIndex.toDouble();
      if (crossing > totalDays - 1) crossing = (totalDays - 1).toDouble();
    }

    final maxY = [forecastTotal, limit, spent].reduce((a, c) => a > c ? a : c) * 1.15;

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: TC.card(context), shape: BoxShape.circle, border: Border.all(color: TC.border(context))),
                      alignment: Alignment.center,
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: TC.text(context)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_periodTitle(start), style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: TC.primaryMd(context))),
                        Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TC.gloock(context, fontSize: 24, color: TC.text(context), letterSpacing: -0.4)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => NewBudgetScreen(existing: b)));
                    },
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: TC.card(context), shape: BoxShape.circle, border: Border.all(color: TC.border(context))),
                      alignment: Alignment.center,
                      child: Icon(Icons.edit_outlined, size: 16, color: TC.text(context)),
                    ),
                  ),
                ],
              ),
            ),

            // Summary card
            Container(
              margin: const EdgeInsets.fromLTRB(18, 6, 18, 14),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$sym${AppCurrencyUtils.formatAmount(limit, 0)}', style: TC.gloock(context, fontSize: 30, color: TC.text(context), letterSpacing: -1)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: (over ? TC.er(context) : TC.primary(context)).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text('${(pct * 100).round()}% used', style: TC.geist(context, fontSize: 12, fontWeight: FontWeight.w800, color: over ? TC.er(context) : TC.primary(context))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      minHeight: 10,
                      backgroundColor: TC.bg2(context),
                      valueColor: AlwaysStoppedAnimation(over ? TC.er(context) : (pct >= 0.8 ? TC.wn(context) : TC.primary(context))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$sym${AppCurrencyUtils.formatAmount(spent, 0)}', style: TC.gloock(context, fontSize: 18, color: TC.text(context))),
                        Text('Spent', style: TC.geist(context, fontSize: 11, color: TC.text3(context))),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('$sym${AppCurrencyUtils.formatAmount(remaining.abs(), 0)}', style: TC.gloock(context, fontSize: 18, color: over ? TC.er(context) : TC.ok(context))),
                        Text(over ? 'Over' : 'Remains', style: TC.geist(context, fontSize: 11, color: TC.text3(context))),
                      ]),
                    ],
                  ),
                ],
              ),
            ),

            // Trend section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Text('Trend', style: TC.gloock(context, fontSize: 20, color: TC.text(context))),
            ),
            if (willOverspend)
              Container(
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: TC.er(context).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TC.er(context).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: TC.er(context), size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'At this pace you’ll spend ~$sym${AppCurrencyUtils.formatAmount(forecastTotal, 0)} — over budget. You risk overspending.',
                    style: TC.geist(context, fontSize: 12, fontWeight: FontWeight.w600, color: TC.er(context), height: 1.4),
                  )),
                ]),
              ),
            Container(
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              padding: const EdgeInsets.fromLTRB(8, 18, 18, 10),
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: SizedBox(
                height: 200,
                child: _buildChart(context, totalDays, todayIndex, cum, dailyRate, spent, limit, maxY, crossing, willOverspend, sym),
              ),
            ),
            // Legend
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Wrap(spacing: 16, runSpacing: 6, children: [
                _legend(context, TC.ok(context), 'Spent'),
                _legend(context, TC.blue(context), 'Forecast'),
                if (willOverspend) _legend(context, TC.er(context), 'Overspend'),
                _legend(context, TC.text3(context), 'Limit'),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 3, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w700, color: TC.text3(context))),
      ]);

  Widget _buildChart(BuildContext context, int totalDays, int todayIndex, List<double> cum,
      double dailyRate, double spent, double limit, double maxY, double crossing, bool willOverspend, String sym) {
    final actual = <FlSpot>[
      for (var i = 0; i <= todayIndex; i++) FlSpot(i.toDouble(), cum[i]),
    ];
    // Forecast spots from today to end
    double fAt(double i) => spent + dailyRate * (i - todayIndex);
    final lastIdx = (totalDays - 1).toDouble();

    final forecastBlue = <FlSpot>[];
    final forecastRed = <FlSpot>[];
    if (willOverspend) {
      forecastBlue.add(FlSpot(todayIndex.toDouble(), spent));
      forecastBlue.add(FlSpot(crossing, fAt(crossing)));
      forecastRed.add(FlSpot(crossing, fAt(crossing)));
      forecastRed.add(FlSpot(lastIdx, fAt(lastIdx)));
    } else {
      forecastBlue.add(FlSpot(todayIndex.toDouble(), spent));
      forecastBlue.add(FlSpot(lastIdx, fAt(lastIdx)));
    }

    final bars = <LineChartBarData>[
      // Limit (dashed)
      LineChartBarData(
        spots: [FlSpot(0, limit), FlSpot(lastIdx, limit)],
        isCurved: false,
        color: TC.text3(context),
        barWidth: 1.5,
        dashArray: [6, 4],
        dotData: const FlDotData(show: false),
      ),
      // Actual spent (green) with fill
      LineChartBarData(
        spots: actual,
        isCurved: true,
        color: TC.ok(context),
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: TC.ok(context).withValues(alpha: 0.12)),
      ),
      // Forecast (blue)
      LineChartBarData(
        spots: forecastBlue,
        isCurved: false,
        color: TC.blue(context),
        barWidth: 3,
        dashArray: [2, 3],
        dotData: const FlDotData(show: false),
      ),
      if (willOverspend)
        LineChartBarData(
          spots: forecastRed,
          isCurved: false,
          color: TC.er(context),
          barWidth: 3,
          dashArray: [2, 3],
          dotData: const FlDotData(show: false),
        ),
    ];

    return LineChart(LineChartData(
      minX: 0,
      maxX: lastIdx,
      minY: 0,
      maxY: maxY <= 0 ? 1 : maxY,
      lineTouchData: const LineTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? maxY / 3 : 1,
        getDrawingHorizontalLine: (v) => FlLine(color: TC.border(context), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: maxY > 0 ? maxY / 3 : 1,
            getTitlesWidget: (v, m) => Text(
              v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
              style: TC.geist(context, fontSize: 9, color: TC.text3(context)),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: (totalDays / 4).ceilToDouble(),
            getTitlesWidget: (v, m) => Text('${v.toInt() + 1}', style: TC.geist(context, fontSize: 9, color: TC.text3(context))),
          ),
        ),
      ),
      lineBarsData: bars,
    ));
  }
}
