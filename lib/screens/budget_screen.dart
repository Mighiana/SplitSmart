import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../utils/icon_map.dart';
import 'new_budget_screen.dart';
import 'budget_detail_screen.dart';

/// Budgets list (Phase A) — named budgets with spent/limit progress.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  String _sym(String code) => AppState.currencies
      .firstWhere((c) => c.code == code,
          orElse: () => CurrencyData(code, code, '💰', code))
      .sym;

  String _periodLabel(String p) =>
      p == 'weekly' ? 'Weekly' : p == 'yearly' ? 'Yearly' : 'Monthly';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final budgets = state.budgets;

    return Scaffold(
      backgroundColor: TC.bg(context),
      // Empty state has its own centered CTA — only show the FAB once there
      // are budgets to avoid two identical "New Budget" buttons on one screen.
      floatingActionButton: budgets.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: TC.primary(context),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NewBudgetScreen()));
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Budget',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            Expanded(
              child: budgets.isEmpty
                  ? _emptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: budgets.length,
                      itemBuilder: (_, i) => _budgetCard(context, state, budgets[i])
                          .animate(delay: (i * 60).ms)
                          .fadeIn(duration: 360.ms)
                          .slideY(begin: 0.1, curve: Curves.easeOut),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SPENDING LIMITS', style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: TC.primaryMd(context))),
              Text('Budgets', style: TC.gloock(context, fontSize: 28, color: TC.text(context), letterSpacing: -0.6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 52, color: TC.primary(context)),
            const SizedBox(height: 14),
            Text('No budgets yet', style: TC.gloock(context, fontSize: 20, color: TC.text(context))),
            const SizedBox(height: 6),
            Text('Create a budget to set a spending limit and track it through the month.',
                textAlign: TextAlign.center,
                style: TC.geist(context, fontSize: 13, color: TC.text2(context), height: 1.5)),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () { HapticFeedback.mediumImpact(); Navigator.push(context, MaterialPageRoute(builder: (_) => const NewBudgetScreen())); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                decoration: BoxDecoration(color: TC.primary(context), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: TC.primaryGlow(context), blurRadius: 16, offset: const Offset(0, 6))]),
                child: const Text('+ New Budget', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _budgetCard(BuildContext context, AppState state, Budget b) {
    final spent = state.budgetSpent(b);
    final pct = b.amount > 0 ? (spent / b.amount).clamp(0.0, 1.0) : 0.0;
    final over = spent > b.amount;
    final remaining = b.amount - spent;
    final sym = _sym(b.currency);
    final color = over
        ? TC.er(context)
        : (pct >= 0.8 ? TC.wn(context) : TC.primary(context));
    final catLabel = b.categories.isEmpty
        ? 'All categories'
        : '${b.categories.length} ${b.categories.length == 1 ? 'category' : 'categories'}';

    return Dismissible(
      key: Key('budget_${b.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(color: TC.er(context), borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: TC.card(context),
          title: Text('Delete budget?', style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w700)),
          content: Text('Remove "${b.name}"? This cannot be undone.', style: TextStyle(color: TC.text2(context))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: TC.text3(context)))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: TC.er(context), fontWeight: FontWeight.w700))),
          ],
        ),
      ),
      onDismissed: (_) => state.deleteBudget(b.id),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(context, MaterialPageRoute(builder: (_) => BudgetDetailScreen(budget: b)));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TC.card(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TC.gloock(context, fontSize: 18, color: TC.text(context))),
                        const SizedBox(height: 3),
                        Row(children: [
                          Flexible(child: Text('${_periodLabel(b.period)} · $catLabel', maxLines: 1, overflow: TextOverflow.ellipsis, style: TC.geist(context, fontSize: 11, color: TC.text3(context)))),
                          if (b.categories.isNotEmpty)
                            ...b.categories.take(4).map((k) => Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(iconForEmoji(k), size: 13, color: colorForEmoji(k, fallback: TC.text3(context))),
                                )),
                        ]),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text('${(pct * 100).round()}%', style: TC.geist(context, fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$sym${AppCurrencyUtils.formatAmount(spent, 0)}', style: TC.gloock(context, fontSize: 22, color: TC.text(context), letterSpacing: -0.5)),
                  Text('of $sym${AppCurrencyUtils.formatAmount(b.amount, 0)}', style: TC.geist(context, fontSize: 12, color: TC.text3(context))),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: pct.toDouble(),
                  minHeight: 8,
                  backgroundColor: TC.bg2(context),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                over
                    ? 'Over by $sym${AppCurrencyUtils.formatAmount(spent - b.amount, 0)}'
                    : '$sym${AppCurrencyUtils.formatAmount(remaining, 0)} remaining',
                style: TC.geist(context, fontSize: 12, fontWeight: FontWeight.w600, color: over ? TC.er(context) : TC.ok(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
