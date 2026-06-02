import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'group_detail_screen.dart';

enum _Kind { personal, groupExpense, settlement }

class _Item {
  final _Kind kind;
  final String emoji, title, subtitle, sub2, sym;
  final double amount;
  final bool isPositive;
  final String? receiptPath;
  final DateTime? date;
  final GroupData? group;
  const _Item({
    required this.kind, required this.emoji, required this.title,
    required this.subtitle, required this.sub2, required this.amount, 
    required this.isPositive, required this.sym, 
    this.receiptPath, this.date, this.group,
  });
}

enum _Filter { all, personal, groups, settlements }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _Filter _filter = _Filter.all;
  final Map<String, bool> _expandedGroups = {};
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _availableCategories = const ['All'];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Item> _buildItems(AppState state, AppLocalizations l) {
    final items = <_Item>[];
    for (final t in state.transactions) {
      final isInc = t.type == 'income';
      items.add(_Item(
        kind: _Kind.personal, 
        emoji: t.cat, 
        title: t.desc,
        subtitle: isInc ? l.income : l.expenses,
        sub2: t.currency,
        amount: t.amount, 
        isPositive: isInc, 
        sym: t.sym,
        receiptPath: t.receiptPath, 
        date: t.rawDate,
      ));
    }
    for (final g in state.groups) {
      for (final e in g.expenses) {
        final isYou = e.paidBy == 'You';
        double share;
        if (e.splits != null && e.splits!.isNotEmpty) {
          final rawTotal = e.splits!.values.fold(0.0, (s, v) => s + v);
          final scale = (rawTotal > 0 && (rawTotal - e.amount).abs() > 0.01)
              ? e.amount / rawTotal
              : 1.0;
          share = (e.splits!['You'] ?? (e.amount / g.members.length)) * scale;
        } else {
          share = g.members.isEmpty ? 0 : e.amount / g.members.length;
        }
        final net = isYou ? (e.amount - share) : -share;
        items.add(_Item(
          kind: _Kind.groupExpense, 
          emoji: e.cat, 
          title: e.desc,
          subtitle: '${g.emoji} ${g.name}', 
          sub2: e.paidBy,
          amount: net.abs(), 
          isPositive: net >= 0, 
          sym: g.sym,
          receiptPath: e.receiptPath, 
          date: TransactionData.parseDate(e.date), 
          group: g,
        ));
      }
      for (final s in g.settlements) {
        items.add(_Item(
          kind: _Kind.settlement, 
          emoji: '🤝', 
          title: '${s.from} → ${s.to}', 
          subtitle: l.settled,
          sub2: s.method,
          amount: s.amount, 
          isPositive: true, 
          sym: g.sym,
          date: TransactionData.parseDate(s.date), 
          group: g,
        ));
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
    List<_Item> res = all;
    switch (_filter) {
      case _Filter.personal:    res = all.where((i) => i.kind == _Kind.personal).toList(); break;
      case _Filter.groups:      res = all.where((i) => i.kind == _Kind.groupExpense).toList(); break;
      case _Filter.settlements: res = all.where((i) => i.kind == _Kind.settlement).toList(); break;
      case _Filter.all:         break;
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      res = res.where((i) => i.title.toLowerCase().contains(q) || i.subtitle.toLowerCase().contains(q) || i.sub2.toLowerCase().contains(q)).toList();
    }
    if (_selectedCategory != 'All') {
      res = res.where((i) => i.emoji == _selectedCategory).toList();
    }
    return res;
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _categoryLabel(String emoji) {
    if (emoji == 'All') return 'All';
    switch (emoji) {
      case '🍽️': return '🍽️ Food';
      case '🚕': return '🚕 Travel';
      case '💰': return '💰 Income';
      case '🏠': return '🏠 Housing';
      case '🎡': return '🎡 Fun';
      case '🛍️': return '🛍️ Shopping';
      case '🏥': return '🏥 Health';
      case '📚': return '📚 Education';
      default: return '$emoji Item';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    final l = AppLocalizations.of(context);
    final allItems = _buildItems(state, l);
    final filtered = _applyFilter(allItems);

    // Dynamic categories extracted from all items
    final categoriesSet = <String>{'All'};
    for (final item in allItems) {
      if (item.emoji.isNotEmpty && item.emoji != '🤝') {
        categoriesSet.add(item.emoji);
      }
    }
    final categories = categoriesSet.toList();
    _availableCategories = categories;

    // Group by date
    final Map<String, List<_Item>> grouped = {};
    final labelOrder = <String>[];
    for (final item in filtered) {
      final label = _dateLabel(item.date);
      grouped.putIfAbsent(label, () { labelOrder.add(label); return []; });
      grouped[label]!.add(item);
      _expandedGroups.putIfAbsent(label, () => true);
    }

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            _buildHeader(allItems.length, l).animate().fade(duration: 300.ms).slideY(begin: 0.1),

            // ── Search bar + filter button (Revolut-style) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: TC.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TC.border(context)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: TC.text3(context)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              style: TC.geist(context, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search',
                                hintStyle: TC.geist(context, fontSize: 14, color: TC.text3(context)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () => setState(() {
                                _searchCtrl.clear();
                                _searchQuery = '';
                              }),
                              child: Icon(Icons.close, size: 16, color: TC.text3(context)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _showFilterSheet,
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: _hasActiveFilter ? TC.primary(context) : TC.card(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _hasActiveFilter ? TC.primary(context) : TC.border(context)),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.tune_rounded,
                          size: 20,
                          color: _hasActiveFilter ? Colors.white : TC.text(context)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Results count ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Text(
                '${filtered.length} results',
                style: TC.geist(context, fontSize: 11, fontWeight: FontWeight.w500, color: TC.text3(context)),
              ),
            ),

            // ── Content ──
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: EmptyState(
                        icon: '📭', title: l.noActivityYet,
                        subtitle: _filter == _Filter.all
                            ? l.addActivityHint
                            : 'No matching activity found',
                      ).animate().fade(duration: 400.ms),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                      itemCount: labelOrder.length,
                      itemBuilder: (context, i) {
                        final label = labelOrder[i];
                        final section = grouped[label]!;
                        final isExpanded = _expandedGroups[label] ?? true;

                        return _buildDateGroup(label, section, isExpanded, l, isDark, i)
                            .animate(delay: Duration(milliseconds: 50 + (i * 30)))
                            .fade(duration: 300.ms)
                            .slideY(begin: 0.05);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int totalCount, AppLocalizations l) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: EdgeInsets.fromLTRB(18, canPop ? 12 : 24, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: TC.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TC.border(context)),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.arrow_back_ios_new_rounded, color: TC.text(context), size: 14),
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.activity,
                      style: TC.gloock(context, fontSize: 28, color: TC.text(context), letterSpacing: -0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.financialTimeline,
                      style: TC.geist(context, fontSize: 11, color: TC.text3(context), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: TC.primaryPale(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: TC.primary(context).withValues(alpha: 0.25), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: TC.primary(context), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$totalCount',
                      style: TC.gloock(context, fontSize: 13, color: TC.primary(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasActiveFilter => _filter != _Filter.all || _selectedCategory != 'All';

  String _scopeLabel(_Filter f, AppLocalizations l) {
    switch (f) {
      case _Filter.all: return l.all;
      case _Filter.personal: return l.personal;
      case _Filter.groups: return l.groups;
      case _Filter.settlements: return l.settled;
    }
  }

  String _scopeIcon(_Filter f) {
    switch (f) {
      case _Filter.all: return '\u{1F5C2}\u{FE0F}';
      case _Filter.personal: return '\u{1F5D2}\u{FE0F}';
      case _Filter.groups: return '\u{1F465}';
      case _Filter.settlements: return '\u{1F91D}';
    }
  }

  void _showFilterSheet() {
    HapticFeedback.lightImpact();
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.card(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            void choose(VoidCallback fn) {
              HapticFeedback.selectionClick();
              setState(fn);
              setSheet(() {});
            }
            Widget chip(String label, bool selected, VoidCallback onTap) {
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? TC.primary(context) : TC.card2(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: selected ? TC.primary(context) : TC.border(context)),
                  ),
                  child: Text(
                    label,
                    style: TC.geist(context,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : TC.text2(context)),
                  ),
                ),
              );
            }
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Filters',
                            style: TC.gloock(context, fontSize: 20, color: TC.text(context))),
                        const Spacer(),
                        if (_hasActiveFilter)
                          GestureDetector(
                            onTap: () => choose(() {
                              _filter = _Filter.all;
                              _selectedCategory = 'All';
                            }),
                            child: Text('Clear all',
                                style: TC.geist(context,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: TC.primary(context))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('TYPE',
                        style: TC.geist(context,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: TC.text3(context),
                            letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _Filter.values.map((f) {
                        return chip('${_scopeIcon(f)}  ${_scopeLabel(f, l)}', _filter == f,
                            () => choose(() => _filter = f));
                      }).toList(),
                    ),
                    if (_availableCategories.length > 1) ...[
                      const SizedBox(height: 20),
                      Text('CATEGORY',
                          style: TC.geist(context,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: TC.text3(context),
                              letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableCategories.map((cat) {
                          return chip(_categoryLabel(cat), _selectedCategory == cat,
                              () => choose(() => _selectedCategory = cat));
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 22),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetCtx),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: TC.primary(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Done',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _calculateDailyTotal(List<_Item> items) {
    double total = 0;
    for (final item in items) {
      if (item.kind == _Kind.settlement) continue;
      if (item.isPositive) {
        total += item.amount;
      } else {
        total -= item.amount;
      }
    }
    return total;
  }

  Widget _buildDateGroup(String label, List<_Item> items, bool isExpanded, AppLocalizations l, bool isDark, int index) {
    final dailyNet = _calculateDailyTotal(items);
    
    // Find daily symbol
    String dailySym = '€';
    if (items.isNotEmpty) {
      final firstSym = items.first.sym;
      if (items.every((item) => item.sym == firstSym)) {
        dailySym = firstSym;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _expandedGroups[label] = !isExpanded);
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: Row(
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w800, color: TC.text3(context), letterSpacing: 1.5),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      '${items.length}',
                      style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w800, color: TC.text2(context)),
                    ),
                  ),
                  const Spacer(),
                  if (dailyNet != 0) ...[
                    Text(
                      '${dailyNet >= 0 ? '+' : '-'}$dailySym${AppCurrencyUtils.formatAmount(dailyNet.abs(), 0)}',
                      style: TC.gloock(
                        context,
                        fontSize: 12,
                        color: dailyNet >= 0 ? TC.ok(context) : TC.er(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Text('⌄', style: TextStyle(fontSize: 12, color: TC.text3(context))),
                  ),
                ],
              ),
            ),
          ),
          // Body
          AnimatedCrossFade(
            firstChild: Container(
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TC.border(context)),
                boxShadow: [
                  BoxShadow(color: TC.shadow(context), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: List.generate(items.length, (i) => _buildTransactionRow(items[i], i == items.length - 1, l)),
                ),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
            crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(_Item item, bool isLast, AppLocalizations l) {
    Color dotColor, tagBg, tagText;
    Color iconBg = TC.bg(context);
    String tagLabel;

    if (item.kind == _Kind.personal) {
      dotColor = TC.blue(context);
      tagText = TC.blue(context);
      tagBg = TC.bluePale(context);
      tagLabel = l.personal;
      iconBg = TC.bluePale(context);
    } else if (item.kind == _Kind.groupExpense) {
      dotColor = TC.primary(context);
      tagText = TC.primary(context);
      tagBg = TC.primaryPale(context);
      tagLabel = l.group;
      iconBg = TC.primaryPale(context);
    } else {
      dotColor = TC.purple(context);
      tagText = TC.purple(context);
      tagBg = TC.purplePale(context);
      tagLabel = l.settled;
      iconBg = TC.purplePale(context);
    }

    final amtColor = item.isPositive ? TC.ok(context) : TC.er(context);
    final prefix = item.isPositive ? '+' : '-';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          if (item.receiptPath != null) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ReceiptViewer(imagePath: item.receiptPath!, title: item.title)));
            return;
          }
          if (item.kind == _Kind.groupExpense && item.group != null) {
            final state = context.read<AppState>();
            state.currentGroup = item.group;
            Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupDetailScreen()));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: isLast ? null : Border(bottom: BorderSide(color: TC.border(context))),
          ),
          child: Row(
            children: [
              // Vertical tx-dot
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 10),
              // Icon Bubble
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(item.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              // Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TC.geist(context, fontSize: 13, fontWeight: FontWeight.w600, color: TC.text(context), height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          item.subtitle,
                          style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w500, color: TC.text3(context)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('·', style: TextStyle(fontSize: 10, color: TC.text3(context))),
                        ),
                        Expanded(
                          child: Text(
                            item.sub2,
                            style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w500, color: TC.text3(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right side
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefix${item.sym}${AppCurrencyUtils.formatAmount(item.amount)}',
                    style: TC.gloock(context, fontSize: 14, color: amtColor, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      tagLabel,
                      style: TC.geist(context, fontSize: 9, fontWeight: FontWeight.w700, color: tagText),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 14, color: TC.text3(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class SliverToBoxAdapterDummy extends StatelessWidget {
  final Widget child;
  const SliverToBoxAdapterDummy({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
