import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/app_utils.dart';
import '../../main.dart';
import '../add_expense_screen.dart';

class GroupExpensesTab extends StatefulWidget {
  final GroupData g;
  final AppState state;
  final bool isArchived;
  final String searchQuery;
  final String selectedCategory;
  const GroupExpensesTab({
    super.key,
    required this.g,
    required this.state,
    required this.isArchived,
    this.searchQuery = '',
    this.selectedCategory = '',
  });

  @override
  State<GroupExpensesTab> createState() => _GroupExpensesTabState();
}

class _GroupExpensesTabState extends State<GroupExpensesTab> {
  String _getDateLabel(String dStr) {
    final now = DateTime.now();
    final dParts = dStr.split('-');
    if (dParts.length != 3) return dStr;
    final d = DateTime(int.tryParse(dParts[0]) ?? now.year, int.tryParse(dParts[1]) ?? now.month, int.tryParse(dParts[2]) ?? now.day);
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) return 'Yesterday';
    
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month-1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final state = widget.state;
    final isArchived = widget.isArchived;
    final searchQuery = widget.searchQuery;
    final selectedCategory = widget.selectedCategory;

    final expenses = g.expenses.where((e) {
      final matchesSearch = searchQuery.isEmpty ||
          e.desc.toLowerCase().contains(searchQuery) ||
          e.cat.toLowerCase().contains(searchQuery) ||
          e.paidBy.toLowerCase().contains(searchQuery);
      final matchesCat = selectedCategory.isEmpty || e.cat == selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();
    
    if (g.expenses.isEmpty) {
      return const _AnimatedEmptyState(
        icon: '🧾',
        title: 'No expenses yet',
        subtitle: 'Tap + Add to split your first bill',
      );
    }
    if (expenses.isEmpty) {
      return const EmptyState(
        icon: '🔍',
        title: 'No results',
        subtitle: 'Try a different search term or category',
      );
    }

    final grouped = <String, List<ExpenseData>>{};
    for (final e in expenses) {
      final lbl = _getDateLabel(e.date);
      grouped.putIfAbsent(lbl, () => []).add(e);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
      itemCount: grouped.length,
      itemBuilder: (_, i) {
        final dateLabel = grouped.keys.elementAt(i);
        final list = grouped[dateLabel]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 12, top: i > 0 ? 12.0 : 0.0),
              child: Text(
                dateLabel,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TC.text(context)),
              ),
            ),
            ...list.map((e) {
              final isYou = e.paidBy == 'You';
              final myShare = (e.splits != null && e.splits!.containsKey('You'))
                  ? e.splits!['You']!
                  : e.amount / g.members.length;
              final net = isYou ? (e.amount - myShare) : -myShare;
              
              return _TappableExpenseCard(
                e: e,
                g: g,
                net: net,
                state: state,
                isArchived: isArchived,
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

class _TappableExpenseCard extends StatefulWidget {
  final ExpenseData e;
  final GroupData g;
  final double net;
  final AppState state;
  final bool isArchived;
  const _TappableExpenseCard({
    required this.e,
    required this.g,
    required this.net,
    required this.state,
    required this.isArchived,
  });

  @override
  State<_TappableExpenseCard> createState() => _TappableExpenseCardState();
}

class _TappableExpenseCardState extends State<_TappableExpenseCard> {
  void _onLongPress() {
    if (widget.isArchived) return;
    HapticFeedback.mediumImpact();
    final springCtrl = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 450),
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      transitionAnimationController: springCtrl,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TC.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.e.desc,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: TC.text(context),
              ),
            ),
            Text(
              '${widget.g.sym}${widget.e.amount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 13, color: TC.text2(context)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('✏️', style: TextStyle(fontSize: 22)),
              title: const Text(
                'Edit Expense',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                widget.state.currentGroup = widget.g;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(existing: widget.e),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Text('🗑', style: TextStyle(fontSize: 22)),
              title: const Text(
                'Delete Expense',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.red,
                ),
              ),
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.card(context),
        title: Text(
          'Delete expense?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: TC.text(context),
          ),
        ),
        content: Text(
          'Delete "${widget.e.desc}"? This cannot be undone.',
          style: TextStyle(color: TC.text2(context)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: TC.text2(context)),
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              widget.state.deleteExpense(widget.g, widget.e);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _onLongPress,
      onTap: _onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TC.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.greenDim, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(widget.e.cat, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.e.desc,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(context)),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.e.paidBy} paid',
                    style: TextStyle(fontSize: 12, color: TC.text2(context)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${widget.g.sym}${widget.e.amount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: TC.text(context)),
                ),
                const SizedBox(height: 4),
                if (widget.net > 0)
                  Text('Gets back ${widget.g.sym}${widget.net.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600))
                else if (widget.net < 0)
                  Text('You owe ${widget.g.sym}${widget.net.abs().toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.red, fontWeight: FontWeight.w600))
                else
                  const Text('Not involved', style: TextStyle(fontSize: 12, color: AppColors.text3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedEmptyState extends StatefulWidget {
  final String icon, title, subtitle;
  const _AnimatedEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_AnimatedEmptyState> createState() => _AnimatedEmptyStateState();
}

class _AnimatedEmptyStateState extends State<_AnimatedEmptyState>
    with TickerProviderStateMixin {
  late AnimationController _orbitCtrl;

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: AnimatedBuilder(
              animation: _orbitCtrl,
              builder: (_, __) {
                final bob = math.sin(_orbitCtrl.value * math.pi * 2) * 5;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, bob),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: TC.card2(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: TC.border(context),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.icon,
                          style: const TextStyle(fontSize: 30),
                        ),
                      ),
                    ),
                    _OrbitDot(
                      angle: _orbitCtrl.value * math.pi * 2,
                      radius: 44,
                      color: AppColors.green,
                      size: 7,
                    ),
                    _OrbitDot(
                      angle: _orbitCtrl.value * math.pi * 2 + math.pi * 2 / 3,
                      radius: 44,
                      color: AppColors.blue,
                      size: 6,
                    ),
                    _OrbitDot(
                      angle: _orbitCtrl.value * math.pi * 2 + math.pi * 4 / 3,
                      radius: 44,
                      color: AppColors.yellow,
                      size: 6,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: TC.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: TC.text2(context)),
          ),
        ],
      ),
    );
  }
}

class _OrbitDot extends StatelessWidget {
  final double angle, radius, size;
  final Color color;
  const _OrbitDot({
    required this.angle,
    required this.radius,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final x = math.cos(angle) * radius;
    final y = math.sin(angle) * radius;
    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
