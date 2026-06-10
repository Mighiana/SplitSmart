import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/app_utils.dart';
import '../../utils/icon_map.dart';
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

  Color _getAvatarBg(String name) {
    final char = name.isNotEmpty ? name.toLowerCase()[0] : 'a';
    if (char == 'y') return const Color(0xFFFFEDEE);
    if (char == 'o') return const Color(0xFFE7F3F0);
    if (char == 'r') return const Color(0xFFFFF3EB);
    if (char == 'l') return const Color(0xFFEEF0FF);
    if (char == 'u') return const Color(0xFFFFF8E0);
    final colors = [const Color(0xFFE7F3F0), const Color(0xFFFFEDEE), const Color(0xFFFFF3EB), const Color(0xFFEEF0FF), const Color(0xFFFFF8E0)];
    return colors[name.hashCode % colors.length];
  }

  Color _getAvatarColor(String name) {
    final char = name.isNotEmpty ? name.toLowerCase()[0] : 'a';
    if (char == 'y') return const Color(0xFFE85A6A);
    if (char == 'o') return const Color(0xFF0A5D5F);
    if (char == 'r') return const Color(0xFFE07A00);
    if (char == 'l') return const Color(0xFF5B6CF8);
    if (char == 'u') return const Color(0xFFC09000);
    final colors = [const Color(0xFF0A5D5F), const Color(0xFFE85A6A), const Color(0xFFE07A00), const Color(0xFF5B6CF8), const Color(0xFFC09000)];
    return colors[name.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final state = widget.state;
    final total = g.expenses.fold(0.0, (s, e) => s + e.amount);
    final perPerson = g.members.isEmpty ? 0.0 : total / g.members.length;
    final plan = state.buildSettlePlan(g);
    
    // Find who paid most
    double maxPaid = 0.0;
    String paidMostMember = '';
    for (final m in g.members) {
      double paid = 0;
      for (final e in g.expenses) {
        if (e.paidBy == m) paid += e.amount;
      }
      if (paid > maxPaid) {
        maxPaid = paid;
        paidMostMember = m;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      children: [
        // GROUP SUMMARY
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TC.card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TC.border(context)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Group summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(context))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: const Text('💰', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text('Total expenses', style: TextStyle(fontSize: 11, color: TC.text2(context), fontWeight: FontWeight.w500)),
                            const SizedBox(height: 3),
                            Text('${g.sym}${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: TC.text(context), letterSpacing: -0.5)),
                          ],
                        ),
                        Container(width: 1, height: 32, color: TC.border(context)),
                        Column(
                          children: [
                            Text('People', style: TextStyle(fontSize: 11, color: TC.text2(context), fontWeight: FontWeight.w500)),
                            const SizedBox(height: 3),
                            Text('${g.members.length}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: TC.text(context), letterSpacing: -0.5)),
                          ],
                        ),
                        Container(width: 1, height: 32, color: TC.border(context)),
                        Column(
                          children: [
                            Text('Each should pay', style: TextStyle(fontSize: 11, color: TC.text2(context), fontWeight: FontWeight.w500)),
                            const SizedBox(height: 3),
                            Text('${g.sym}${perPerson.toStringAsFixed(2)}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.green, letterSpacing: -0.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // INDIVIDUAL BREAKDOWN
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Individual breakdown',
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1E),
              letterSpacing: -0.3,
              decoration: TextDecoration.underline,
              decorationColor: Color(0x591DBF73),
            ),
          ),
        ),
        const SizedBox(height: 10),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: g.members.map((m) {
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
              final isYou = m == 'You';
              final isPaidMost = maxPaid > 0 && paid == maxPaid && paidMostMember == m;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: TC.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TC.border(context)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 8, offset: const Offset(0, 1))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: _getAvatarBg(m), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(m.isNotEmpty ? m.substring(0, 1).toUpperCase() : '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _getAvatarColor(m))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(m, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TC.text(context))),
                              if (isYou || isPaidMost) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isYou ? const Color(0xFFFFEDEE) : const Color(0xFFE7F3F0),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isYou ? 'You' : 'Paid most',
                                    style: TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w700,
                                      color: isYou ? const Color(0xFFE85A6A) : const Color(0xFF0A5D5F),
                                    ),
                                  ),
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 7),
                          Container(
                            height: 7,
                            decoration: BoxDecoration(color: const Color(0xFFF0F0F3), borderRadius: BorderRadius.circular(99)),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: (net >= 0 && paid > 0) 
                                      ? [const Color(0xFF0D7377), const Color(0xFF0A5D5F)]
                                      : [const Color(0xFFF0A0AA), const Color(0xFFE85A6A)],
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${g.sym}${paid.toStringAsFixed(2)} paid', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(
                          net == 0 ? 'settled' : (net > 0 ? 'gets back ${g.sym}${net.toStringAsFixed(2)}' : 'owes ${g.sym}${net.abs().toStringAsFixed(2)}'),
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: net == 0 ? const Color(0xFF8E8E93) : (net > 0 ? const Color(0xFF0D7377) : const Color(0xFFE85A6A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Color(0xFFD0D0D5), size: 18),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 10),

        // SUGGESTED SETTLEMENTS
        if (plan.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: TC.border(context)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: const Color(0xFFE7F3F0), borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.compare_arrows_rounded, color: Color(0xFF0D7377)),
                    ),
                    const SizedBox(width: 10),
                    Text('Suggested settlements', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(context))),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFE7F3F0), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Minimize', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0D7377))),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...plan.map((p) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: p == plan.last ? Colors.transparent : const Color(0xFFF5F6F8))),
                    ),
                    child: Row(
                      children: [
                        ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(p.from, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TC.text(context))),
                      ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF8E8E93)),
                        ),
                        Expanded(child: Text(p.to, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TC.text(context)))),
                        Text('${g.sym}${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.green)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 10),

        // STICKY BOTTOM BUTTONS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (!g.isArchived)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettleUpScreen()));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF0D7377), Color(0xFF0A5D5F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x611DBF73), blurRadius: 28, offset: Offset(0, 8))],
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, color: Colors.white, size: 18),
                        SizedBox(width: 9),
                        Text('Record Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        SizedBox(width: 9),
                        Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                      ],
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
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x611DBF73), width: 1.8),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, color: Color(0xFF0D7377), size: 18),
                      SizedBox(width: 8),
                      Text('View Group Analytics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D7377))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
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
                Icon(iconForEmoji(g.emoji), size: 26, color: AppColors.green),
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
              // View All Transactions Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  _showAllGroupTransactions(context, g);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: TC.card(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📋', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text('View All Transactions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.green)),
                    ],
                  ),
                ),
              ),
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

  // _calcRow: was dead code — never called, removed to eliminate analyzer warning.

  void _showAllGroupTransactions(BuildContext context, GroupData g) {
    // The group detail screen already has an expenses tab, but since we are 
    // inside the group detail screen (on the breakdown tab), we can just 
    // tell the parent GroupDetailScreen to switch tabs. However, we don't have
    // direct access to the parent state. 
    // Instead, we can push a new simple screen that just shows the expenses list.
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: TC.bg(context),
      appBar: AppBar(
        backgroundColor: TC.bg(context),
        elevation: 0,
        title: Text('${g.name} Transactions', style: TextStyle(color: TC.text(context), fontSize: 16, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: TC.text(context)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: g.expenses.length,
        itemBuilder: (ctx, i) {
          final e = g.expenses[i];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TC.border(context)),
            ),
            child: Row(
              children: [
                EmojiBox(emoji: e.cat, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.desc, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: TC.text(context))),
                      const SizedBox(height: 4),
                      Text('Paid by ${e.paidBy} · ${TransactionData.formatDate(e.date)}', style: TextStyle(color: TC.text2(context), fontSize: 11)),
                    ],
                  ),
                ),
                Text('${g.sym}${e.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.green)),
              ],
            ),
          );
        },
      ),
    )));
  }
}
