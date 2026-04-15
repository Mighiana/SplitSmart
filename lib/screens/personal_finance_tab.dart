import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import 'add_transaction_screen.dart';
import 'personal_charts_screen.dart';
import 'personal_transactions_screen.dart';
import 'subscriptions_screen.dart';
import 'reminders_screen.dart';
import 'saving_goals_screen.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:fl_chart/fl_chart.dart';
import 'settings_screen.dart';
import '../widgets/app_drawer.dart';

// ─── Period enum ─────────────────────────────────────────────────────────────
enum _Period { day, week, month, year }

final List<Color> _catPalette = const [
  Color(0xFF00D68F), // Green
  Color(0xFFFF4D6D), // Red
  Color(0xFF4D9EFF), // Blue
  Color(0xFFFFA500), // Orange
  Color(0xFFB388FF), // Purple
  Color(0xFF00BCD4), // Cyan
  Color(0xFFFFD166), // Yellow
  Color(0xFF607D8B), // BlueGrey
  Color(0xFF8BC34A), // LightGreen
  Color(0xFFE91E63), // Pink
  Color(0xFF3F51B5), // Indigo
  Color(0xFFFF5722), // DeepOrange
  Color(0xFF009688), // Teal
  Color(0xFF9C27B0), // DeepPurple
  Color(0xFFCDDC39), // Lime
  Color(0xFF795548), // Brown
  Color(0xFFFF9800), // Amber
  Color(0xFF2196F3), // LightBlue
  Color(0xFF4CAF50), // StandardGreen
  Color(0xFFF44336), // VibrantRed
];

final Map<String, Color> _catColorMap = {};
int _paletteIndex = 0;

Color _getCatColor(String catEmoji) {
  if (_catColorMap.containsKey(catEmoji)) {
    return _catColorMap[catEmoji]!;
  }
  final c = _catPalette[_paletteIndex % _catPalette.length];
  _catColorMap[catEmoji] = c;
  _paletteIndex++;
  return c;
}

// ─── MoneyTab ─────────────────────────────────────────────────────────────────
class MoneyTab extends StatefulWidget {
  const MoneyTab({super.key});

  @override
  State<MoneyTab> createState() => _MoneyTabState();
}

class _MoneyTabState extends State<MoneyTab> {
  Timer? _greetTimer;
  int _hour = DateTime.now().hour;
  String _userName = '';

  _Period _period = _Period.month;
  bool _showExpenses = true;
  DateTime _selectedDate =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _drawerKey = GlobalKey();
  final GlobalKey _balanceKey = GlobalKey();

  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadName();
    _checkTour();
    _greetTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final newHour = DateTime.now().hour;
      if (newHour != _hour && mounted) setState(() => _hour = newHour);
    });
  }

  void _showTutorial() {
    final targets = [
      TargetFocus(
        identify: "Balance",
        keyTarget: _balanceKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text("Personal Finances", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 24)),
                SizedBox(height: 10),
                Text("Here is your net balance. You can see your charts and all your personal transactions below.", style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          )
        ],
      ),
      TargetFocus(
        identify: "Drawer",
        keyTarget: _drawerKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text("Powerful Menu", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 24)),
                SizedBox(height: 10),
                Text("Check this menu to select Subscriptions, Reminders, Saving Goals, and navigate to other screens.", style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          )
        ],
      ),
      TargetFocus(
        identify: "Settings",
        keyTarget: _settingsKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text("Settings & Export", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 24)),
                SizedBox(height: 10),
                Text("Tap here to enable App Lock, manage data, or export your transactions to PDF & CSV.", style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          )
        ],
      ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.85,
      onFinish: () {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('tour_seen', true);
        });
      },
      onSkip: () {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('tour_seen', true);
        });
        return true;
      },
    ).show(context: context);
  }

  Future<void> _checkTour() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('tour_seen') ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTutorial();
        }
      });
    }
  }

  @override
  void dispose() {
    _greetTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_first_name');
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => _userName = name);
    }
  }

  String get _formattedGreeting {
    String g = 'Good evening';
    if (_hour < 12) g = 'Good morning';
    else if (_hour < 17) g = 'Good afternoon';
    
    if (_userName.trim().isEmpty) return g;
    return '$g, ${_userName.trim()}';
  }
  String? _selectedCurrency; // null = show all / first available

  // ── Period navigation ─────────────────────────────────────────────────────
  void _prevPeriod() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_period) {
        case _Period.day:
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
        case _Period.week:
          _selectedDate = _selectedDate.subtract(const Duration(days: 7));
        case _Period.month:
          _selectedDate =
              DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
        case _Period.year:
          _selectedDate = DateTime(_selectedDate.year - 1, 1, 1);
      }
    });
  }

  void _nextPeriod() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_period) {
        case _Period.day:
          _selectedDate = _selectedDate.add(const Duration(days: 1));
        case _Period.week:
          _selectedDate = _selectedDate.add(const Duration(days: 7));
        case _Period.month:
          _selectedDate =
              DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        case _Period.year:
          _selectedDate = DateTime(_selectedDate.year + 1, 1, 1);
      }
    });
  }

  void _jumpToToday() {
    HapticFeedback.mediumImpact();
    setState(() {
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, 1);
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
      case _Period.day:
        return '${shortMonths[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
      case _Period.week:
        final end = _selectedDate.add(const Duration(days: 6));
        return '${shortMonths[_selectedDate.month - 1]} ${_selectedDate.day} – ${shortMonths[end.month - 1]} ${end.day}';
      case _Period.month:
        return '${months[_selectedDate.month - 1]} ${_selectedDate.year}';
      case _Period.year:
        return '${_selectedDate.year}';
    }
  }

  // ── Filter transactions by period ─────────────────────────────────────────
  List<TransactionData> _filterByPeriod(List<TransactionData> all) {
    return all.where((t) {
      final d = t.rawDate;
      if (d == null) return false;
      switch (_period) {
        case _Period.day:
          return d.year == _selectedDate.year &&
              d.month == _selectedDate.month &&
              d.day == _selectedDate.day;
        case _Period.week:
          final end = _selectedDate.add(const Duration(days: 7));
          return !d.isBefore(_selectedDate) && d.isBefore(end);
        case _Period.month:
          return d.year == _selectedDate.year &&
              d.month == _selectedDate.month;
        case _Period.year:
          return d.year == _selectedDate.year;
      }
    }).toList();
  }

  // ── Get all unique currencies from transactions ───────────────────────────
  List<String> _getCurrencies(List<TransactionData> txns) {
    final seen = <String>{};
    final result = <String>[];
    for (final t in txns) {
      if (seen.add(t.currency)) result.add(t.currency);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final transactions = context
        .select<AppState, List<TransactionData>>((s) => s.transactions);
    final wallets =
        context.select<AppState, Map<String, double>>((s) => s.wallets);
    final state = context.read<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // All unique currencies in this period
    final periodAll = _filterByPeriod(transactions);
    final currencies = _getCurrencies(periodAll);

    // Auto-select first wallet if nothing selected
    String? activeCur = _selectedCurrency;
    if (activeCur == null && wallets.keys.isNotEmpty) {
      activeCur = wallets.keys.first;
      // schedule update after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedCurrency = wallets.keys.first);
      });
    } else if (activeCur == null && AppState.currencies.isNotEmpty) {
      activeCur = AppState.currencies.first.code;
    }

    // Filter to currency + type
    final currencyFiltered = activeCur != null
        ? periodAll.where((t) => t.currency == activeCur).toList()
        : periodAll;

    final typed = _showExpenses
        ? currencyFiltered.where((t) => t.type == 'expense').toList()
        : currencyFiltered.where((t) => t.type == 'income').toList();

    final totalAmount = typed.fold(0.0, (s, t) => s + t.amount);

    // Category breakdown (within same currency → % is valid)
    final Map<String, double> catTotals = {};
    for (final t in typed) {
      catTotals[t.cat] = (catTotals[t.cat] ?? 0) + t.amount;
    }
    final sortedCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Symbol for active currency
    final CurrencyData? activeCurData = activeCur != null
        ? AppState.currencies.firstWhere(
            (c) => c.code == activeCur,
            orElse: () => CurrencyData(activeCur!, activeCur!, '💱', activeCur!),
          )
        : null;
    final sym = activeCurData?.sym ?? '\$';

    // Overall wallet balance for THIS specific currency (NOT globally summed)
    final overallBalance = activeCur != null ? (wallets[activeCur] ?? 0.0) : 0.0;
    
    // Fallbacks
    final headerSym = activeCurData?.sym ?? '\$';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            _buildHeader(context, overallBalance, headerSym, state, isDark, activeCur),

            // ── EXPENSES / INCOME tabs ───────────────────────────────────────
            _buildTypeTabs(context, isDark),

            // ── Period selector ──────────────────────────────────────────────
            _buildPeriodSelector(context, isDark),

            // ── Scrollable body ──────────────────────────────────────────────
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  // Donut chart
                  _buildChartCard(context, totalAmount, sortedCats, sym,
                      activeCur, isDark, state),

                  // Category list
                  if (sortedCats.isNotEmpty)
                    _buildCategoryList(
                        context, sortedCats, totalAmount, sym, activeCur)
                  else
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: EmptyState(
                        icon: _showExpenses ? '💸' : '💰',
                        title: _showExpenses
                            ? 'No expenses this period'
                            : 'No income this period',
                        subtitle: currencies.isEmpty
                            ? 'Tap + to add a transaction'
                            : 'Try selecting a different currency or period',
                      ),
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTransactionScreen(fixedCurrency: activeCur)),
          );
        },
        backgroundColor: AppColors.green,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 17) return 'Good afternoon 🌤️';
    return 'Good evening 🌙';
  }

  // ─── Header bar ──────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, double balance, String sym,
      AppState state, bool isDark, String? activeCur) {
    return Container(
      decoration: BoxDecoration(
        color: TC.bg(context),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AppDrawer(),
                  );
                },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: TC.card(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TC.border(context)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.menu_rounded, color: TC.text(context), size: 22),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.green, letterSpacing: 1.5)),
                    const SizedBox(height: 2),
                    Text('Money 💰', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: TC.text(context), letterSpacing: -0.5)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: TC.card(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TC.border(context)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  alignment: Alignment.center,
                  child: const Text('⚙️', style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ).animate().fade().slideY(begin: -0.2, end: 0, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          // Luxury Balance Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.greenGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10, top: -10,
                  child: Icon(Icons.waves_rounded, color: Colors.black.withValues(alpha: 0.05), size: 100),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('VIRTUAL ASSETS'.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black54, letterSpacing: 1.2)),
                        const Icon(Icons.contactless_outlined, color: Colors.black54, size: 20),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$sym${AppCurrencyUtils.formatAmount(balance.abs(), 0)}',
                      style: const TextStyle(color: Colors.black, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildQuickDataIcon(Icons.insights_rounded, 'Analysis', () => Navigator.push(context, MaterialPageRoute(builder: (_) => MoneyChartsScreen(initialCurrency: activeCur)))),
                        const SizedBox(width: 12),
                        _buildQuickDataIcon(Icons.history_edu_rounded, 'History', () => Navigator.push(context, MaterialPageRoute(builder: (_) => MoneyTransactionsScreen(filterCurrency: activeCur)))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text(activeCur ?? 'ALL', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fade().scale(curve: Curves.easeOutBack, duration: 600.ms),
        ],
      ),
    );
  }

  Widget _buildQuickDataIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87, size: 14),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // ─── EXPENSES / INCOME tabs ───────────────────────────────────────────────
  Widget _buildTypeTabs(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TC.border(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showExpenses = true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _showExpenses ? const Color(0xFFFF4D6D) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'EXPENSES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: _showExpenses ? Colors.white : TC.text3(context),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showExpenses = false);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_showExpenses ? const Color(0xFF00D68F) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'INCOME',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: !_showExpenses ? Colors.white : TC.text3(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Period selector ──────────────────────────────────────────────────────
  Widget _buildPeriodSelector(BuildContext context, bool isDark) {
    return Container(
      color: TC.card(context),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _Period.values.map((p) {
              final isActive = _period == p;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _period = p;
                    final now = DateTime.now();
                    _selectedDate = p == _Period.month
                        ? DateTime(now.year, now.month, 1)
                        : p == _Period.year
                            ? DateTime(now.year, 1, 1)
                            : DateTime(now.year, now.month, now.day);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.greenDim
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: isActive
                        ? Border.all(
                            color: AppColors.green.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Text(
                    p.name[0].toUpperCase() + p.name.substring(1),
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
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: _prevPeriod,
                child: Icon(Icons.chevron_left,
                    color: TC.text2(context), size: 22),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _jumpToToday,
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
              ),
              GestureDetector(
                onTap: _jumpToToday,
                child: Icon(Icons.fast_forward_rounded,
                    color: TC.text3(context), size: 18),
              ),
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
    );
  }

  // ─── Donut chart card ────────────────────────────────────────────────────
  Widget _buildChartCard(
    BuildContext context,
    double totalAmount,
    List<MapEntry<String, double>> sortedCats,
    String sym,
    String? activeCur,
    bool isDark,
    AppState state,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TC.border(context)),
      ),
      child: Column(
        children: [
          // Currency note
          if (activeCur != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart_outline,
                      size: 13, color: TC.text3(context)),
                  const SizedBox(width: 4),
                  Text(
                    '% breakdown in $activeCur only',
                    style: TextStyle(
                        fontSize: 11, color: TC.text3(context)),
                  ),
                ],
              ),
            ),

          // Donut chart + Legend
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 170, // Smaller to give legend space
                      height: 170,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 3,
                          centerSpaceRadius: 50,
                          sections: sortedCats.isEmpty
                              ? [
                                  PieChartSectionData(
                                    color: TC.border(context),
                                    value: 1,
                                    title: '',
                                    radius: 35,
                                  )
                                ]
                              : List.generate(sortedCats.length, (i) {
                                  final isTouched = i == _touchedIndex;
                                  final radius = isTouched ? 45.0 : 35.0; 
                                  final value = sortedCats[i].value;
                                  return PieChartSectionData(
                                    color: _getCatColor(sortedCats[i].key),
                                    value: value,
                                    title: '', // Keep title blank as legend is on right
                                    radius: radius,
                                  );
                                }),
                        ),
                      ),
                    ),
                    // Centre label (stationary)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sym,
                          style: TextStyle(
                            color: TC.text3(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          AppCurrencyUtils.formatAmount(totalAmount, 0),
                          style: TextStyle(
                            color: TC.text(context),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _showExpenses ? 'expenses' : 'income',
                          style: TextStyle(
                              color: TC.text3(context), fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 170,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sortedCats.isEmpty
                            ? [Text('No Data', style: TextStyle(color: TC.text3(context)))]
                            : sortedCats.map((cat) {
                                final percent = totalAmount > 0 ? (cat.value / totalAmount * 100) : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 5,
                                        backgroundColor: _getCatColor(cat.key),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          cat.key, 
                                          style: TextStyle(color: TC.text(context), fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${percent.toStringAsFixed(0)}%',
                                        style: TextStyle(color: TC.text3(context), fontSize: 13, fontWeight: FontWeight.bold),
                                      )
                                    ],
                                  ),
                                );
                              }).toList(),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),

          const SizedBox(height: 12),

          // View charts + transactions buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MoneyChartsScreen(initialCurrency: activeCur)));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D68F), Color(0xFF00B377)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.insights_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Charts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MoneyTransactionsScreen(filterCurrency: activeCur)));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: TC.card(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TC.border(context)),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, color: TC.text2(context), size: 16),
                        const SizedBox(width: 6),
                        Text('All Transactions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TC.text(context))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Category breakdown list ──────────────────────────────────────────────
  Widget _buildCategoryList(
    BuildContext context,
    List<MapEntry<String, double>> sortedCats,
    double totalAmount,
    String sym,
    String? activeCur,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'BY CATEGORY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TC.text3(context),
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (activeCur != null)
                Text(
                  activeCur,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        ...sortedCats.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value;
          final pct =
              totalAmount > 0 ? (cat.value / totalAmount * 100) : 0.0;
          final color = _getCatColor(cat.key);

          final catData = AppState.expenseCategories.firstWhere(
            (c) => c.icon == cat.key,
            orElse: () => AppState.incomeCategories.firstWhere(
              (c) => c.icon == cat.key,
              orElse: () =>
                  const CategoryItem('?', 'Other', '#9999aa'),
            ),
          );

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MoneyTransactionsScreen(
                    filterCat: cat.key,
                    filterCurrency: activeCur,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TC.border(context)),
              ),
              child: Row(
                children: [
                  // Icon circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(cat.key,
                        style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  // Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          catData.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: TC.text(context),
                          ),
                        ),
                        // Progress bar
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: totalAmount > 0
                                ? (cat.value / totalAmount)
                                    .clamp(0.0, 1.0)
                                : 0,
                            backgroundColor: TC.border(context),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Pct + amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      Text(
                        '$sym${AppCurrencyUtils.formatAmount(cat.value, 0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: TC.text(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
                .animate(delay: (i * 50).ms)
                .slideX(
                    begin: 0.1,
                    curve: Curves.easeOutCubic,
                    duration: 300.ms)
                .fadeIn(duration: 300.ms),
          );
        }),
      ],
    );
  }

  // ─── Side Drawer ─────────────────────────────────────────────────────────
  void _showDrawer(BuildContext context, AppState state) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TC.surface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _MoneyDrawer(),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case 'Charts':
        Navigator.push(context, MaterialPageRoute(builder: (_) => MoneyChartsScreen(initialCurrency: _selectedCurrency)));
      case 'Subscriptions':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsScreen()));
      case 'Reminders':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen()));
      case 'Saving Goals':
        Navigator.push(context, MaterialPageRoute(builder: (_) => SavingGoalsScreen(initialCurrency: _selectedCurrency)));
      case 'Accounts':
        _showAccountsSheet(context, state);
    }
  }

  void _showAccountsSheet(BuildContext parentCtx, AppState state) {
    showModalBottomSheet(
      context: parentCtx,
      backgroundColor: TC.card(parentCtx),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        final wallets = state.wallets;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(parentCtx), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Your Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(parentCtx))),
                    const Spacer(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _showAddAccountSheet(parentCtx, state);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.green.withValues(alpha: 0.3))),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add, color: AppColors.green, size: 16), SizedBox(width: 4), Text('Add Account', style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w700))]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (wallets.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    const Text('💳', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text('No accounts yet', style: TextStyle(fontSize: 14, color: TC.text2(parentCtx))),
                    const SizedBox(height: 4),
                    Text('Tap "Add Account" to create one', style: TextStyle(fontSize: 12, color: TC.text3(parentCtx))),
                  ]),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(parentCtx).size.height * 0.4),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: wallets.entries.map((e) {
                    final curData = AppState.currencies.firstWhere((c) => c.code == e.key, orElse: () => CurrencyData(e.key, e.key, '💱', e.key));
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(sheetCtx);
                        setState(() {
                          _selectedCurrency = e.key;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: TC.card2(parentCtx), borderRadius: BorderRadius.circular(16), border: Border.all(color: TC.border(parentCtx))),
                        child: Row(
                          children: [
                            Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.greenDim, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(curData.flag, style: const TextStyle(fontSize: 22))),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${curData.code} Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(parentCtx))),
                              Text(curData.name, style: TextStyle(fontSize: 11, color: TC.text3(parentCtx))),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('${curData.sym}${AppCurrencyUtils.formatAmount(e.value.abs(), 0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: e.value >= 0 ? AppColors.green : AppColors.red)),
                              Text(e.value >= 0 ? 'Balance' : 'Deficit', style: TextStyle(fontSize: 10, color: TC.text3(parentCtx))),
                            ]),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, color: TC.text3(parentCtx), size: 20),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showAddAccountSheet(BuildContext parentCtx, AppState state) {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!parentCtx.mounted) return;
      final existing = state.wallets.keys.toSet();
      final available = AppState.currencies.where((c) => !existing.contains(c.code)).toList();
      showModalBottomSheet(
        context: parentCtx,
        backgroundColor: TC.card(parentCtx),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetCtx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(parentCtx), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Add New Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(parentCtx)))),
                const SizedBox(height: 4),
                Text('Select a currency for your new account', style: TextStyle(fontSize: 12, color: TC.text3(parentCtx))),
                const SizedBox(height: 16),
                if (available.isEmpty)
                  Padding(padding: const EdgeInsets.all(32), child: Text('All currencies already have accounts', style: TextStyle(color: TC.text2(parentCtx), fontSize: 14))),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(parentCtx).size.height * 0.5),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: available.length,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemBuilder: (_, i) {
                      final c = available[i];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(sheetCtx);
                          _showBudgetSetupSheet(parentCtx, state, c);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: TC.card2(parentCtx), borderRadius: BorderRadius.circular(14), border: Border.all(color: TC.border(parentCtx))),
                          child: Row(children: [
                            Text(c.flag, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${c.code} - ${c.name}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TC.text(parentCtx))),
                              Text('Symbol: ${c.sym}', style: TextStyle(fontSize: 11, color: TC.text3(parentCtx))),
                            ])),
                            const Icon(Icons.add_circle_outline, color: AppColors.green, size: 22),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    });
  }

  void _showBudgetSetupSheet(BuildContext parentCtx, AppState state, CurrencyData c) {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!parentCtx.mounted) return;
      double amount = 0;
      bool isWeekly = false;

      showModalBottomSheet(
        context: parentCtx,
        backgroundColor: TC.card(parentCtx),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetCtx) {
          return StatefulBuilder(builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Setup Account Budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context)))),
                    const SizedBox(height: 4),
                    Text('Optional budget for your ${c.code} account', style: TextStyle(fontSize: 12, color: TC.text3(context))),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: TC.card2(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: TC.border(context))),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isWeekly = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(color: !isWeekly ? AppColors.green : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                  alignment: Alignment.center,
                                  child: Text('Monthly', style: TextStyle(color: !isWeekly ? Colors.white : TC.text2(context), fontWeight: FontWeight.w700, fontSize: 13)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isWeekly = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(color: isWeekly ? AppColors.green : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                  alignment: Alignment.center,
                                  child: Text('Weekly', style: TextStyle(color: isWeekly ? Colors.white : TC.text2(context), fontWeight: FontWeight.w700, fontSize: 13)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: '${c.sym} ',
                          prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.green),
                          border: InputBorder.none,
                          filled: true,
                          fillColor: TC.card2(context),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onChanged: (v) => amount = double.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () {
                          state.createWallet(c.code, 0);
                          if (amount > 0) {
                            final mBudget = isWeekly ? amount * 4.33 : amount;
                            state.setBudgetLimit('_overall', c.code, mBudget);
                          }
                          final code = c.code;
                          final currCtx = parentCtx;
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(currCtx).showSnackBar(SnackBar(content: Text('${c.flag} $code account created!'), backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                          
                          Future.delayed(const Duration(milliseconds: 300), () {
                            showDialog(
                              context: currCtx,
                              builder: (dlCtx) => AlertDialog(
                                backgroundColor: TC.surface(currCtx),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('Set a Saving Goal?', style: TextStyle(color: TC.text(currCtx), fontWeight: FontWeight.w800)),
                                content: Text('Would you like to set a saving goal (like a car or new house) for your $code account?', style: TextStyle(color: TC.text2(currCtx))),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dlCtx), child: Text('Not Now', style: TextStyle(color: TC.text3(currCtx)))),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(dlCtx);
                                      Navigator.push(currCtx, MaterialPageRoute(builder: (_) => SavingGoalsScreen(initialCurrency: code)));
                                    },
                                    child: const Text('Add Goal', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            );
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                          alignment: Alignment.center,
                          child: const Text('Create Account', style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          });
        },
      );
    });
  }
}

// ─── Tab widget ───────────────────────────────────────────────────────────────
class _TypeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeTab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                label,
                style: TextStyle(
                  color: active ? TC.text(context) : TC.text3(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              color: active ? AppColors.green : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pill button ──────────────────────────────────────────────────────────────
class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.greenDim,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.green, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Side Drawer ──────────────────────────────────────────────────────────────
class _MoneyDrawer extends StatelessWidget {
  const _MoneyDrawer();

  @override
  Widget build(BuildContext context) {
    final items = [
      _DrawerItem(Icons.account_balance_wallet_outlined, 'Accounts'),
      _DrawerItem(Icons.bar_chart_rounded, 'Charts'),
      _DrawerItem(Icons.repeat_rounded, 'Subscriptions'),
      _DrawerItem(Icons.notifications_outlined, 'Reminders'),
      _DrawerItem(Icons.track_changes_outlined, 'Saving Goals'),
    ];

    return SafeArea(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.greenDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('💰',
                      style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Text(
                  'Money Manager',
                  style: TextStyle(
                    color: TC.text(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: items.map((item) {
                return ListTile(
                  leading: Icon(item.icon, color: TC.text2(context)),
                  title: Text(item.label,
                      style: TextStyle(
                        color: TC.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      )),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, item.label);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String label;
  const _DrawerItem(this.icon, this.label);
}

// ─── Donut Chart Painter ──────────────────────────────────────────────────────
class _DonutSlice {
  final double value; // 0..1
  final Color color;
  const _DonutSlice({required this.value, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSlice> slices;
  final Color ringColor;
  final Color bgColor;

  const _DonutPainter({
    required this.slices,
    required this.ringColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 4;
    const strokeW = 26.0;
    const gap = 0.020;

    if (slices.isEmpty) {
      // Dashed empty ring
      final paint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW;
      canvas.drawCircle(center, outerR - strokeW / 2, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweepAngle = slice.value * 2 * math.pi - gap;
      if (sweepAngle <= 0) {
        startAngle += slice.value * 2 * math.pi;
        continue;
      }
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerR - strokeW / 2),
        startAngle + gap / 2,
        sweepAngle,
        false,
        paint,
      );
      startAngle += slice.value * 2 * math.pi;
    }

    // Inner fill
    canvas.drawCircle(
        center,
        outerR - strokeW,
        Paint()
          ..color = bgColor
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.ringColor != ringColor;
}
