import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';

class GoalDetailScreen extends StatelessWidget {
  final SavingGoal goal;
  final VoidCallback onDeposit;
  final VoidCallback onEdit;

  const GoalDetailScreen({
    super.key,
    required this.goal,
    required this.onDeposit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final g = context.watch<AppState>().savingGoals.firstWhere(
      (x) => x.id == goal.id,
      orElse: () => goal,
    );
    final progress = g.targetAmount > 0 ? (g.savedAmount / g.targetAmount).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();
    final remaining = (g.targetAmount - g.savedAmount).clamp(0.0, double.infinity);
    final isCompleted = g.savedAmount >= g.targetAmount;
    final monthsLeft = g.targetDate != null
        ? ((g.targetDate!.difference(DateTime.now()).inDays) / 30.0).ceil()
        : 0;
    final monthlyNeeded = monthsLeft > 0 ? (remaining / monthsLeft) : 0.0;
    final targetDateStr = g.targetDate != null
        ? '${_monthName(g.targetDate!.month)} ${g.targetDate!.year}'
        : 'No date set';

    return Scaffold(
      backgroundColor: TC.bg(context),
      appBar: AppBar(
        backgroundColor: TC.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: TC.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text('Goals', style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w800, fontSize: 20)),
            Text('Track your saving goals', style: TextStyle(color: TC.text3(context), fontSize: 12)),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.green, width: 1.5),
            ),
            child: const Icon(Icons.add, color: AppColors.green, size: 18),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main goal card
            _card(isDark, context, child: Column(
              children: [
                Row(
                  children: [
                    _goalIcon(g, isDark),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context))),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.calendar_today, size: 12, color: TC.text3(context)),
                          const SizedBox(width: 4),
                          Text('Target date: $targetDateStr', style: TextStyle(fontSize: 12, color: TC.text3(context))),
                        ]),
                      ],
                    )),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$percent%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.green)),
                        Text('of goal', style: TextStyle(fontSize: 11, color: TC.text3(context))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats row — use FittedBox to prevent overflow on large numbers
                Row(
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                          child: Text(AppCurrencyUtils.formatAmount(g.savedAmount),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.green))),
                        Text('${g.currency} Saved', style: TextStyle(fontSize: 11, color: TC.text3(context))),
                      ],
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        FittedBox(fit: BoxFit.scaleDown,
                          child: Text(AppCurrencyUtils.formatAmount(g.targetAmount),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: TC.text(context)))),
                        Text('${g.currency} Target', style: TextStyle(fontSize: 11, color: TC.text3(context))),
                      ],
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight,
                          child: Text(AppCurrencyUtils.formatAmount(remaining),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: TC.text(context)))),
                        Text('${g.currency} Remaining', style: TextStyle(fontSize: 11, color: TC.text3(context))),
                      ],
                    )),
                  ],
                ),

                const SizedBox(height: 14),
                // Progress bar with floating % pill inside the fill
                LayoutBuilder(builder: (_, constraints) {
                  final fillWidth = (constraints.maxWidth * progress).clamp(0.0, constraints.maxWidth);
                  return SizedBox(
                    height: 24,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        // Track
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8E8E8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        // Fill
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          width: fillWidth.clamp(4.0, double.infinity),
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isCompleted
                                  ? [const Color(0xFF3B82F6), const Color(0xFF6366F1)]
                                  : [AppColors.green, const Color(0xFF00B87C)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        // Floating % pill inside fill (only if fill >= 28px)
                        if (fillWidth >= 28)
                          Positioned(
                            left: 0,
                            width: fillWidth,
                            child: Center(
                              child: Text(
                                '$percent%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        else if (percent > 0)
                          // Show pill floating to the right of fill when fill is too small
                          Positioned(
                            left: fillWidth + 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$percent%',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 10),
                Container(height: 1, color: TC.border(context)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(
                      color: isCompleted ? const Color(0xFF3B82F6) : AppColors.green,
                      shape: BoxShape.circle,
                    )),
                    const SizedBox(width: 6),
                    Text(isCompleted ? 'Completed' : 'On track', style: TextStyle(
                      fontSize: 13, color: isCompleted ? const Color(0xFF3B82F6) : AppColors.green, fontWeight: FontWeight.w600,
                    )),
                    const Spacer(),
                    Flexible(child: Text(
                      isCompleted ? 'Goal reached!' : "Great! You're on track to reach your goal.",
                      style: TextStyle(fontSize: 12, color: TC.text3(context)),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16, color: TC.text3(context)),
                  ],
                ),
              ],
            )),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                _actionBtn(context, isDark, Icons.add_circle_outline, 'Add Money', onDeposit),
                const SizedBox(width: 10),
                _actionBtn(context, isDark, Icons.edit_outlined, 'Edit Goal', onEdit),
                const SizedBox(width: 10),
                _actionBtn(context, isDark, Icons.history, 'History', () => _showHistory(context, isDark, g)),
              ],
            ),
            const SizedBox(height: 12),
            // Stay on track
            if (!isCompleted && monthsLeft > 0) Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.green.withValues(alpha: 0.08) : const Color(0xFFEAF7F1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('🎯', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stay on track', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(context))),
                      const SizedBox(height: 2),
                      RichText(text: TextSpan(
                        style: TextStyle(fontSize: 12, color: TC.text2(context), height: 1.4),
                        children: [
                          const TextSpan(text: 'Save '),
                          TextSpan(text: '${g.currency} ${AppCurrencyUtils.formatAmount(monthlyNeeded)}', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                          TextSpan(text: ' more each month\nto reach your goal by $targetDateStr.'),
                        ],
                      )),
                    ],
                  )),
                  const SizedBox(width: 8),
                  SizedBox(width: 56, height: 44, child: CustomPaint(painter: _ChartUpPainter(isDark: isDark))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(bool isDark, BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        border: isDark ? Border.all(color: TC.border(context)) : null,
      ),
      child: child,
    );
  }

  Widget _goalIcon(SavingGoal g, bool isDark) {
    final emoji = _getEmoji(g.title);
    const colors = [Color(0xFFEDE9FE), Color(0xFFDBEAFE), Color(0xFFDCFCE7), Color(0xFFFFEDD5), Color(0xFFFEE2E2)];
    final bg = colors[g.id % colors.length];
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: isDark ? bg.withValues(alpha: 0.2) : bg),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
    );
  }


  Widget _actionBtn(BuildContext context, bool isDark, IconData icon, String label, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: TC.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
          border: isDark ? Border.all(color: TC.border(context)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.green),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TC.text(context))),
          ],
        ),
      ),
    ));
  }

  void _showHistory(BuildContext context, bool isDark, SavingGoal g) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          // Always re-fetch live goal so edits are immediately reflected
          final liveGoal = context.read<AppState>().savingGoals
              .firstWhere((x) => x.id == g.id, orElse: () => g);
          final deposits = liveGoal.deposits.isNotEmpty
              ? liveGoal.deposits
              : [if (liveGoal.savedAmount > 0)
                  GoalDeposit(amount: liveGoal.savedAmount, date: DateTime.now(), note: 'Initial deposit')];

          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, ctrl) => Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: TC.border(context), borderRadius: BorderRadius.circular(2),
                )),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppColors.green, size: 20),
                      const SizedBox(width: 8),
                      Text('Deposit History', style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context),
                      )),
                      const Spacer(),
                      Text('${deposits.length} entries',
                        style: TextStyle(fontSize: 12, color: TC.text3(context))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: deposits.isEmpty
                      ? Center(child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.savings_outlined, size: 48, color: TC.text3(context)),
                            const SizedBox(height: 8),
                            Text('No deposits yet', style: TextStyle(color: TC.text3(context))),
                          ],
                        ))
                      : ListView.separated(
                          controller: ctrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: deposits.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: TC.border(context)),
                          itemBuilder: (_, i) {
                            final realIdx = deposits.length - 1 - i; // newest first
                            final d = deposits[realIdx];
                            final dt = d.date;
                            final dateStr = '${dt.day.toString().padLeft(2,'0')} '
                                '${_monthName(dt.month)} ${dt.year}';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              leading: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_downward_rounded,
                                  color: AppColors.green, size: 18),
                              ),
                              title: Text(
                                '+ ${liveGoal.currency} ${AppCurrencyUtils.formatAmount(d.amount)}',
                                style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: AppColors.green,
                                ),
                              ),
                              subtitle: Text(
                                d.note.isNotEmpty ? '${d.note} · $dateStr' : dateStr,
                                style: TextStyle(fontSize: 12, color: TC.text3(context)),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.edit_outlined, size: 18, color: TC.text3(context)),
                                onPressed: () => _editDeposit(context, sheetCtx, liveGoal, realIdx, setSheetState),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _editDeposit(BuildContext context, BuildContext sheetCtx, SavingGoal g, int depositIdx, StateSetter setSheetState) {
    final d = g.deposits[depositIdx];
    final ctrl = TextEditingController(text: d.amount.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: TC.card(context),
        title: Text('Edit Deposit', style: TextStyle(fontWeight: FontWeight.w800, color: TC.text(context))),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (${g.currency})',
            labelStyle: TextStyle(color: TC.text2(context)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.green),
            ),
          ),
          style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w700),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel', style: TextStyle(color: TC.text3(context))),
          ),
          TextButton(
            onPressed: () async {
              final newAmt = double.tryParse(ctrl.text.replaceAll(',', ''));
              if (newAmt == null || newAmt <= 0) return;
              final oldAmt = d.amount;
              final diff = newAmt - oldAmt;
              // Build updated deposits list
              final updated = List<GoalDeposit>.from(g.deposits);
              updated[depositIdx] = GoalDeposit(amount: newAmt, date: d.date, note: d.note);
              // Update goal with new saved total and updated deposits
              await context.read<AppState>().updateSavingGoal(g,
                savedAmount: (g.savedAmount + diff).clamp(0, double.infinity),
                deposits: updated,
              );
              if (dCtx.mounted) Navigator.pop(dCtx);
              setSheetState(() {}); // refresh sheet
            },
            child: const Text('Save', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }



  static String _getEmoji(String t) {
    final l = t.toLowerCase();
    if (l.contains('car') || l.contains('vehicle')) return '🚗';
    if (l.contains('home') || l.contains('house')) return '🏠';
    if (l.contains('vacation') || l.contains('trip') || l.contains('travel')) return '✈️';
    if (l.contains('emergency')) return '🛡️';
    if (l.contains('gadget') || l.contains('tech') || l.contains('phone')) return '📱';
    return '🎯';
  }

  static String _monthName(int m) {
    const n = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return (m >= 1 && m <= 12) ? n[m - 1] : '';
  }
}

class _ChartUpPainter extends CustomPainter {
  final bool isDark;
  _ChartUpPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 60, sy = size.height / 50;
    canvas.scale(sx, sy);
    final bars = [
      [4.0, 34.0, 10.0, 12.0, const Color(0xFFB8E8D0)],
      [18.0, 26.0, 10.0, 20.0, const Color(0xFF7DD4A8)],
      [32.0, 16.0, 10.0, 30.0, const Color(0xFF3DB87A)],
      [46.0, 8.0, 10.0, 38.0, const Color(0xFF1DB87A)],
    ];
    for (final b in bars) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(b[0] as double, b[1] as double, b[2] as double, b[3] as double), const Radius.circular(3)),
        Paint()..color = b[4] as Color,
      );
    }
    final linePaint = Paint()..color = const Color(0xFF1DB87A)..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final path = Path()..moveTo(8, 32)..lineTo(22, 22)..lineTo(36, 13)..lineTo(50, 5);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
