import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import 'group_detail_screen.dart';

// ─── Unified activity item ────────────────────────────────────────────────────
enum _ActivityKind { personal, groupExpense, settlement }

class _ActivityItem {
  final _ActivityKind kind;
  final String emoji;
  final String title;
  final String subtitle;
  final double amount;
  final bool isPositive;
  final String sym;
  final String? receiptPath;
  final DateTime? date;
  final GroupData? group;

  const _ActivityItem({
    required this.kind,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isPositive,
    required this.sym,
    this.receiptPath,
    this.date,
    this.group,
  });
}

// ─── Filter type ─────────────────────────────────────────────────────────────
enum _Filter { all, personal, groups, settlements }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _Filter _filter = _Filter.all;

  List<_ActivityItem> _buildItems(AppState state) {
    final items = <_ActivityItem>[];

    // Personal transactions
    for (final t in state.transactions) {
      final isInc = t.type == 'income';
      items.add(_ActivityItem(
        kind:       _ActivityKind.personal,
        emoji:      t.cat,
        title:      t.desc,
        subtitle:   '${isInc ? 'Income' : 'Expense'} · ${t.currency} · ${t.date}',
        amount:     t.amount,
        isPositive: isInc,
        sym:        t.sym,
        receiptPath: t.receiptPath,
        date:       t.rawDate,
      ));
    }

    // Group expenses
    for (final g in state.groups) {
      for (final e in g.expenses) {
        final isYou    = e.paidBy == 'You';
        final share    = e.amount / g.members.length;
        final net      = isYou ? (e.amount - share) : -share;
        items.add(_ActivityItem(
          kind:       _ActivityKind.groupExpense,
          emoji:      e.cat,
          title:      e.desc,
          subtitle:   '${g.emoji} ${g.name} · Paid by ${e.paidBy} · ${e.date}',
          amount:     net.abs(),
          isPositive: net >= 0,
          sym:        g.sym,
          receiptPath: e.receiptPath,
          date:       TransactionData.parseDate(e.date),
          group:      g,
        ));
      }

      // Settlements
      for (final s in g.settlements) {
        items.add(_ActivityItem(
          kind:       _ActivityKind.settlement,
          emoji:      '✅',
          title:      '${s.from} paid ${s.to}',
          subtitle:   '${g.emoji} ${g.name} · via ${s.method} · ${s.date}',
          amount:     s.amount,
          isPositive: true,
          sym:        g.sym,
          date:       TransactionData.parseDate(s.date),
          group:      g,
        ));
      }
    }

    // Sort newest first (nulls go to end)
    items.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return items;
  }

  List<_ActivityItem> _applyFilter(List<_ActivityItem> all) {
    switch (_filter) {
      case _Filter.personal:    return all.where((i) => i.kind == _ActivityKind.personal).toList();
      case _Filter.groups:      return all.where((i) => i.kind == _ActivityKind.groupExpense).toList();
      case _Filter.settlements: return all.where((i) => i.kind == _ActivityKind.settlement).toList();
      case _Filter.all:         return all;
    }
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return 'Earlier';
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day   = DateTime(d.year, d.month, d.day);
    final diff  = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff <= 7) return 'This Week';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final transactions = context.select<AppState, List<TransactionData>>((s) => s.transactions);
    final groups       = context.select<AppState, List<GroupData>>((s) => s.groups);
    final state        = context.read<AppState>(); // for currentGroup mutation only
    final isDark       = state.isDark;
    final allItems     = _buildItems(state);
    final filtered     = _applyFilter(allItems);

    // Group by date label — preserve display order
    final Map<String, List<_ActivityItem>> grouped = {};
    final labelOrder = <String>[];
    for (final item in filtered) {
      final label = _dateLabel(item.date);
      if (!grouped.containsKey(label)) {
        grouped[label] = [];
        labelOrder.add(label);
      }
      grouped[label]!.add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FINANCIAL HISTORY',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.green,
                      letterSpacing: 2)),
              const SizedBox(height: 4),
              Text('Activity',
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900,
                      color: TC.text(context), letterSpacing: -0.5)),
              const SizedBox(height: 12),

              // ── Stats row ──────────────────────────────────────────────
              Row(
                children: [
                  _QuickStat(
                    label: 'Transactions',
                    value: '${transactions.length}',
                    color: AppColors.blue,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _QuickStat(
                    label: 'Group expenses',
                    value: '${groups.fold(0, (s, g) => s + g.expenses.length)}',
                    color: AppColors.green,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 10),
                  _QuickStat(
                    label: 'Settlements',
                    value: '${groups.fold(0, (s, g) => s + g.settlements.length)}',
                    color: const Color(0xFFb388ff),
                    isDark: isDark,
                  ),
                ],
              ).animate().fade().slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 100.ms),
              const SizedBox(height: 20),

              // ── Filter chips ───────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _FilterChip(label: 'All',         filter: _Filter.all,         current: _filter, onTap: (f) => setState(() => _filter = f)),
                    _FilterChip(label: '💸 Personal', filter: _Filter.personal,    current: _filter, onTap: (f) => setState(() => _filter = f)),
                    _FilterChip(label: '👥 Groups',   filter: _Filter.groups,      current: _filter, onTap: (f) => setState(() => _filter = f)),
                    _FilterChip(label: '✅ Settled',  filter: _Filter.settlements, current: _filter, onTap: (f) => setState(() => _filter = f)),
                  ],
                ),
              ).animate().fade().slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 200.ms),
            ],
          ),
        ),

        // ── List ──────────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: '📭',
                    title: 'No activity yet',
                    subtitle: _filter == _Filter.all
                        ? 'Add transactions or group expenses to see them here'
                        : 'No ${_filter.name} activity found',
                  ).animate().fade().scale(duration: 400.ms, delay: 300.ms),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: labelOrder.fold<int>(0, (s, l) => s + (grouped[l]!.length + 1)),
                  itemBuilder: (_, rawIndex) {
                    // Flatten grouped sections
                    int idx = rawIndex;
                    for (final label in labelOrder) {
                      if (idx == 0) {
                        return _DateHeader(label: label).animate().fade(duration: 300.ms);
                      }
                      idx--;
                      final section = grouped[label]!;
                      if (idx < section.length) {
                        return _ActivityCard(
                          item: section[idx],
                          isDark: isDark,
                          onTap: () => _onItemTap(context, state, section[idx]),
                        ).animate().fade().slideY(begin: 0.05, end: 0, duration: 300.ms);
                      }
                      idx -= section.length;
                    }
                    return const SizedBox.shrink();
                  },
                ),
        ),
      ],
    );
  }

  void _onItemTap(BuildContext context, AppState state, _ActivityItem item) {
    HapticFeedback.mediumImpact();
    if (item.receiptPath != null) {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => ReceiptViewer(
              imagePath: item.receiptPath!, title: item.title)));
      return;
    }
    if (item.kind == _ActivityKind.groupExpense && item.group != null) {
      state.currentGroup = item.group;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const GroupDetailScreen()));
    }
  }
}

// ─── Quick stat pill ──────────────────────────────────────────────────────────
class _QuickStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
  
  const _QuickStat({
    required this.label, required this.value,
    required this.color, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.25 : 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: TC.text2(context),
                    fontWeight: FontWeight.w600, letterSpacing: 0.2)),
          ],
        ),
      ),
    );
  }
}

// ─── Filter chip ─────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final _Filter filter, current;
  final void Function(_Filter) onTap;
  
  const _FilterChip({
    required this.label, required this.filter,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = filter == current;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(filter); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.greenDim : TC.card(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: active ? AppColors.green : TC.border(context), width: 1.5),
          boxShadow: active ? [
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.black.withValues(alpha: 0.2) 
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? AppColors.green : TC.text2(context),
            )),
      ),
    );
  }
}

// ─── Date section header ──────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: TC.text3(context), letterSpacing: 1.5)),
    );
  }
}

// ─── Activity card ────────────────────────────────────────────────────────────
class _ActivityCard extends StatefulWidget {
  final _ActivityItem item;
  final bool isDark;
  final VoidCallback onTap;
  
  const _ActivityCard({
    required this.item, required this.isDark, required this.onTap,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  double _scale = 1.0;

  Color get _kindColor {
    switch (widget.item.kind) {
      case _ActivityKind.personal:    return AppColors.blue;
      case _ActivityKind.groupExpense: return AppColors.green;
      case _ActivityKind.settlement:  return const Color(0xFFb388ff);
    }
  }

  String get _kindLabel {
    switch (widget.item.kind) {
      case _ActivityKind.personal:    return 'Personal';
      case _ActivityKind.groupExpense: return 'Group';
      case _ActivityKind.settlement:  return 'Settled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTapDown:   (_) { setState(() => _scale = 0.97); },
      onTapUp:     (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TC.border(context)),
            boxShadow: [
              BoxShadow(
                color: widget.isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              // Emoji
              EmojiBox(emoji: item.emoji, size: 48, borderRadius: 14),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15,
                            color: TC.text(context)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(item.subtitle,
                        style: TextStyle(fontSize: 12, color: TC.text2(context), fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kindColor.withValues(alpha: widget.isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kindColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(_kindLabel,
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: _kindColor)),
                        ),
                        if (item.receiptPath != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: widget.isDark ? 0.15 : 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
                            ),
                            child: const Text('📎 receipt',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: AppColors.blue)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.isPositive ? '+' : '-'}${item.sym}${AppCurrencyUtils.formatAmount(item.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16,
                      color: item.kind == _ActivityKind.settlement
                          ? const Color(0xFFb388ff)
                          : item.isPositive ? AppColors.green : AppColors.red,
                    ),
                  ),
                  if (item.kind == _ActivityKind.groupExpense && item.group != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('tap to open →',
                          style: TextStyle(fontSize: 10, color: TC.text3(context), fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
