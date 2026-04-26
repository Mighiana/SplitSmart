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
  void _onLongPress() => _showExpenseDetail(context);

  void _showExpenseDetail(BuildContext context) {
    if (widget.isArchived) return;
    HapticFeedback.mediumImpact();
    final e = widget.e;
    final g = widget.g;
    final isAuthor = e.createdBy == null || e.createdBy == 'You';
    final memberAmounts = <String, double>{};
    for (final m in g.members) {
      memberAmounts[m] = (e.splits != null && e.splits!.containsKey(m))
          ? e.splits![m]!
          : (g.members.isEmpty ? 0 : e.amount / g.members.length);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            // Header
            Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.greenDim, shape: BoxShape.circle), alignment: Alignment.center, child: Text(e.cat, style: const TextStyle(fontSize: 26))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.desc, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context))),
                const SizedBox(height: 2),
                Text('${g.sym}${e.amount.toStringAsFixed(2)} · ${e.date}', style: TextStyle(fontSize: 13, color: TC.text2(context))),
              ])),
            ]),
            const SizedBox(height: 14),
            // Paid by
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.green.withValues(alpha: 0.25))),
              child: Row(children: [
                AvatarCircle(label: e.paidBy, size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text('${e.paidBy} paid', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green))),
                Text('${g.sym}${e.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green, fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 16),
            Text('WHO OWES WHAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: TC.text3(context), letterSpacing: 2)),
            const SizedBox(height: 8),
            ...g.members.map((m) {
              final owes = memberAmounts[m] ?? 0;
              final isPayer = m == e.paidBy;
              final net = isPayer ? (e.amount - owes) : -owes;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: TC.border(context))),
                child: Row(children: [
                  AvatarCircle(label: m, size: 32),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: TC.text(context))),
                    Text(isPayer ? 'Paid the bill' : 'Share: ${g.sym}${owes.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: TC.text2(context))),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: net >= 0 ? AppColors.greenDim : AppColors.redDim, borderRadius: BorderRadius.circular(8)),
                    child: Text(net >= 0 ? 'gets back ${g.sym}${net.toStringAsFixed(2)}' : 'owes ${g.sym}${net.abs().toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: net >= 0 ? AppColors.green : AppColors.red)),
                  ),
                ]),
              );
            }),
            if (e.createdBy != null) ...[
              const SizedBox(height: 6),
              Text(e.updatedBy != null ? '✏️ Edited by ${e.updatedBy}' : '👤 Added by ${e.createdBy}',
                  style: TextStyle(fontSize: 11, color: TC.text3(context))),
            ],
            const SizedBox(height: 16),
            Divider(color: TC.border(context)),
            if (!isAuthor)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Only the author (${e.createdBy}) can edit this expense.',
                    style: TextStyle(color: TC.text3(context), fontSize: 13), textAlign: TextAlign.center),
              )
            else ...[
              ListTile(
                leading: const Text('✏️', style: TextStyle(fontSize: 22)),
                title: const Text('Edit Expense', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  widget.state.currentGroup = widget.g;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(existing: e)));
                },
              ),
              ListTile(
                leading: const Text('🗑', style: TextStyle(fontSize: 22)),
                title: const Text('Delete Expense', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.red)),
                onTap: () { HapticFeedback.heavyImpact(); Navigator.pop(context); _confirmDelete(context); },
              ),
            ],
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
                  if (widget.e.createdBy != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.e.updatedBy != null
                          ? '✏️ Edited by ${widget.e.updatedBy}'
                          : '👤 Added by ${widget.e.createdBy}',
                      style: TextStyle(fontSize: 10, color: TC.text3(context)),
                    ),
                  ],
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
