import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'group_detail_screen.dart';

enum _Kind { personal, groupExpense, settlement }

class _Item {
  final _Kind kind;
  final String emoji, title, subtitle, sym;
  final double amount;
  final bool isPositive;
  final String? receiptPath;
  final DateTime? date;
  final GroupData? group;
  const _Item({required this.kind, required this.emoji, required this.title,
    required this.subtitle, required this.amount, required this.isPositive,
    required this.sym, this.receiptPath, this.date, this.group});
}

enum _Filter { all, personal, groups, settlements }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _Filter _filter = _Filter.all;

  List<_Item> _buildItems(AppState state) {
    final items = <_Item>[];
    for (final t in state.transactions) {
      final isInc = t.type == 'income';
      items.add(_Item(kind: _Kind.personal, emoji: t.cat, title: t.desc,
        subtitle: '${isInc ? 'Income' : 'Expense'} · ${t.currency}',
        amount: t.amount, isPositive: isInc, sym: t.sym,
        receiptPath: t.receiptPath, date: t.rawDate));
    }
    for (final g in state.groups) {
      for (final e in g.expenses) {
        final isYou = e.paidBy == 'You';
        final share = e.amount / g.members.length;
        final net = isYou ? (e.amount - share) : -share;
        items.add(_Item(kind: _Kind.groupExpense, emoji: e.cat, title: e.desc,
          subtitle: '${g.emoji} ${g.name} · ${e.paidBy}',
          amount: net.abs(), isPositive: net >= 0, sym: g.sym,
          receiptPath: e.receiptPath, date: TransactionData.parseDate(e.date), group: g));
      }
      for (final s in g.settlements) {
        items.add(_Item(kind: _Kind.settlement, emoji: 'check', // Icon handled in tile
          title: '${s.from} → ${s.to}', subtitle: '${g.emoji} ${g.name} · ${s.method}',
          amount: s.amount, isPositive: true, sym: g.sym,
          date: TransactionData.parseDate(s.date), group: g));
      }
    }
    items.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return items;
  }

  List<_Item> _applyFilter(List<_Item> all) {
    switch (_filter) {
      case _Filter.personal:    return all.where((i) => i.kind == _Kind.personal).toList();
      case _Filter.groups:      return all.where((i) => i.kind == _Kind.groupExpense).toList();
      case _Filter.settlements: return all.where((i) => i.kind == _Kind.settlement).toList();
      case _Filter.all:         return all;
    }
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff <= 7) return 'This Week';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }


  Color _kindColor(_Kind kind) {
    switch (kind) {
      case _Kind.personal:     return AppColors.blue;
      case _Kind.groupExpense: return AppColors.green;
      case _Kind.settlement:   return AppColors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use watch so the screen rebuilds whenever transactions, groups, or
    // group expenses change — including immediately after sign-in and when
    // other group members add expenses.
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    final l = AppLocalizations.of(context);
    final allItems = _buildItems(state);
    final filtered = _applyFilter(allItems);

    // Group by date
    final Map<String, List<_Item>> grouped = {};
    final labelOrder = <String>[];
    for (final item in filtered) {
      final label = _dateLabel(item.date);
      grouped.putIfAbsent(label, () { labelOrder.add(label); return []; });
      grouped[label]!.add(item);
    }

    // Stats
    final now = DateTime.now();
    int personalCount = 0, groupCount = 0, settlementCount = 0;
    for (final item in allItems) {
      if (item.date != null && item.date!.month == now.month && item.date!.year == now.year) {
        if (item.kind == _Kind.personal) personalCount++;
        else if (item.kind == _Kind.groupExpense) groupCount++;
        else settlementCount++;
      }
    }

    // Build flat list of widgets for sliver
    final sliverChildren = <Widget>[];
    for (int g = 0; g < labelOrder.length; g++) {
      final label = labelOrder[g];
      final section = grouped[label]!;
      sliverChildren.add(_SectionHeader(label: label, count: section.length));
      for (int i = 0; i < section.length; i++) {
        sliverChildren.add(_TransactionTile(
          item: section[i], isDark: isDark,
          kindColor: _kindColor(section[i].kind),
          onTap: () => _onTap(context, state, section[i]),
          delay: (g * 80 + i * 40),
        ));
      }
    }

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.activity,
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                                  color: TC.text(context), letterSpacing: -0.5, height: 1.1)),
                              const SizedBox(height: 2),
                              Text(l.financialTimeline,
                                style: TextStyle(fontSize: 13, color: TC.text3(context), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        // Animated pulse dot
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.greenDim,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6,
                                decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.6), blurRadius: 8)])),
                              const SizedBox(width: 6),
                              Text('${allItems.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.green)),
                            ],
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true))
                         .shimmer(duration: 2000.ms, color: AppColors.green.withValues(alpha: 0.15)),
                      ],
                    ).animate().fade(duration: 300.ms),

                    const SizedBox(height: 20),

                    // ── Glassmorphic stat row ──
                    Row(
                      children: [
                        _GlassStat(icon: Icons.receipt_long_rounded, label: l.personal,
                          value: '$personalCount', color: AppColors.blue, isDark: isDark),
                        const SizedBox(width: 10),
                        _GlassStat(icon: Icons.group_rounded, label: l.group,
                          value: '$groupCount', color: AppColors.green, isDark: isDark),
                        const SizedBox(width: 10),
                        _GlassStat(icon: Icons.handshake_rounded, label: l.settled,
                          value: '$settlementCount', color: AppColors.purple, isDark: isDark),
                      ],
                    ).animate().fade().slideY(begin: 0.08, end: 0, duration: 400.ms, delay: 100.ms),

                    const SizedBox(height: 18),

                    // ── Filter pills ──
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _Pill(label: l.all, active: _filter == _Filter.all,
                            onTap: () => setState(() => _filter = _Filter.all)),
                          _Pill(label: l.personal, icon: Icons.receipt_long_rounded, color: AppColors.blue, active: _filter == _Filter.personal,
                            onTap: () => setState(() => _filter = _Filter.personal)),
                          _Pill(label: l.groups, icon: Icons.group_rounded, color: AppColors.green, active: _filter == _Filter.groups,
                            onTap: () => setState(() => _filter = _Filter.groups)),
                          _Pill(label: l.settled, icon: Icons.handshake_rounded, color: AppColors.purple, active: _filter == _Filter.settlements,
                            onTap: () => setState(() => _filter = _Filter.settlements)),
                        ],
                      ),
                    ).animate().fade().slideY(begin: 0.08, end: 0, duration: 400.ms, delay: 200.ms),

                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),

            // ── Content ──
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: EmptyState(
                    icon: '📭', title: l.noActivityYet,
                    subtitle: _filter == _Filter.all
                      ? l.addActivityHint
                      : 'No ${_filter.name} activity found',
                  ).animate().fade().scale(duration: 400.ms, delay: 300.ms),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => sliverChildren[i],
                    childCount: sliverChildren.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext ctx, AppState state, _Item item) {
    HapticFeedback.mediumImpact();
    if (item.receiptPath != null) {
      Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => ReceiptViewer(imagePath: item.receiptPath!, title: item.title)));
      return;
    }
    if (item.kind == _Kind.groupExpense && item.group != null) {
      state.currentGroup = item.group;
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => const GroupDetailScreen()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLASSMORPHIC STAT CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _GlassStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final bool isDark;
  const _GlassStat({required this.icon, required this.label,
    required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: isDark ? 0.12 : 0.08),
              color.withValues(alpha: isDark ? 0.04 : 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.2 : 0.15)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: isDark ? 0.08 : 0.05),
              blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, height: 1)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: TC.text3(context), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTER PILL
// ═══════════════════════════════════════════════════════════════════════════════
class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  const _Pill({required this.label, required this.active, required this.onTap, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? (color ?? AppColors.green) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? (color ?? AppColors.green) : TC.border(context),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? [
            BoxShadow(color: (color ?? AppColors.green).withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
          ] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: active ? Colors.black : (color ?? TC.text2(context))),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? Colors.black : TC.text2(context),
            )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION HEADER (date divider)
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: TC.text3(context), letterSpacing: 1.8)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: TC.card2(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: TC.text3(context))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 0.5, color: TC.border(context))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRANSACTION TILE — clean, Revolut-style row
// ═══════════════════════════════════════════════════════════════════════════════
class _TransactionTile extends StatefulWidget {
  final _Item item;
  final bool isDark;
  final Color kindColor;
  final VoidCallback onTap;
  final int delay;
  const _TransactionTile({required this.item, required this.isDark,
    required this.kindColor, required this.onTap, required this.delay});

  @override
  State<_TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<_TransactionTile> {
  double _scale = 1.0;

  String _kindTag(_Kind k) {
    final l = AppLocalizations.of(context);
    switch (k) {
      case _Kind.personal:     return l.personal;
      case _Kind.groupExpense: return l.group;
      case _Kind.settlement:   return l.settlement;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final amtColor = item.kind == _Kind.settlement
        ? AppColors.purple
        : item.isPositive ? AppColors.green : AppColors.red;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) { setState(() => _scale = 1.0); widget.onTap(); },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale, duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: TC.border(context).withValues(alpha: 0.4), width: 0.5)),
          ),
          child: Row(
            children: [
              // ── Icon circle with gradient ring ──
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      widget.kindColor.withValues(alpha: widget.isDark ? 0.18 : 0.12),
                      widget.kindColor.withValues(alpha: widget.isDark ? 0.06 : 0.04),
                    ],
                  ),
                  border: Border.all(color: widget.kindColor.withValues(alpha: 0.25), width: 1.5),
                ),
                alignment: Alignment.center,
                child: item.kind == _Kind.settlement
                    ? Icon(Icons.check_circle_rounded, color: widget.kindColor, size: 24)
                    : Text(item.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),

              // ── Title + subtitle + tag ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: TC.text(context), height: 1.2),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        // Kind dot
                        Container(width: 5, height: 5,
                          decoration: BoxDecoration(color: widget.kindColor, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(item.subtitle,
                            style: TextStyle(fontSize: 12, color: TC.text3(context), fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (item.receiptPath != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.blueDim,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.attach_file_rounded, size: 10, color: AppColors.blue),
                                const SizedBox(width: 2),
                                Text(AppLocalizations.of(context).receipt, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.blue)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // ── Amount + arrow ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${item.isPositive ? '+' : '−'}${item.sym}${AppCurrencyUtils.formatAmount(item.amount)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: amtColor, height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(_kindTag(item.kind),
                    style: TextStyle(fontSize: 10, color: widget.kindColor, fontWeight: FontWeight.w600)),
                ],
              ),
              if (item.kind == _Kind.groupExpense && item.group != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 18, color: TC.text3(context)),
              ],
            ],
          ),
        ),
      ).animate().fade(duration: 300.ms, delay: Duration(milliseconds: widget.delay))
       .slideX(begin: 0.02, end: 0, duration: 300.ms),
    );
  }
}
