import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

/// Provider-based state. On first launch it seeds sample data; afterwards it
/// loads everything from SQLite so data survives app restarts.
class AppState extends ChangeNotifier {
  // ─── Loading flag ────────────────────────────────────────────────────────
  bool isLoading = true;

  // ─── Theme ───────────────────────────────────────────────────────────────
  late ThemeMode themeMode;

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    SharedPreferences.getInstance()
        .then((p) => p.setBool('dark_mode', themeMode == ThemeMode.dark));
    notifyListeners();
  }

  bool get isDark => themeMode == ThemeMode.dark;

  // ─── Language / Locale ───────────────────────────────────────────────────
  late Locale locale;

  Future<void> setLocale(Locale l) async {
    locale = l;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', l.languageCode);
    notifyListeners();
  }

  // ─── Currency / static data ──────────────────────────────────────────────
  static const List<CurrencyData> currencies = [
    CurrencyData('EUR', 'Euro', '🇪🇺', '€'),
    CurrencyData('USD', 'US Dollar', '🇺🇸', '\$'),
    CurrencyData('GBP', 'Pound Sterling', '🇬🇧', '£'),
    CurrencyData('HUF', 'Hungarian Forint', '🇭🇺', 'Ft'),
    CurrencyData('PKR', 'Pakistani Rupee', '🇵🇰', '₨'),
    CurrencyData('INR', 'Indian Rupee', '🇮🇳', '₹'),
    CurrencyData('TRY', 'Turkish Lira', '🇹🇷', '₺'),
    CurrencyData('AED', 'UAE Dirham', '🇦🇪', 'د.إ'),
    CurrencyData('SAR', 'Saudi Riyal', '🇸🇦', '﷼'),
    CurrencyData('CHF', 'Swiss Franc', '🇨🇭', 'Fr'),
    CurrencyData('CAD', 'Canadian Dollar', '🇨🇦', 'C\$'),
    CurrencyData('AUD', 'Australian Dollar', '🇦🇺', 'A\$'),
    CurrencyData('JPY', 'Japanese Yen', '🇯🇵', '¥'),
    CurrencyData('CNY', 'Chinese Yuan', '🇨🇳', '¥'),
    CurrencyData('KRW', 'South Korean Won', '🇰🇷', '₩'),
    CurrencyData('BRL', 'Brazilian Real', '🇧🇷', 'R\$'),
    CurrencyData('MXN', 'Mexican Peso', '🇲🇽', '\$'),
    CurrencyData('PLN', 'Polish Zloty', '🇵🇱', 'zł'),
    CurrencyData('SEK', 'Swedish Krona', '🇸🇪', 'kr'),
    CurrencyData('NOK', 'Norwegian Krone', '🇳🇴', 'kr'),
    CurrencyData('DKK', 'Danish Krone', '🇩🇰', 'kr'),
    CurrencyData('CZK', 'Czech Koruna', '🇨🇿', 'Kč'),
    CurrencyData('RON', 'Romanian Leu', '🇷🇴', 'lei'),
    CurrencyData('BGN', 'Bulgarian Lev', '🇧🇬', 'лв'),
    CurrencyData('RUB', 'Russian Ruble', '🇷🇺', '₽'),
    CurrencyData('UAH', 'Ukrainian Hryvnia', '🇺🇦', '₴'),
    CurrencyData('EGP', 'Egyptian Pound', '🇪🇬', '£'),
    CurrencyData('NGN', 'Nigerian Naira', '🇳🇬', '₦'),
    CurrencyData('KES', 'Kenyan Shilling', '🇰🇪', 'KSh'),
    CurrencyData('ZAR', 'South African Rand', '🇿🇦', 'R'),
    CurrencyData('GHS', 'Ghanaian Cedi', '🇬🇭', '₵'),
    CurrencyData('MAD', 'Moroccan Dirham', '🇲🇦', 'د.م.'),
    CurrencyData('BDT', 'Bangladeshi Taka', '🇧🇩', '৳'),
    CurrencyData('MYR', 'Malaysian Ringgit', '🇲🇾', 'RM'),
    CurrencyData('IDR', 'Indonesian Rupiah', '🇮🇩', 'Rp'),
    CurrencyData('PHP', 'Philippine Peso', '🇵🇭', '₱'),
    CurrencyData('THB', 'Thai Baht', '🇹🇭', '฿'),
    CurrencyData('VND', 'Vietnamese Dong', '🇻🇳', '₫'),
    CurrencyData('SGD', 'Singapore Dollar', '🇸🇬', 'S\$'),
    CurrencyData('HKD', 'Hong Kong Dollar', '🇭🇰', 'HK\$'),
    CurrencyData('TWD', 'Taiwan Dollar', '🇹🇼', 'NT\$'),
    CurrencyData('NZD', 'New Zealand Dollar', '🇳🇿', 'NZ\$'),
    CurrencyData('ARS', 'Argentine Peso', '🇦🇷', '\$'),
    CurrencyData('CLP', 'Chilean Peso', '🇨🇱', '\$'),
    CurrencyData('COP', 'Colombian Peso', '🇨🇴', '\$'),
    CurrencyData('PEN', 'Peruvian Sol', '🇵🇪', 'S/.'),
    CurrencyData('QAR', 'Qatari Riyal', '🇶🇦', 'ر.ق'),
    CurrencyData('KWD', 'Kuwaiti Dinar', '🇰🇼', 'د.ك'),
    CurrencyData('BHD', 'Bahraini Dinar', '🇧🇭', '.د.ب'),
    CurrencyData('OMR', 'Omani Rial', '🇴🇲', 'ر.ع.'),
    CurrencyData('JOD', 'Jordanian Dinar', '🇯🇴', 'د.ا'),
    CurrencyData('LBP', 'Lebanese Pound', '🇱🇧', 'ل.ل'),
    CurrencyData('IQD', 'Iraqi Dinar', '🇮🇶', 'ع.د'),
    CurrencyData('DZD', 'Algerian Dinar', '🇩🇿', 'د.ج'),
    CurrencyData('TND', 'Tunisian Dinar', '🇹🇳', 'د.ت'),
    CurrencyData('LKR', 'Sri Lankan Rupee', '🇱🇰', 'රු'),
    CurrencyData('NPR', 'Nepalese Rupee', '🇳🇵', 'रु'),
    CurrencyData('MNT', 'Mongolian Tögrög', '🇲🇳', '₮'),
    CurrencyData('BND', 'Brunei Dollar', '🇧🇳', 'B\$'),
    CurrencyData('MMK', 'Myanmar Kyat', '🇲🇲', 'Ks'),
    CurrencyData('KHR', 'Cambodian Riel', '🇰🇭', '៛'),
    CurrencyData('LAK', 'Lao Kip', '🇱🇦', '₭'),
    CurrencyData('MOP', 'Macanese Pataca', '🇲🇴', 'MOP\$'),
    CurrencyData('TZS', 'Tanzanian Shilling', '🇹🇿', 'TSh'),
    CurrencyData('UGX', 'Ugandan Shilling', '🇺🇬', 'USh'),
    CurrencyData('ZMW', 'Zambian Kwacha', '🇿🇲', 'ZK'),
    CurrencyData('MZN', 'Mozambican Metical', '🇲🇿', 'MT'),
    CurrencyData('BWP', 'Botswana Pula', '🇧🇼', 'P'),
    CurrencyData('NAD', 'Namibian Dollar', '🇳🇦', 'N\$'),
    CurrencyData('AOA', 'Angolan Kwanza', '🇦🇴', 'Kz'),
    CurrencyData('XOF', 'CFA Franc BCEAO', '🌍', 'CFA'),
    CurrencyData('XAF', 'CFA Franc BEAC', '🌍', 'FCFA'),
    CurrencyData('GMD', 'Gambian Dalasi', '🇬🇲', 'D'),
    CurrencyData('MUR', 'Mauritian Rupee', '🇲🇺', '₨'),
    CurrencyData('SCR', 'Seychellois Rupee', '🇸🇨', '₨'),
    CurrencyData('MGA', 'Malagasy Ariary', '🇲🇬', 'Ar'),
    CurrencyData('MWK', 'Malawian Kwacha', '🇲🇼', 'MK'),
    CurrencyData('RWF', 'Rwandan Franc', '🇷🇼', 'FRw'),
    CurrencyData('BIF', 'Burundian Franc', '🇧🇮', 'FBu'),
    CurrencyData('ETB', 'Ethiopian Birr', '🇪🇹', 'Br'),
    CurrencyData('SOS', 'Somali Shilling', '🇸🇴', 'Sh.so.'),
    CurrencyData('CRC', 'Costa Rican Colón', '🇨🇷', '₡'),
    CurrencyData('PAB', 'Panamanian Balboa', '🇵🇦', 'B/.'),
    CurrencyData('DOP', 'Dominican Peso', '🇩🇴', 'RD\$'),
    CurrencyData('GTQ', 'Guatemalan Quetzal', '🇬🇹', 'Q'),
    CurrencyData('HNL', 'Honduran Lempira', '🇭🇳', 'L'),
    CurrencyData('NIO', 'Nicaraguan Córdoba', '🇳🇮', 'C\$'),
    CurrencyData('SVC', 'Salvadoran Colón', '🇸🇻', '₡'),
    CurrencyData('CUP', 'Cuban Peso', '🇨🇺', '₱'),
    CurrencyData('BSD', 'Bahamian Dollar', '🇧🇸', 'B\$'),
    CurrencyData('BBD', 'Barbadian Dollar', '🇧🇧', 'Bds\$'),
    CurrencyData('JMD', 'Jamaican Dollar', '🇯🇲', 'J\$'),
    CurrencyData('TTD', 'Trinidad and Tobago Dollar', '🇹🇹', 'TT\$'),
    CurrencyData('XCD', 'East Caribbean Dollar', '🏖️', 'EC\$'),
    CurrencyData('GYD', 'Guyanese Dollar', '🇬🇾', 'G\$'),
    CurrencyData('SRD', 'Surinamese Dollar', '🇸🇷', 'Sr\$'),
    CurrencyData('BOB', 'Bolivian Boliviano', '🇧🇴', 'Bs.'),
    CurrencyData('PYG', 'Paraguayan Guaraní', '🇵🇾', '₲'),
    CurrencyData('UYU', 'Uruguayan Peso', '🇺🇾', '\$U'),
    CurrencyData('VEF', 'Venezuelan Bolívar', '🇻🇪', 'Bs'),
    CurrencyData('FJD', 'Fijian Dollar', '🇫🇯', 'FJ\$'),
    CurrencyData('WST', 'Samoan Tala', '🇼🇸', 'WS\$'),
    CurrencyData('TOP', 'Tongan Paʻanga', '🇹🇴', 'T\$'),
    CurrencyData('SBD', 'Solomon Islands Dollar', '🇸🇧', 'SI\$'),
    CurrencyData('VUV', 'Vanuatu Vatu', '🇻🇺', 'VT'),
    CurrencyData('PGK', 'Papua New Guinean Kina', '🇵🇬', 'K'),
    CurrencyData('ISK', 'Icelandic Króna', '🇮🇸', 'kr'),
    CurrencyData('RSD', 'Serbian Dinar', '🇷🇸', 'дин.'),
    CurrencyData('BAM', 'Bosnia and Herzegovina Convertible Mark', '🇧🇦', 'KM'),
    CurrencyData('ALL', 'Albanian Lek', '🇦🇱', 'L'),
    CurrencyData('MKD', 'Macedonian Denar', '🇲🇰', 'ден'),
    CurrencyData('GEL', 'Georgian Lari', '🇬🇪', '₾'),
    CurrencyData('AMD', 'Armenian Dram', '🇦🇲', '֏'),
    CurrencyData('AZN', 'Azerbaijani Manat', '🇦🇿', '₼'),
    CurrencyData('KZT', 'Kazakhstani Tenge', '🇰🇿', '₸'),
    CurrencyData('UZS', 'Uzbekistani Som', '🇺🇿', 'лв'),
    CurrencyData('AFN', 'Afghan Afghani', '🇦🇫', '؋'),
  ];

  static const List<String> emojis = [
    '✈️',
    '🏖️',
    '🏠',
    '🍽️',
    '🎉',
    '🚗',
    '🏰',
    '🎮',
    '🏋️',
    '🛒',
    '🎓',
    '💼',
    '🎵',
    '⚽',
    '🌍',
    '🎁',
    '🍕',
    '☕',
    '🎸',
    '🏔️',
    '🚢',
    '🎭',
  ];

  static const List<CategoryItem> expenseCategories = [
    CategoryItem('🍽️', 'Food', '#FF5252'), // Vibrant Red
    CategoryItem('🚗', 'Transport', '#448AFF'), // Vibrant Blue
    CategoryItem('🛒', 'Shopping', '#FFC107'), // Amber
    CategoryItem('🎫', 'Activity', '#E040FB'), // Purple
    CategoryItem('💡', 'Bills', '#00E676'), // Spring Green
    CategoryItem('🏠', 'Rent', '#FF9100'), // Deep Orange
    CategoryItem('🎉', 'Fun', '#FF4081'), // Pink
    CategoryItem('💊', 'Health', '#1DE9B6'), // Teal
    CategoryItem('📚', 'Education', '#546E7A'), // Blue Grey
    CategoryItem('✈️', 'Travel', '#00B0FF'), // Light Blue
    CategoryItem('💰', 'Other', '#9E9E9E'), // Grey
  ];

  static const List<CategoryItem> incomeCategories = [
    CategoryItem('💼', 'Salary', '#00C853'), // Green
    CategoryItem('💻', 'Freelance', '#2979FF'), // Blue
    CategoryItem('🎁', 'Gift', '#FFD600'), // Yellow
    CategoryItem('📈', 'Investment', '#7C4DFF'), // Deep Purple
    CategoryItem('📚', 'Scholarship', '#00B8D4'), // Cyan
    CategoryItem('🏧', 'Allowance', '#FFAB00'), // Amber
    CategoryItem('🏠', 'Rent Income', '#64DD17'), // Light Green
    CategoryItem('💰', 'Other', '#757575'), // Grey
  ];

  static const List<String> settleMethods = [
    'Cash',
    'Revolut',
    'Bank transfer',
    'PayPal',
    'Wise',
    'Other',
  ];

  // ─── Runtime data ────────────────────────────────────────────────────────
  List<GroupData> groups = [];
  Map<String, double> wallets = {}; // Personal Finance wallets
  Map<String, double> groupWallets = {}; // explicitly tracked group currencies
  List<TransactionData> transactions = [];
  List<SubscriptionData> subscriptions = [];
  List<ReminderData> reminders = [];
  List<SavingGoal> savingGoals = [];
  GroupData? currentGroup;

  /// Budget limits: category emoji → limit amount (per currency group)
  Map<String, double> budgetLimits = {};

  // ─── Init / load ─────────────────────────────────────────────────────────
  AppState({
    Locale? initialLocale,
    bool? initialDarkMode,
  }) {
    locale = initialLocale ?? const Locale('en');
    themeMode = (initialDarkMode ?? true) ? ThemeMode.dark : ThemeMode.light;
  }

  /// Public startup loader — call this once from main.dart before runApp().
  Future<void> loadInitialData() async {
    await _load();
  }

  Future<void> _load() async {
    isLoading = true;
    notifyListeners();

    final db = DatabaseService.instance;

    groups = await db.loadGroups();
    transactions = await db.loadTransactions();
    wallets = await db.loadWallets();
    groupWallets = await db.loadGroupWallets();
    budgetLimits = await db.loadBudgetLimits();
    subscriptions = await db.loadSubscriptions();
    reminders = await db.loadReminders();
    savingGoals = (await db.loadSavingGoals()).map((r) => SavingGoal.fromMap(r)).toList();

    // Seed sample data only on very first launch (empty DB)
    if (groups.isEmpty && transactions.isEmpty) {
      await _seedSampleData(db);
      groups = await db.loadGroups();
      transactions = await db.loadTransactions();
      wallets = await db.loadWallets();
      groupWallets = await db.loadGroupWallets();
      budgetLimits = await db.loadBudgetLimits();
      subscriptions = await db.loadSubscriptions();
      reminders = await db.loadReminders();
      savingGoals = (await db.loadSavingGoals()).map((r) => SavingGoal.fromMap(r)).toList();
    }

    isLoading = false;
    notifyListeners();
  }

  /// Public reload — called by BackupService after a restore so the UI
  /// reflects the newly imported data without restarting the app.
  Future<void> reloadFromDatabase() async {
    isLoading = true;
    notifyListeners();

    final db = DatabaseService.instance;
    groups = await db.loadGroups();
    transactions = await db.loadTransactions();
    wallets = await db.loadWallets();
    groupWallets = await db.loadGroupWallets();
    budgetLimits = await db.loadBudgetLimits();
    subscriptions = await db.loadSubscriptions();
    reminders = await db.loadReminders();
    savingGoals = (await db.loadSavingGoals()).map((r) => SavingGoal.fromMap(r)).toList();

    isLoading = false;
    _cachedAllTxns = null;
    notifyListeners();
  }

  Future<void> _seedSampleData(DatabaseService db) async {
    // Group 1
    final g1 = GroupData(
      id: 1,
      name: 'Budapest Trip',
      emoji: '🏰',
      currency: 'EUR',
      sym: '€',
      members: ['You', 'Ali', 'Sara'],
      expenses: [
        ExpenseData(
          id: 101,
          desc: 'Dinner at Vaci St',
          amount: 42,
          cat: '🍽️',
          paidBy: 'You',
          date: '2h ago',
        ),
        ExpenseData(
          id: 102,
          desc: 'Thermal Bath',
          amount: 36,
          cat: '🎫',
          paidBy: 'Ali',
          date: 'Yesterday',
        ),
        ExpenseData(
          id: 103,
          desc: 'Uber to airport',
          amount: 18,
          cat: '🚗',
          paidBy: 'Sara',
          date: '2 days ago',
        ),
      ],
    );
    await db.insertGroup(g1);
    for (final e in g1.expenses) {
      await db.insertExpense(g1.id, e);
    }

    // Group 2
    final g2 = GroupData(
      id: 2,
      name: 'Roommates',
      emoji: '🏠',
      currency: 'HUF',
      sym: 'Ft',
      members: ['You', 'Hamza', 'Petra'],
      expenses: [
        ExpenseData(
          id: 201,
          desc: 'Groceries',
          amount: 8000,
          cat: '🛒',
          paidBy: 'Hamza',
          date: '3 days ago',
        ),
        ExpenseData(
          id: 202,
          desc: 'Internet',
          amount: 4500,
          cat: '💡',
          paidBy: 'You',
          date: '1 week ago',
        ),
      ],
    );
    await db.insertGroup(g2);
    for (final e in g2.expenses) {
      await db.insertExpense(g2.id, e);
    }

    // Transactions
    final txns = [
      TransactionData(
        id: 1001,
        type: 'expense',
        desc: 'Coffee',
        amount: 3.5,
        cat: '☕',
        currency: 'EUR',
        sym: '€',
        date: 'Today',
      ),
      TransactionData(
        id: 1002,
        type: 'income',
        desc: 'Scholarship',
        amount: 500,
        cat: '📚',
        currency: 'EUR',
        sym: '€',
        date: '1 Mar',
      ),
      TransactionData(
        id: 1003,
        type: 'expense',
        desc: 'Bus pass',
        amount: 9.5,
        cat: '🚗',
        currency: 'EUR',
        sym: '€',
        date: '28 Feb',
      ),
    ];
    for (final t in txns) {
      await db.insertTransactionRaw(t);
    }

    // No pre-seeded wallets — user creates them via the Currencies tab
  }

  // ─── Balance logic ───────────────────────────────────────────────────────
  Map<String, double> getAllBalances(GroupData g) {
    final bal = <String, double>{};
    for (final m in g.members) {
      bal[m] = 0;
    }

    for (final e in g.expenses) {
      if (e.splits != null && e.splits!.isNotEmpty) {
        final rawTotal = e.splits!.values.fold(0.0, (s, v) => s + v);
        final needsNormalize =
            rawTotal > 0 && (rawTotal - e.amount).abs() > 0.01;
        final scale = needsNormalize ? e.amount / rawTotal : 1.0;

        for (final m in g.members) {
          final share = (e.splits![m] ?? 0) * scale;
          if (e.paidBy == m) {
            bal[m] = (bal[m] ?? 0) + e.amount - share;
          } else {
            bal[m] = (bal[m] ?? 0) - share;
          }
        }
      } else {
        final share = e.amount / g.members.length;
        for (final m in g.members) {
          if (e.paidBy == m) {
            bal[m] = (bal[m] ?? 0) + e.amount - share;
          } else {
            bal[m] = (bal[m] ?? 0) - share;
          }
        }
      }
    }

    for (final s in g.settlements) {
      bal[s.from] = (bal[s.from] ?? 0) + s.amount;
      bal[s.to] = (bal[s.to] ?? 0) - s.amount;
    }

    bal.updateAll((k, v) => double.parse(v.toStringAsFixed(2)));
    return bal;
  }

  double getMyBalance(GroupData g) => getAllBalances(g)['You'] ?? 0;

  double getGroupWalletBalance(String currency) {
    double total = 0.0;
    for (final g in activeGroups.where((x) => x.currency == currency)) {
      total += getMyBalance(g);
    }
    return total;
  }

  List<SettlePair> buildSettlePlan(GroupData g) {
    final balances = getAllBalances(g);

    final creditors = balances.entries
        .where((e) => e.value > 0.01)
        .map((e) => _Pair(e.key, e.value))
        .toList()
      ..sort((a, b) => b.amt.compareTo(a.amt));

    final debtors = balances.entries
        .where((e) => e.value < -0.01)
        .map((e) => _Pair(e.key, e.value.abs()))
        .toList()
      ..sort((a, b) => b.amt.compareTo(a.amt));

    final plan = <SettlePair>[];
    int i = 0, j = 0;

    while (i < creditors.length && j < debtors.length) {
      final amt = creditors[i].amt < debtors[j].amt
          ? creditors[i].amt
          : debtors[j].amt;

      if (amt > 0.01) {
        plan.add(SettlePair(debtors[j].name, creditors[i].name, amt));
      }

      creditors[i].amt -= amt;
      debtors[j].amt -= amt;

      if (creditors[i].amt < 0.01) i++;
      if (debtors[j].amt < 0.01) j++;
    }

    return plan;
  }

  // ─── Mutations ───────────────────────────────────────────────────────────

  Future<void> addGroup(GroupData g) async {
    await DatabaseService.instance.insertGroup(g);
    groups = [g, ...groups];
    _cachedAllTxns = null;
    notifyListeners();
  }

  /// Import a group that was scanned from a QR code.
  /// Returns the newly created [GroupData] so the caller can navigate to it.
  /// Returns the existing group if a group with the same name+currency already exists.
  Future<GroupData?> importGroupFromQR(Map<String, dynamic> json) async {
    try {
      // SEC-5: Validate and sanitize all QR input to prevent injection/data bombs
      var name = (json['name'] as String?)?.trim() ?? 'Imported Group';
      var currency = (json['currency'] as String?) ?? 'USD';
      var sym = (json['sym'] as String?) ?? '\$';
      var emoji = (json['emoji'] as String?) ?? '🌍';
      final rawMembers = (json['members'] as List<dynamic>?) ?? ['You'];

      // Enforce length limits
      if (name.length > 50) name = name.substring(0, 50);
      if (currency.length > 5) currency = currency.substring(0, 5);
      if (sym.length > 5) sym = sym.substring(0, 5);
      if (emoji.length > 10) emoji = emoji.substring(0, 10);

      // Limit member count to prevent data bombs
      final members = rawMembers
          .take(30)
          .map((e) {
            var s = e.toString();
            return s.length > 30 ? s.substring(0, 30) : s;
          })
          .toList();

      if (!members.contains('You')) {
        members.insert(0, 'You');
      }

      final existing = groups.where((g) {
        return g.name.trim().toLowerCase() == name.toLowerCase() &&
            g.currency == currency;
      }).toList();

      if (existing.isNotEmpty) {
        return existing.first;
      }

      final newId = DateTime.now().microsecondsSinceEpoch;

      final g = GroupData(
        id: newId,
        name: name,
        emoji: emoji,
        currency: currency,
        sym: sym,
        members: members,
        expenses: [],
        settlements: [],
      );

      await DatabaseService.instance.insertGroup(g);
      groups = [g, ...groups];
      _cachedAllTxns = null;
      notifyListeners();
      return g;
    } catch (_) {
      return null;
    }
  }

  Future<void> addExpenseToGroup(GroupData g, ExpenseData e) async {
    await DatabaseService.instance.insertExpense(g.id, e);
    g.expenses = [e, ...g.expenses];
    groups = List.of(groups);
    _cachedAllTxns = null;
    notifyListeners();
  }

  Future<void> editExpenseInGroup(
    GroupData g,
    ExpenseData oldExp,
    ExpenseData newExp,
  ) async {
    await DatabaseService.instance.updateExpense(g.id, newExp);
    final idx = g.expenses.indexOf(oldExp);
    if (idx >= 0) {
      g.expenses = [
        ...g.expenses.sublist(0, idx),
        newExp,
        ...g.expenses.sublist(idx + 1),
      ];
    }
    groups = List.of(groups);
    _cachedAllTxns = null;
    notifyListeners();
  }

  Future<void> deleteExpense(GroupData g, ExpenseData e) async {
    await DatabaseService.instance.deleteExpense(e.id);
    g.expenses = g.expenses.where((x) => x.id != e.id).toList();
    groups = List.of(groups);
    _cachedAllTxns = null;
    notifyListeners();
  }

  Future<void> recordSettlement(GroupData g, SettlementData s) async {
    await DatabaseService.instance.insertSettlement(g.id, s);
    g.settlements = [...g.settlements, s];
    groups = List.of(groups);
    notifyListeners();
  }

  Future<void> archiveGroup(GroupData g) async {
    await DatabaseService.instance.setGroupArchived(g.id, true);
    g.isArchived = true;
    groups = List.of(groups);
    notifyListeners();
  }

  Future<void> unarchiveGroup(GroupData g) async {
    await DatabaseService.instance.setGroupArchived(g.id, false);
    g.isArchived = false;
    groups = List.of(groups);
    notifyListeners();
  }

  Future<void> deleteGroup(GroupData g) async {
    await DatabaseService.instance.deleteGroup(g.id);
    groups = groups.where((x) => x.id != g.id).toList();
    if (currentGroup?.id == g.id) currentGroup = null;
    _cachedAllTxns = null;
    notifyListeners();
  }

  Future<void> addTransaction(TransactionData t) async {
    final cur = wallets[t.currency] ?? 0;
    final newBal = double.parse(
      (t.type == 'expense' ? cur - t.amount : cur + t.amount)
          .toStringAsFixed(2),
    );

    try {
      await DatabaseService.instance.insertTransactionAtomic(t, newBal);
    } catch (_) {
      rethrow;
    }

    transactions = [t, ...transactions];
    wallets = Map.of(wallets)..[t.currency] = newBal;
    _cachedAllTxns = null;
    notifyListeners();
  }

  Future<void> editTransaction(
    TransactionData old,
    TransactionData updated,
  ) async {
    final idx = transactions.indexWhere((t) => t.id == old.id);
    final workingWallets = Map.of(wallets);

    final oldCur = workingWallets[old.currency] ?? 0;
    final reversedOld = double.parse(
      (old.type == 'expense' ? oldCur + old.amount : oldCur - old.amount)
          .toStringAsFixed(2),
    );

    final newCur = old.currency == updated.currency ? reversedOld : (workingWallets[updated.currency] ?? 0);
    final newBal = double.parse(
      (updated.type == 'expense' ? newCur - updated.amount : newCur + updated.amount)
          .toStringAsFixed(2),
    );

    try {
      await DatabaseService.instance.updateTransactionAtomic(updated, old.currency, reversedOld, newBal);
    } catch (_) {
      rethrow;
    }

    if (idx >= 0) {
      transactions = [
        ...transactions.sublist(0, idx),
        updated,
        ...transactions.sublist(idx + 1),
      ];
    }
    workingWallets[old.currency] = reversedOld;
    workingWallets[updated.currency] = newBal;
    wallets = workingWallets;
    _cachedAllTxns = null;
    notifyListeners();
  }

  Future<void> deleteTransaction(TransactionData t) async {
    final cur = wallets[t.currency] ?? 0;
    final newBal = double.parse(
      (t.type == 'expense' ? cur + t.amount : cur - t.amount)
          .toStringAsFixed(2),
    );

    try {
      await DatabaseService.instance.deleteTransactionAtomic(t.id, t.currency, newBal);
    } catch (_) {
      rethrow;
    }

    transactions = transactions.where((x) => x.id != t.id).toList();
    wallets = Map.of(wallets)..[t.currency] = newBal;
    _cachedAllTxns = null;
    notifyListeners();
  }

  Future<void> resetAllData() async {
    await DatabaseService.instance.clearAll();
    groups = [];
    transactions = [];
    wallets = {};
    groupWallets = {};
    budgetLimits = {};
    subscriptions = [];
    reminders = [];
    currentGroup = null;
    notifyListeners();
  }

  // ─── Wallet management ───────────────────────────────────────────────────

  Future<void> createWallet(String currency, double initialBalance) async {
    await DatabaseService.instance.upsertWallet(currency, initialBalance);
    wallets = Map.of(wallets)..[currency] = initialBalance;
    notifyListeners();
  }

  Future<void> deleteWallet(String currency) async {
    await DatabaseService.instance.deleteWallet(currency);
    wallets = Map.of(wallets)..remove(currency);
    notifyListeners();
  }

  Future<void> createGroupWallet(String currency, double initialBalance) async {
    await DatabaseService.instance.upsertGroupWallet(currency, initialBalance);
    groupWallets = Map.of(groupWallets)..[currency] = initialBalance;
    notifyListeners();
  }

  Future<void> deleteGroupWallet(String currency) async {
    await DatabaseService.instance.deleteGroupWallet(currency);
    groupWallets = Map.of(groupWallets)..remove(currency);
    notifyListeners();
  }

  // ─── Budget limits ───────────────────────────────────────────────────────

  Future<void> setBudgetLimit(String catIcon, String currency, double limit) async {
    final key = '${catIcon}_$currency';
    await DatabaseService.instance.upsertBudgetLimit(key, limit);
    budgetLimits = Map.of(budgetLimits)..[key] = limit;
    notifyListeners();
  }

  double getBudgetLimit(String catIcon, String currency) =>
      budgetLimits['${catIcon}_$currency'] ?? 0;

  double getMonthlySpending(String catIcon, String currency, DateTime month) {
    return transactions
        .where((t) =>
            t.type == 'expense' &&
            t.cat == catIcon &&
            t.currency == currency &&
            _isSameMonth(t.rawDate, month))
        .fold(0.0, (s, t) => s + t.amount);
  }

  bool _isSameMonth(DateTime? d, DateTime month) {
    if (d == null) return false;
    return d.year == month.year && d.month == month.month;
    }

  // ─── Grouped accessors ───────────────────────────────────────────────────

  List<GroupData> get activeGroups =>
      groups.where((g) => !g.isArchived).toList();

  /// Cached merged list of personal + group transactions.
  /// Invalidated whenever groups or transactions change.
  List<TransactionData>? _cachedAllTxns;

  List<TransactionData> get allTransactionsWithGroupShares {
    if (_cachedAllTxns != null) return _cachedAllTxns!;
    final list = List<TransactionData>.from(transactions);
    for (final g in activeGroups) {
      for (final e in g.expenses) {
        double myShare = 0;
        if (e.splits != null && e.splits!.containsKey('You')) {
          myShare = e.splits!['You']!;
        } else if (g.members.contains('You')) {
          myShare = e.amount / g.members.length;
        } else if (e.paidBy == 'You') {
          myShare = e.amount;
        }
        if (myShare > 0) {
          list.add(TransactionData(
            id: e.id,
            type: 'expense',
            desc: '${g.name}: ${e.desc}',
            amount: myShare,
            cat: e.cat,
            currency: g.currency,
            sym: g.sym,
            date: e.date,
            isGroupShare: true,
            groupId: g.id,
          ));
        }
      }
    }
    _cachedAllTxns = list;
    return list;
  }

  List<GroupData> get archivedGroups =>
      groups.where((g) => g.isArchived).toList();

  List<TransactionData> transactionsForMonth(DateTime month) =>
      transactions.where((t) => _isSameMonth(t.rawDate, month)).toList();

  // ─── Subscription management ─────────────────────────────────────────────

  Future<void> addSubscription(SubscriptionData sub) async {
    final newId = await DatabaseService.instance.insertSubscription(sub);
    final saved = sub.copyWith(id: newId);
    subscriptions = ([saved, ...subscriptions]
      ..sort((a, b) => a.daysUntilBilling.compareTo(b.daysUntilBilling)));
    notifyListeners();
  }

  Future<void> updateSubscription(SubscriptionData sub) async {
    await DatabaseService.instance.updateSubscription(sub);
    final idx = subscriptions.indexWhere((s) => s.id == sub.id);
    if (idx >= 0) {
      subscriptions = [
        ...subscriptions.sublist(0, idx),
        sub,
        ...subscriptions.sublist(idx + 1),
      ]..sort((a, b) => a.daysUntilBilling.compareTo(b.daysUntilBilling));
    }
    notifyListeners();
  }

  Future<void> deleteSubscription(SubscriptionData sub) async {
    await DatabaseService.instance.deleteSubscription(sub.id);
    subscriptions = subscriptions.where((s) => s.id != sub.id).toList();
    notifyListeners();
  }

  Future<void> toggleSubscriptionActive(SubscriptionData sub) async {
    final updated = sub.copyWith(isActive: !sub.isActive);
    await updateSubscription(updated);
  }

  /// Total monthly cost of all active subscriptions across all currencies.
  /// Returns a map of currency code → monthly equivalent.
  Map<String, double> get subscriptionMonthlyCostByCurrency {
    final result = <String, double>{};
    for (final sub in subscriptions.where((s) => s.isActive)) {
      result[sub.currency] = (result[sub.currency] ?? 0) + sub.monthlyEquivalent;
    }
    return result;
  }

  // ─── Reminder management ─────────────────────────────────────────────────

  Future<void> addReminder(ReminderData r) async {
    final newId = await DatabaseService.instance.insertReminder(r);
    final saved = r.copyWith(id: newId);
    reminders = ([saved, ...reminders]..sort((a, b) => a.date.compareTo(b.date)));
    await NotificationService.scheduleReminder(saved);
    notifyListeners();
  }

  Future<void> updateReminder(ReminderData r) async {
    await DatabaseService.instance.updateReminder(r);
    final idx = reminders.indexWhere((x) => x.id == r.id);
    if (idx >= 0) {
      reminders = [
        ...reminders.sublist(0, idx),
        r,
        ...reminders.sublist(idx + 1),
      ]..sort((a, b) => a.date.compareTo(b.date));
    }
    await NotificationService.scheduleReminder(r);
    notifyListeners();
  }

  Future<void> deleteReminder(ReminderData r) async {
    await DatabaseService.instance.deleteReminder(r.id);
    reminders = reminders.where((x) => x.id != r.id).toList();
    await NotificationService.cancelReminder(r.id);
    notifyListeners();
  }

  Future<void> toggleReminderCompleted(ReminderData r) async {
    final updated = r.copyWith(isCompleted: !r.isCompleted);
    await updateReminder(updated);
  }

  // ─── Saving Goals ─────────────────────────────────────────────────────────

  Future<void> addSavingGoal(String currency, String title, double targetAmount, {DateTime? targetDate}) async {
    final data = {
      'currency': currency,
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': 0.0,
      'target_date': targetDate?.toIso8601String(),
    };
    final id = await DatabaseService.instance.insertSavingGoal(data);
    savingGoals.add(SavingGoal(id: id, currency: currency, title: title, targetAmount: targetAmount, targetDate: targetDate));
    notifyListeners();
  }

  Future<void> updateSavingGoal(SavingGoal g, {String? title, double? targetAmount, double? savedAmount, DateTime? targetDate}) async {
    final updated = SavingGoal(
      id: g.id,
      currency: g.currency,
      title: title ?? g.title,
      targetAmount: targetAmount ?? g.targetAmount,
      savedAmount: savedAmount ?? g.savedAmount,
      targetDate: targetDate ?? g.targetDate,
    );
    await DatabaseService.instance.updateSavingGoal(g.id, updated.toMap());
    final idx = savingGoals.indexWhere((x) => x.id == g.id);
    if (idx >= 0) {
      savingGoals[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteSavingGoal(int id) async {
    await DatabaseService.instance.deleteSavingGoal(id);
    savingGoals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  static Color getCategoryColor(String emoji) {
    // Exact match
    var cat = expenseCategories.firstWhere((c) => c.icon == emoji,
        orElse: () => incomeCategories.firstWhere((c) => c.icon == emoji,
            orElse: () => const CategoryItem('', '', '')));
            
    // If not found, try stripping variation selectors
    if (cat.icon.isEmpty) {
      final stripped = emoji.replaceAll(RegExp(r'[\uFE00-\uFE0F]'), '');
      cat = expenseCategories.firstWhere((c) => c.icon.replaceAll(RegExp(r'[\uFE00-\uFE0F]'), '') == stripped,
          orElse: () => incomeCategories.firstWhere((c) => c.icon.replaceAll(RegExp(r'[\uFE00-\uFE0F]'), '') == stripped,
              orElse: () => const CategoryItem('', '', '#9E9E9E')));
    }

    try {
      final hex = cat.color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF9E9E9E);
    }
  }
} // end AppState

// ─── Lightweight data models ───────────────────────────────────────────────

class ReminderData {
  final int id;
  final String title;
  final String amountStr;
  final DateTime date;
  final bool isCompleted;

  ReminderData({
    required this.id,
    required this.title,
    this.amountStr = '',
    required this.date,
    this.isCompleted = false,
  });

  ReminderData copyWith({
    int? id,
    String? title,
    String? amountStr,
    DateTime? date,
    bool? isCompleted,
  }) {
    return ReminderData(
      id: id ?? this.id,
      title: title ?? this.title,
      amountStr: amountStr ?? this.amountStr,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class CurrencyData {
  final String code, name, flag, sym;
  const CurrencyData(this.code, this.name, this.flag, this.sym);
}

class CategoryItem {
  final String icon, label, color;
  const CategoryItem(this.icon, this.label, this.color);
}

class GroupData {
  final int id;
  String name, emoji, currency, sym;
  bool isArchived;
  List<String> members;
  List<ExpenseData> expenses;
  List<SettlementData> settlements;

  GroupData({
    required this.id,
    required this.name,
    required this.emoji,
    required this.currency,
    required this.sym,
    required this.members,
    List<ExpenseData>? expenses,
    List<SettlementData>? settlements,
    this.isArchived = false,
  })  : expenses = expenses ?? [],
        settlements = settlements ?? [];
}

class ExpenseData {
  final int id;
  final String desc, cat, paidBy, date;
  final double amount;
  final bool receipt;
  final String? receiptPath;

  /// Custom per-member split amounts. null = equal split.
  /// Key = member name, value = amount that member owes.
  final Map<String, double>? splits;

  /// JSON encoding of [splits] for database storage.
  String? get splitsJson {
    if (splits == null || splits!.isEmpty) return null;
    return jsonEncode(splits);
  }

  ExpenseData({
    required this.id,
    required this.desc,
    required this.amount,
    required this.cat,
    required this.paidBy,
    required this.date,
    this.receipt = false,
    this.receiptPath,
    this.splits,
  });
}

class TransactionData {
  final int id;
  final String type, desc, cat, currency, sym, date;
  final double amount;
  final String? receiptPath;
  final bool isGroupShare;
  final int? groupId;

  /// Parsed DateTime for month-filtering; null if date was a relative string.
  DateTime? get rawDate => parseDate(date);

  static DateTime? parseDate(String d) {
    try {
      return DateTime.parse(d);
    } catch (_) {}

    final lower = d.trim().toLowerCase();
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    final parts = d.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final day = int.tryParse(parts[0]);
      final mon = months[parts[1].toLowerCase()];
      if (day != null && mon != null) {
        final now = DateTime.now();
        return DateTime(now.year, mon, day);
      }
    }

    if (lower.contains('today')) return DateTime.now();
    if (lower.contains('yesterday')) {
      return DateTime.now().subtract(const Duration(days: 1));
    }

    final agoMatch =
        RegExp(r'(\d+)\s*(day|hour|h|week|min|minute)s?\s*ago').firstMatch(lower);

    if (agoMatch != null) {
      final n = int.tryParse(agoMatch.group(1) ?? '') ?? 0;
      final unit = agoMatch.group(2) ?? '';

      switch (unit) {
        case 'day':
          return DateTime.now().subtract(Duration(days: n));
        case 'hour':
        case 'h':
          return DateTime.now().subtract(Duration(hours: n));
        case 'week':
          return DateTime.now().subtract(Duration(days: n * 7));
        case 'min':
        case 'minute':
          return DateTime.now().subtract(Duration(minutes: n));
      }
    }

    return null;
  }

  const TransactionData({
    required this.id,
    required this.type,
    required this.desc,
    required this.amount,
    required this.cat,
    required this.currency,
    required this.sym,
    required this.date,
    this.receiptPath,
    this.isGroupShare = false,
    this.groupId,
  });
}

class SettlementData {
  final String from, to, method, date;
  final double amount;

  const SettlementData({
    required this.from,
    required this.to,
    required this.amount,
    required this.method,
    required this.date,
  });
}

class SettlePair {
  final String from, to;
  final double amount;
  const SettlePair(this.from, this.to, this.amount);
}

class _Pair {
  final String name;
  double amt;
  _Pair(this.name, this.amt);
}

// ─── Subscription model ────────────────────────────────────────────────────

class BillingCycle {
  static const monthly = 'monthly';
  static const weekly = 'weekly';
  static const yearly = 'yearly';
}

class SubscriptionData {
  final int id;
  final String name;
  final double amount;
  final String currency;
  final String sym;
  final String cycle; // 'monthly' | 'weekly' | 'yearly'
  final int billingDay; // 1-28 for monthly/yearly; 1-7 (Mon-Sun) for weekly
  final int billingMonth; // 1-12, used only for yearly cycle
  final String category;
  final String emoji;
  final String colorHex;
  final bool isActive;
  final DateTime createdAt;

  const SubscriptionData({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.sym,
    required this.cycle,
    required this.billingDay,
    this.billingMonth = 1,
    required this.category,
    required this.emoji,
    required this.colorHex,
    this.isActive = true,
    required this.createdAt,
  });

  SubscriptionData copyWith({
    int? id,
    String? name,
    double? amount,
    String? currency,
    String? sym,
    String? cycle,
    int? billingDay,
    int? billingMonth,
    String? category,
    String? emoji,
    String? colorHex,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      SubscriptionData(
        id: id ?? this.id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        sym: sym ?? this.sym,
        cycle: cycle ?? this.cycle,
        billingDay: billingDay ?? this.billingDay,
        billingMonth: billingMonth ?? this.billingMonth,
        category: category ?? this.category,
        emoji: emoji ?? this.emoji,
        colorHex: colorHex ?? this.colorHex,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  DateTime get nextBillingDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (cycle) {
      case BillingCycle.monthly:
        final day = billingDay.clamp(1, 28);
        var candidate = DateTime(today.year, today.month, day, 9, 0);
        if (!candidate.isAfter(today)) {
          candidate = DateTime(today.year, today.month + 1, day, 9, 0);
        }
        return candidate;

      case BillingCycle.weekly:
        var daysAhead = billingDay - today.weekday;
        if (daysAhead <= 0) daysAhead += 7;
        return today
            .add(Duration(days: daysAhead))
            .add(const Duration(hours: 9));

      case BillingCycle.yearly:
        final day = billingDay.clamp(1, 28);
        final month = billingMonth.clamp(1, 12);
        var candidate = DateTime(today.year, month, day, 9, 0);
        if (!candidate.isAfter(today)) {
          candidate = DateTime(today.year + 1, month, day, 9, 0);
        }
        return candidate;

      default:
        return today.add(const Duration(days: 30));
    }
  }

  int get daysUntilBilling {
    final diff = nextBillingDate.difference(DateTime.now());
    return diff.inDays.clamp(0, 9999);
  }

  bool get isDueSoon => daysUntilBilling <= 3;

  double get monthlyEquivalent {
    switch (cycle) {
      case BillingCycle.weekly:
        return amount * 4.333;
      case BillingCycle.yearly:
        return amount / 12;
      default:
        return amount;
    }
  }

  String get cycleLabel {
    switch (cycle) {
      case BillingCycle.weekly:
        return 'week';
      case BillingCycle.yearly:
        return 'year';
      default:
        return 'month';
    }
  }

  double get cycleProgress {
    final next = nextBillingDate;
    final cycleDays = cycle == BillingCycle.weekly
        ? 7
        : cycle == BillingCycle.yearly
            ? 365
            : 30;
    final prev = next.subtract(Duration(days: cycleDays));
    final elapsed = DateTime.now().difference(prev).inSeconds;
    final total = next.difference(prev).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

class SavingGoal {
  final int id;
  final String currency;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;

  SavingGoal({
    required this.id,
    required this.currency,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0.0,
    this.targetDate,
  });

  factory SavingGoal.fromMap(Map<String, dynamic> map) {
    return SavingGoal(
      id: map['id'] as int,
      currency: (map['currency'] as String?) ?? 'USD',
      title: (map['title'] as String?) ?? '',
      targetAmount: (map['target_amount'] as num?)?.toDouble() ?? 0.0,
      savedAmount: (map['saved_amount'] as num?)?.toDouble() ?? 0.0,
      targetDate: map['target_date'] != null ? DateTime.tryParse(map['target_date']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currency': currency,
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'target_date': targetDate?.toIso8601String(),
    };
  }
}
