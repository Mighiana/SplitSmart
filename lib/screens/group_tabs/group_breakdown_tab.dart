import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/app_utils.dart';
import '../../main.dart';
import '../settle_up_screen.dart';

class GroupBreakdownTab extends StatefulWidget {
  final GroupData g;
  final AppState state;
  const GroupBreakdownTab({super.key, required this.g, required this.state});

  @override
  State<GroupBreakdownTab> createState() => _GroupBreakdownTabState();
}

class _GroupBreakdownTabState extends State<GroupBreakdownTab> with TickerProviderStateMixin {
  late AnimationController _barCtrl;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _barCtrl.forward();
    });
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final state = widget.state;
    final total = g.expenses.fold(0.0, (s, e) => s + e.amount);
    final perPerson = g.members.isEmpty ? 0.0 : total / g.members.length;
    final plan = state.buildSettlePlan(g);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SSCard(
          child: Column(
            children: [
              _calcRow(
                context,
                'Total expenses',
                '${g.sym}${total.toStringAsFixed(2)}',
                false,
              ),
              _calcRow(
                context,
                'Number of people',
                g.members.length.toString(),
                false,
              ),
              const Divider(color: AppColors.border, height: 20),
              _calcRow(
                context,
                'Fair share per person',
                '${g.sym}${perPerson.toStringAsFixed(2)}',
                true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'INDIVIDUAL BREAKDOWN',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: TC.text3(context),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        ...g.members.asMap().entries.map((entry) {
          final idx = entry.key;
          final m = entry.value;
          double paid = 0, owes = 0;

          for (final e in g.expenses) {
            if (e.paidBy == m) paid += e.amount;
            if (e.splits != null && e.splits!.containsKey(m)) {
              owes += e.splits![m]!;
            } else {
              owes += e.amount / g.members.length;
            }
          }

          final net = paid - owes;
          final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
          final barAnim = CurvedAnimation(
            parent: _barCtrl,
            curve: Interval(
              (idx * 0.12).clamp(0.0, 0.5),
              ((idx * 0.12) + 0.6).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TC.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarCircle(label: m, size: 32),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: TC.text(context),
                        ),
                      ),
                    ),
                    Text(
                      '${g.sym}${paid.toStringAsFixed(2)} paid',
                      style: TextStyle(
                        fontSize: 11,
                        color: TC.text2(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: barAnim,
                  builder: (_, __) {
                    final barVal = barAnim.value * progress;
                    final barColor =
                        net >= 0 ? AppColors.green : AppColors.red;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: barVal,
                            backgroundColor: TC.border(context),
                            valueColor: AlwaysStoppedAnimation(barColor),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(barVal * 100).toStringAsFixed(0)}% of total',
                              style: TextStyle(
                                fontSize: 10,
                                color: TC.text3(context),
                              ),
                            ),
                            Text(
                              net >= 0
                                  ? 'gets back ${g.sym}${net.toStringAsFixed(2)}'
                                  : 'owes ${g.sym}${net.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: barColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TC.card2(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _calcRow(
                        context,
                        'Total paid',
                        '${g.sym}${paid.toStringAsFixed(2)}',
                        false,
                      ),
                      _calcRow(
                        context,
                        'Fair share (owed)',
                        '-${g.sym}${owes.toStringAsFixed(2)}',
                        false,
                      ),
                      Divider(color: TC.border(context), height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Net balance',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: TC.text(context),
                            ),
                          ),
                          Text(
                            '${net >= 0 ? 'gets back' : 'owes'} ${g.sym}${net.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: net >= 0
                                  ? AppColors.green
                                  : AppColors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.blueDim, Colors.transparent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📊 Minimum transactions to settle',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 8),
              if (plan.isEmpty)
                const Text(
                  'All settled! No payments needed.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.text2,
                  ),
                )
              else
                ...plan.map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text2,
                        ),
                        children: [
                          TextSpan(
                            text: p.from,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: TC.text(context),
                            ),
                          ),
                          const TextSpan(text: ' pays '),
                          TextSpan(
                            text: p.to,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: TC.text(context),
                            ),
                          ),
                          const TextSpan(text: ' → '),
                          TextSpan(
                            text: '${g.sym}${p.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!g.isArchived)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettleUpScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Record a Payment →',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showGroupAnalytics(context, g);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TC.border(context)),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('📊', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Text(
                  'View Group Analytics',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (g.settlements.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'SETTLEMENT HISTORY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.text3,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          ...g.settlements.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text2,
                        ),
                        children: [
                          TextSpan(
                            text: s.from,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: TC.text(context),
                            ),
                          ),
                          const TextSpan(text: ' paid '),
                          TextSpan(
                            text: s.to,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: TC.text(context),
                            ),
                          ),
                          TextSpan(
                            text:
                                ' ${g.sym}${s.amount.toStringAsFixed(2)} via ${s.method}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    s.date,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  void _showGroupAnalytics(BuildContext context, GroupData g) {
    final total = g.expenses.fold(0.0, (s, e) => s + e.amount);

    final Map<String, double> catTotals = {};
    for (final e in g.expenses) {
      catTotals[e.cat] = (catTotals[e.cat] ?? 0) + e.amount;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, double> payerTotals = {};
    for (final e in g.expenses) {
      payerTotals[e.paidBy] = (payerTotals[e.paidBy] ?? 0) + e.amount;
    }
    final sortedPayers = payerTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, double> byDate = {};
    for (final e in g.expenses) {
      final parsedDate = TransactionData.parseDate(e.date);
      if (parsedDate != null) {
        final dStr = '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
        byDate[dStr] = (byDate[dStr] ?? 0) + e.amount;
      }
    }
    final sortedDates = byDate.keys.toList()..sort();
    final spots = <FlSpot>[];
    double maxExp = 0;
    for (int i = 0; i < sortedDates.length; i++) {
      final v = byDate[sortedDates[i]]!;
      if (v > maxExp) maxExp = v;
      spots.add(FlSpot(i.toDouble(), v));
    }
    if (maxExp == 0) maxExp = 1;

    final springCtrl = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 500),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      transitionAnimationController: springCtrl,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TC.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(g.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${g.name} Analytics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: TC.text(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${g.expenses.length} expenses · ${g.sym}${total.toStringAsFixed(2)} total',
              style: TextStyle(fontSize: 13, color: TC.text2(context)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x2200D68F), Color(0x0800D68F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL GROUP SPEND',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: TC.text3(context),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${g.sym}${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'MEMBERS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: TC.text3(context),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        g.members.length.toString(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: TC.text(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (spots.length > 1) ...[
              const SizedBox(height: 24),
              Text(
                'DISTRIBUTION (HISTOGRAM)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TC.text3(context),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                padding: const EdgeInsets.fromLTRB(6, 24, 16, 12),
                decoration: BoxDecoration(
                  color: TC.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TC.border(context)),
                ),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceEvenly,
                    minY: 0,
                    maxY: maxExp * 1.1,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${g.sym}${rod.toY.toStringAsFixed(0)}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxExp / 3 > 0 ? (maxExp / 3) : 1,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: TC.border(context),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (value == 0 || value > maxExp * 1.05) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(right: 6, top: 0),
                              child: Text('${g.sym}${value.toStringAsFixed(0)}', style: TextStyle(color: TC.text3(context), fontSize: 9)),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < sortedDates.length) {
                              final dStr = sortedDates[idx];
                              final d = DateTime.parse(dStr);
                              final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(days[d.weekday - 1], style: TextStyle(color: TC.text2(context), fontSize: 10)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(bottom: BorderSide(color: TC.border(context), width: 1)),
                    ),
                    barGroups: List.generate(spots.length, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: spots[i].y,
                            color: AppColors.green,
                            width: 24, // Wider bars to look like a histogram
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (sortedCats.isNotEmpty) ...[
              Text(
                'SPENDING BY CATEGORY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TC.text3(context),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              ...sortedCats.map((entry) {
                final pct = total > 0 ? entry.value / total : 0.0;
                final catData = AppState.expenseCategories
                    .where((c) => c.icon == entry.key)
                    .firstOrNull;
                final label = catData?.label ?? entry.key;
                final barColor = AppState.getCategoryColor(entry.key);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TC.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TC.border(context)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(entry.key, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: TC.text(context),
                              ),
                            ),
                          ),
                          Text(
                            '${(pct * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: barColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${g.sym}${entry.value.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: TC.text(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: TC.border(context),
                          valueColor: AlwaysStoppedAnimation(barColor),
                          minHeight: 7,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            if (sortedPayers.isNotEmpty) ...[
              Text(
                'TOP PAYERS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TC.text3(context),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              ...sortedPayers.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final payer = entry.value;
                final pct = total > 0 ? payer.value / total : 0.0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TC.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TC.border(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: rank == 1
                              ? AppColors.greenDim
                              : rank == 2
                                  ? AppColors.blueDim
                                  : TC.card2(context),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: rank == 1
                                ? AppColors.green
                                : rank == 2
                                    ? AppColors.blue
                                    : TC.text2(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payer.key,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: TC.text(context),
                              ),
                            ),
                            Text(
                              '${(pct * 100).toStringAsFixed(1)}% of group total',
                              style: TextStyle(
                                fontSize: 11,
                                color: TC.text2(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${g.sym}${payer.value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _calcRow(
    BuildContext context,
    String label,
    String value,
    bool bold,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: bold ? TC.text(context) : TC.text2(context),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? AppColors.green : TC.text(context),
            ),
          ),
        ],
      ),
    );
  }
}
