import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import '../services/export_service.dart';
import '../services/analytics_service.dart';
import 'add_transaction_screen.dart';
import 'personal_charts_screen.dart';

// ─── Period enum ─────────────────────────────────────────────────────────────
enum _TPeriod { day, week, month, year, period }

// ─── MoneyTransactionsScreen ─────────────────────────────────────────────────
class MoneyTransactionsScreen extends StatefulWidget {
  final String? filterCat;
  final String? filterCurrency; // optional currency filter passed from MoneyTab
  const MoneyTransactionsScreen({super.key, this.filterCat, this.filterCurrency});

  @override
  State<MoneyTransactionsScreen> createState() =>
      _MoneyTransactionsScreenState();
}

class _MoneyTransactionsScreenState extends State<MoneyTransactionsScreen> {
  _TPeriod _period = _TPeriod.month;
  bool _showExpenses = true;
  DateTime _selectedDate =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _sortByDate = true; // false = by amount
  String? _sortOrder; // for bottom sheet
  String? _activeCurrencyFilter;

  @override
  void initState() {
    super.initState();
    _activeCurrencyFilter = widget.filterCurrency ?? 'ALL';
  }

  // ── Period navigation ─────────────────────────────────────────────────────
  void _prevPeriod() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_period) {
        case _TPeriod.day:
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
        case _TPeriod.week:
          _selectedDate = _selectedDate.subtract(const Duration(days: 7));
        case _TPeriod.month:
          _selectedDate =
              DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
        case _TPeriod.year:
          _selectedDate = DateTime(_selectedDate.year - 1, 1, 1);
        case _TPeriod.period:
          break;
      }
    });
  }

  void _nextPeriod() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_period) {
        case _TPeriod.day:
          _selectedDate = _selectedDate.add(const Duration(days: 1));
        case _TPeriod.week:
          _selectedDate = _selectedDate.add(const Duration(days: 7));
        case _TPeriod.month:
          _selectedDate =
              DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        case _TPeriod.year:
          _selectedDate = DateTime(_selectedDate.year + 1, 1, 1);
        case _TPeriod.period:
          break;
      }
    });
  }

  String get _periodLabel {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const shortMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    switch (_period) {
      case _TPeriod.day:
        return '${shortMonths[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
      case _TPeriod.week:
        final end = _selectedDate.add(const Duration(days: 6));
        return '${shortMonths[_selectedDate.month - 1]} ${_selectedDate.day} – ${shortMonths[end.month - 1]} ${end.day}';
      case _TPeriod.month:
        return '${months[_selectedDate.month - 1]} ${_selectedDate.year}';
      case _TPeriod.year:
        return '${_selectedDate.year}';
      case _TPeriod.period:
        return 'Custom Period';
    }
  }

  // ── Filter transactions ───────────────────────────────────────────────────
  List<TransactionData> _filterTransactions(List<TransactionData> all) {
    List<TransactionData> filtered;
    switch (_period) {
      case _TPeriod.day:
        filtered = all.where((t) {
          final d = t.rawDate;
          return d != null &&
              d.year == _selectedDate.year &&
              d.month == _selectedDate.month &&
              d.day == _selectedDate.day;
        }).toList();
      case _TPeriod.week:
        final end = _selectedDate.add(const Duration(days: 7));
        filtered = all.where((t) {
          final d = t.rawDate;
          return d != null &&
              !d.isBefore(_selectedDate) &&
              d.isBefore(end);
        }).toList();
      case _TPeriod.month:
        filtered = all.where((t) {
          final d = t.rawDate;
          return d != null &&
              d.year == _selectedDate.year &&
              d.month == _selectedDate.month;
        }).toList();
      case _TPeriod.year:
        filtered = all
            .where((t) => t.rawDate?.year == _selectedDate.year)
            .toList();
      case _TPeriod.period:
        filtered = all;
    }

    // Type filter
    if (_showExpenses) {
      filtered = filtered.where((t) => t.type == 'expense').toList();
    } else {
      filtered = filtered.where((t) => t.type == 'income').toList();
    }

    // removed type filter

    if (_activeCurrencyFilter != null && _activeCurrencyFilter != 'ALL') {
      filtered = filtered.where((t) => t.currency == _activeCurrencyFilter).toList();
    }

    // Category filter
    if (widget.filterCat != null) {
      filtered = filtered.where((t) => t.cat == widget.filterCat).toList();
    }

    // Sort
    if (_sortByDate) {
      filtered.sort((a, b) {
        final da = a.rawDate;
        final db = b.rawDate;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    } else {
      filtered.sort((a, b) => b.amount.compareTo(a.amount));
    }

    return filtered;
  }

  // ── Group by date ─────────────────────────────────────────────────────────
  Map<String, List<TransactionData>> _groupByDate(
      List<TransactionData> txns) {
    final grouped = <String, List<TransactionData>>{};
    for (final t in txns) {
      final d = t.rawDate;
      String key;
      if (d == null) {
        key = t.date;
      } else {
        const months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        key = '${months[d.month - 1]} ${d.day}, ${d.year}';
      }
      grouped.putIfAbsent(key, () => []).add(t);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final transactions =
        context.select<AppState, List<TransactionData>>((s) => s.transactions);
    final state = context.read<AppState>();

    final filtered = _filterTransactions(transactions);
    final totalAmount = filtered.fold(0.0, (s, t) => s + t.amount);
    final grouped = _sortByDate ? _groupByDate(filtered) : null;
    final primarySym =
        filtered.isNotEmpty ? filtered.first.sym : '\$';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ───────────────────────────────────────────────────
            Container(
              color: TC.surface(context),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Icon(Icons.arrow_back_ios_new,
                            color: TC.text(context), size: 20),
                      ),
                      Expanded(
                        child: GestureDetector(
                           onTap: () => _showCurrencyFilterSheet(context),
                           child: Column(
                             children: [
                               Text('Transactions',
                                   style: TextStyle(
                                       color: TC.text(context),
                                       fontSize: 17,
                                       fontWeight: FontWeight.w700)),
                               Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Icon(Icons.monetization_on_outlined,
                                       color: AppColors.green, size: 14),
                                   const SizedBox(width: 4),
                                   Text(_activeCurrencyFilter == 'ALL' ? 'All Currencies' : _activeCurrencyFilter ?? 'All Currencies',
                                       style: TextStyle(
                                           color: TC.text2(context), fontSize: 12, fontWeight: FontWeight.w600)),
                                   Icon(Icons.arrow_drop_down,
                                       color: TC.text3(context), size: 16),
                                 ],
                               ),
                             ],
                           ),
                        ),
                      ),
                      // Search
                      GestureDetector(
                        onTap: () => _showSearch(context, state),
                        child: Icon(Icons.search,
                            color: TC.text(context), size: 22),
                      ),
                      const SizedBox(width: 12),
                      // Charts
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => MoneyChartsScreen(initialCurrency: _activeCurrencyFilter)));
                        },
                        child: Icon(Icons.pie_chart_outline,
                            color: TC.text(context), size: 22),
                      ),
                      const SizedBox(width: 12),
                      // Export
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ExportService.exportPersonalTransactions(filtered, _activeCurrencyFilter ?? 'ALL', context);
                        },
                        child: Icon(Icons.file_download_outlined,
                            color: TC.text(context), size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── EXPENSES / INCOME tabs ────────────────────────────────────
            Container(
              color: TC.surface(context),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showExpenses = true);
                      },
                      child: Column(
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              'EXPENSES',
                              style: TextStyle(
                                color: _showExpenses
                                    ? TC.text(context)
                                    : TC.text3(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 2,
                            color: _showExpenses
                                ? AppColors.green
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showExpenses = false);
                      },
                      child: Column(
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              'INCOME',
                              style: TextStyle(
                                color: !_showExpenses
                                    ? TC.text(context)
                                    : TC.text3(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 2,
                            color: !_showExpenses
                                ? AppColors.green
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Period selector ───────────────────────────────────────────
            Container(
              color: TC.card(context),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                children: [
                  // Day / Week / Month / Year / Period
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _TPeriod.values.map((p) {
                      final isActive = _period == p;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          if (p == _TPeriod.period) {
                            _showPeriodPicker(context);
                            return;
                          }
                          setState(() {
                            _period = p;
                            final now = DateTime.now();
                            _selectedDate = p == _TPeriod.month
                                ? DateTime(now.year, now.month, 1)
                                : p == _TPeriod.year
                                    ? DateTime(now.year, 1, 1)
                                    : DateTime(now.year, now.month, now.day);
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.name[0].toUpperCase() +
                                  p.name.substring(1),
                              style: TextStyle(
                                color: isActive
                                    ? AppColors.green
                                    : TC.text2(context),
                                fontSize: 13,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: 2,
                              width: isActive ? 20 : 0,
                              color: AppColors.green,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  // Nav row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _prevPeriod,
                        child: Icon(Icons.chevron_left,
                            color: TC.text2(context), size: 22),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _periodLabel,
                            style: TextStyle(
                              color: TC.text(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: TC.border(context),
                            ),
                          ),
                        ),
                      ),
                      Icon(Icons.fast_forward_rounded,
                          color: TC.text3(context), size: 18),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _nextPeriod,
                        child: Icon(Icons.chevron_right,
                            color: TC.text2(context), size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── List area ─────────────────────────────────────────────────
            Expanded(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: EmptyState(
                          icon: _showExpenses ? '💸' : '💰',
                          title: 'No transactions this period',
                          subtitle: 'Tap + to add your first',
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 80),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // Total header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              children: [
                                Text(
                                  'Total: $primarySym${AppCurrencyUtils.formatAmount(totalAmount, 0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: TC.text(context),
                                  ),
                                ),
                                const Spacer(),
                                // Sort button
                                GestureDetector(
                                  onTap: () => _showSortSheet(context),
                                  child: Row(
                                    children: [
                                      Text(
                                        _sortByDate ? 'By date' : 'By amount',
                                        style: const TextStyle(
                                            color: AppColors.green,
                                            fontSize: 13),
                                      ),
                                      const Icon(Icons.arrow_drop_down,
                                          color: AppColors.green, size: 18),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Grouped transactions
                          if (_sortByDate && grouped != null)
                            ...grouped.entries
                                .toList()
                                .asMap()
                                .entries
                                .expand((sEntry) {
                              final sectionI = sEntry.key;
                              final section = sEntry.value;
                              return [
                                // Date header
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 16, 16, 8),
                                  child: Text(
                                    section.key,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white54
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ).animate(delay: (sectionI * 40).ms).fadeIn(),
                                // Transaction cards
                                ...section.value.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final t = entry.value;
                                  return _TxnCard(
                                    t: t,
                                    state: state,
                                    delay: (sectionI * 40 + i * 50).ms,
                                  );
                                }),
                              ];
                            })
                          else
                            ...filtered.asMap().entries.map((entry) {
                              return _TxnCard(
                                t: entry.value,
                                state: state,
                                delay: (entry.key * 50).ms,
                              );
                            }),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPeriodPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (_) => const _PeriodPickerDialog(),
    );
  }

  void _showSortSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Sort By',
                style: TextStyle(
                    color: TC.text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.calendar_today_outlined,
                  color: TC.text2(context)),
              title: Text('By date',
                  style: TextStyle(color: TC.text(context))),
              trailing: _sortByDate
                  ? const Icon(Icons.check, color: AppColors.green)
                  : null,
              onTap: () {
                setState(() => _sortByDate = true);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.sort, color: TC.text2(context)),
              title: Text('By amount',
                  style: TextStyle(color: TC.text(context))),
              trailing: !_sortByDate
                  ? const Icon(Icons.check, color: AppColors.green)
                  : null,
              onTap: () {
                setState(() => _sortByDate = false);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSearch(BuildContext context, AppState state) {
    showSearch(
      context: context,
      delegate: _TxnSearchDelegate(transactions: state.transactions),
    );
  }

  void _showCurrencyFilterSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final currencies = AppState.currencies;
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: TC.border(context),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Filter by Currency',
                  style: TextStyle(
                      color: TC.text(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ListTile(
                title: Text('All Currencies',
                    style: TextStyle(color: TC.text(context))),
                trailing: (_activeCurrencyFilter == null || _activeCurrencyFilter == 'ALL')
                    ? const Icon(Icons.check, color: AppColors.green)
                    : null,
                onTap: () {
                  setState(() => _activeCurrencyFilter = 'ALL');
                  Navigator.pop(context);
                },
              ),
              ...currencies.map((c) => ListTile(
                    title: Text('${c.flag} ${c.code}',
                        style: TextStyle(color: TC.text(context))),
                    trailing: _activeCurrencyFilter == c.code
                        ? const Icon(Icons.check, color: AppColors.green)
                        : null,
                    onTap: () {
                      setState(() => _activeCurrencyFilter = c.code);
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Transaction card ─────────────────────────────────────────────────────────
class _TxnCard extends StatelessWidget {
  final TransactionData t;
  final AppState state;
  final Duration delay;
  const _TxnCard({
    required this.t,
    required this.state,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final isInc = t.type == 'income';
    final cardBg = TC.card(context);
    final borderColor = TC.border(context);

    // Find category label
    final catData = AppState.expenseCategories.firstWhere(
      (c) => c.icon == t.cat,
      orElse: () {
        return AppState.incomeCategories.firstWhere(
          (c) => c.icon == t.cat,
          orElse: () => const CategoryItem('?', 'Other', '#9999aa'),
        );
      },
    );

    return Dismissible(
      key: Key('txn_list_${t.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _confirmDelete(context, state);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withValues(alpha: 0.2),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: GestureDetector(
        onTap: () => _showActions(context, state),
        onLongPress: () => _showActions(context, state),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // Category icon with colored background
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isInc
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE57373))
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(t.cat, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catData.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: TC.text(context),
                      ),
                    ),
                    Text(
                      'Main', // Account name placeholder
                      style: TextStyle(
                        fontSize: 12,
                        color: TC.text2(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '${isInc ? '+' : '-'}${t.sym}${AppCurrencyUtils.formatAmount(t.amount, 0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isInc ? AppColors.green : AppColors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: delay)
        .slideX(begin: 0.1, duration: 300.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 300.ms);
  }

  void _confirmDelete(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TC.surface(context),
        title: Text('Delete transaction?',
            style: TextStyle(
                color: TC.text(context), fontWeight: FontWeight.w700)),
        content: Text('Delete "${t.desc}"?',
            style: TextStyle(color: TC.text2(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: TC.text2(context))),
          ),
          TextButton(
            onPressed: () {
              state.deleteTransaction(t);
              AnalyticsService.logTransactionDeleted();
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context, AppState state) {
    HapticFeedback.mediumImpact();
    // Get category details for icon
    final catData = AppState.expenseCategories.firstWhere(
      (c) => c.icon == t.cat,
      orElse: () => AppState.incomeCategories.firstWhere(
        (c) => c.icon == t.cat,
        orElse: () => const CategoryItem('?', 'Other', '#9999aa'),
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: TC.border(context),
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              
              // Transaction Header - Icon, Title, Amount
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (t.type == 'income' ? const Color(0xFF4CAF50) : const Color(0xFFE57373)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(t.cat, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(catData.label, style: TextStyle(color: TC.text2(context), fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(t.desc, style: TextStyle(color: TC.text(context), fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Text('${t.type == 'income' ? '+' : '-'}${t.sym}${AppCurrencyUtils.formatAmount(t.amount, 2)}', 
                      style: TextStyle(color: t.type == 'income' ? AppColors.green : AppColors.red, fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 24),
              
              // Date
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, color: TC.text3(context), size: 18),
                  const SizedBox(width: 12),
                  Text(t.date, style: TextStyle(color: TC.text(context), fontSize: 14)),
                ],
              ),
              
              const SizedBox(height: 24),
              // Actions
              Container(height: 1, color: TC.border(context)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: TC.card(context), shape: BoxShape.circle),
                  child: Icon(Icons.edit_outlined, color: TC.text(context), size: 20),
                ),
                title: Text('Edit Transaction', style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: t)));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline, color: AppColors.red, size: 20),
                ),
                title: const Text('Delete Transaction', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, state);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Period Picker Dialog (calendar style) ────────────────────────────────────
class _PeriodPickerDialog extends StatefulWidget {
  const _PeriodPickerDialog();

  @override
  State<_PeriodPickerDialog> createState() => _PeriodPickerDialogState();
}

class _PeriodPickerDialogState extends State<_PeriodPickerDialog> {
  DateTime? _start;
  DateTime? _end;
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _allTime = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A2A1A),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Period',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            if (_start != null && _end != null)
              Text(
                'from ${_fmt(_start!)} to ${_fmt(_end!)}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            const SizedBox(height: 12),
            // All time toggle
            GestureDetector(
              onTap: () => setState(() => _allTime = !_allTime),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54),
                      borderRadius: BorderRadius.circular(4),
                      color: _allTime
                          ? const Color(0xFF4CAF50)
                          : Colors.transparent,
                    ),
                    child: _allTime
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Text('All time',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Calendar
            _buildCalendar(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL',
                      style: TextStyle(color: Color(0xFF4CAF50))),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK',
                      style: TextStyle(color: Color(0xFF4CAF50))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  Widget _buildCalendar() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final firstDay =
        DateTime(_viewMonth.year, _viewMonth.month, 1);
    final startWeekday = firstDay.weekday % 7;
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final today = DateTime.now();

    return Column(
      children: [
        Text(
          '${months[_viewMonth.month - 1]} ${_viewMonth.year}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.map((d) => SizedBox(
            width: 36,
            child: Text(d,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
          )).toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, childAspectRatio: 1),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (_, i) {
            if (i < startWeekday) return const SizedBox.shrink();
            final day = i - startWeekday + 1;
            final date = DateTime(_viewMonth.year, _viewMonth.month, day);

            final isToday = date.day == today.day &&
                date.month == today.month &&
                date.year == today.year;

            final isSelected = (_start != null &&
                    date.isAtSameMomentAs(_start!)) ||
                (_end != null && date.isAtSameMomentAs(_end!));

            final isInRange = _start != null &&
                _end != null &&
                date.isAfter(_start!) &&
                date.isBefore(_end!);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (_start == null || (_start != null && _end != null)) {
                    _start = date;
                    _end = null;
                  } else {
                    _end = date;
                    if (_end!.isBefore(_start!)) {
                      final tmp = _start;
                      _start = _end;
                      _end = tmp;
                    }
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4CAF50)
                      : isInRange
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                          : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(
                          color: const Color(0xFF4CAF50), width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : isToday
                            ? const Color(0xFF4CAF50)
                            : Colors.white,
                    fontSize: 13,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Search Delegate ──────────────────────────────────────────────────────────
class _TxnSearchDelegate extends SearchDelegate<String> {
  final List<TransactionData> transactions;
  _TxnSearchDelegate({required this.transactions});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D2818),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white38),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final filtered = transactions
        .where((t) =>
            t.desc.toLowerCase().contains(query.toLowerCase()) ||
            t.cat.contains(query))
        .toList();

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (_, i) {
          final t = filtered[i];
          final isInc = t.type == 'income';
          return ListTile(
            leading: Text(t.cat, style: const TextStyle(fontSize: 24)),
            title: Text(t.desc,
                style: TextStyle(color: TC.text(context))),
            subtitle: Text(t.date,
                style: TextStyle(color: TC.text2(context))),
            trailing: Text(
              '${isInc ? '+' : '-'}${t.sym}${AppCurrencyUtils.formatAmount(t.amount)}',
              style: TextStyle(
                color: isInc ? AppColors.green : AppColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }
}
