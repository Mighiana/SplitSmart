import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import 'add_expense_screen.dart';
import 'add_transaction_screen.dart';
import 'new_group_screen.dart';

/// Shown when the user taps "+ Add Transaction" — lets them pick
/// Group Expense or Personal Transaction before proceeding.
class TransactionTypeScreen extends StatelessWidget {
  const TransactionTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
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
                  Text('Add Transaction',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700,
                          color: TC.text(context))),
                ],
              ),
              const SizedBox(height: 40),

              // ── Title ───────────────────────────────────────────────
              Text('What would you\nlike to record?',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800,
                      color: TC.text(context), height: 1.15)),
              const SizedBox(height: 8),
              Text('Choose the type of transaction below',
                  style: TextStyle(fontSize: 14, color: TC.text2(context))),
              const SizedBox(height: 40),

              // ── Group Expense card ───────────────────────────────────
              _TypeCard(
                icon: '👥',
                title: 'Group Expense',
                subtitle: 'Split a bill with your group.\nBalances are calculated automatically.',
                color: AppColors.green,
                dimColor: AppColors.greenDim,
                onTap: () => _pickGroup(context),
              ),
              const SizedBox(height: 16),

              // ── Personal card ────────────────────────────────────────
              _TypeCard(
                icon: '💸',
                title: 'Personal Transaction',
                subtitle: 'Track your own income & expenses.\nAttach receipts and set budgets.',
                color: AppColors.blue,
                dimColor: AppColors.blueDim,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickGroup(BuildContext context) {
    HapticFeedback.lightImpact();
    final state = context.read<AppState>();
    final groups = state.activeGroups;

    if (groups.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: TC.card(ctx),
          title: Text('No groups yet',
              style: TextStyle(color: TC.text(ctx), fontWeight: FontWeight.w700)),
          content: Text('Create a group first to split expenses.',
              style: TextStyle(color: TC.text2(ctx))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Later', style: TextStyle(color: TC.text2(ctx))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NewGroupScreen()));
              },
              child: const Text('Create Group',
                  style: TextStyle(color: AppColors.green)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _GroupPickerSheet(
        groups: groups,
        onGroupSelected: (g) {
          state.currentGroup = g;
          Navigator.pop(ctx);
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
        },
      ),
    );
  }
}

// ─── Type Choice Card ─────────────────────────────────────────────────────────
class _TypeCard extends StatefulWidget {
  final String icon, title, subtitle;
  final Color color, dimColor;
  final VoidCallback onTap;
  const _TypeCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.dimColor, required this.onTap,
  });

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { HapticFeedback.lightImpact(); setState(() => _scale = 0.97); },
      onTapUp:   (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: TC.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TC.border(context), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: widget.dimColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(widget.icon, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: TC.text(context))),
                    const SizedBox(height: 4),
                    Text(widget.subtitle,
                        style: TextStyle(
                            fontSize: 12, color: TC.text2(context), height: 1.4)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: widget.color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Group Picker Sheet ────────────────────────────────────────────────────────
class _GroupPickerSheet extends StatelessWidget {
  final List<GroupData> groups;
  final void Function(GroupData) onGroupSelected;
  const _GroupPickerSheet({required this.groups, required this.onGroupSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: TC.border(context),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Select Group',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: TC.text(context))),
          Text('Choose which group this expense belongs to',
              style: TextStyle(fontSize: 13, color: TC.text2(context))),
          const SizedBox(height: 20),
          ...groups.map((g) => GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onGroupSelected(g); },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TC.border(context)),
              ),
              child: Row(
                children: [
                  Text(g.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14,
                                color: TC.text(context))),
                        Text('${g.members.length} members · ${g.currency}',
                            style: TextStyle(fontSize: 12, color: TC.text2(context))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.green, size: 20),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
