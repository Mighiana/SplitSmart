import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/entitlement.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../services/storage_service.dart';

export '../services/entitlement.dart' show AccountTier, Entitlement;

/// Provider-based state. Routes data through Firestore when signed in,
/// falls back to local SQLite otherwise. Subscriptions & reminders
/// always use local SQLite.
class AppState extends ChangeNotifier {
  // ─── Loading flag ────────────────────────────────────────────────────────
  bool isLoading = true;

  /// Current participation tier. Derived from the Firebase session — the
  /// single source of truth that replaces the old `_useCloud == isSignedIn`
  /// shortcut (which would have migrated a guest's local data to a throwaway
  /// anonymous uid).
  AccountTier get tier => accountTierFrom(
        signedIn: AuthService.instance.isSignedIn,
        isAnonymous: AuthService.instance.isGuest,
      );

  /// True when data flows through Firestore (guest OR full account).
  bool get _useCloud => useCloudForTier(tier);
  bool get useCloud => _useCloud;

  /// True when the session is an accountless guest.
  bool get isGuest => tier == AccountTier.guest;

  // ─── Premium entitlement (owner-paid; gates guest-join only) ─────────────
  Entitlement _entitlement = Entitlement.none;
  Entitlement get entitlement => _entitlement;
  bool get hasPremium => _entitlement.isActive;
  StreamSubscription<Map<String, dynamic>?>? _entitlementSub;

  /// Cache key for offline entitlement mirror.
  static const _kEntitlementPrefsKey = 'entitlement_cache';

  // ─── Theme ───────────────────────────────────────────────────────────────
  late ThemeMode themeMode;

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    SharedPreferences.getInstance()
        .then((p) => p.setBool('dark_mode', themeMode == ThemeMode.dark));
    notifyListeners();
  }

  bool get isDark => themeMode == ThemeMode.dark;
  String get userName => AuthService.instance.currentUser?.displayName ?? 'You';

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
    CurrencyData('USD', 'US Dollar', '🇺🇸', '\$'),
    CurrencyData('EUR', 'Euro', '🇪🇺', '€'),
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
    CategoryItem('🍽️', 'Food',       '#FF9800', Icons.restaurant_rounded),
    CategoryItem('🚌', 'Transport',   '#448AFF', Icons.directions_bus_rounded),
    CategoryItem('🛒', 'Shopping',    '#FFC107', Icons.shopping_bag_rounded),
    CategoryItem('🎫', 'Activity',    '#E040FB', Icons.local_activity_rounded),
    CategoryItem('💡', 'Bills',       '#00E676', Icons.receipt_long_rounded),
    CategoryItem('🏠', 'Rent',        '#FF9100', Icons.home_rounded),
    CategoryItem('🎉', 'Fun',         '#7C4DFF', Icons.celebration_rounded),
    CategoryItem('💊', 'Health',      '#1DE9B6', Icons.favorite_rounded),
    CategoryItem('📚', 'Education',   '#546E7A', Icons.school_rounded),
    CategoryItem('✈️', 'Travel',      '#00B0FF', Icons.flight_rounded),
    CategoryItem('💰', 'Other',       '#9E9E9E', Icons.category_rounded),
  ];

  static const List<CategoryItem> incomeCategories = [
    CategoryItem('💼', 'Salary',      '#00C853', Icons.work_rounded),
    CategoryItem('💻', 'Freelance',   '#2979FF', Icons.laptop_rounded),
    CategoryItem('🎁', 'Gift',        '#FFD600', Icons.card_giftcard_rounded),
    CategoryItem('📈', 'Investment',  '#7C4DFF', Icons.trending_up_rounded),
    CategoryItem('📚', 'Scholarship', '#00B8D4', Icons.menu_book_rounded),
    CategoryItem('🏧', 'Allowance',   '#FFAB00', Icons.account_balance_wallet_rounded),
    CategoryItem('🏠', 'Rent Income', '#64DD17', Icons.real_estate_agent_rounded),
    CategoryItem('💰', 'Other',       '#757575', Icons.category_rounded),
  ];

  /// Fixed default sub-categories, keyed by their PARENT category emoji.
  ///
  /// Sub keys use the form `sub:<group>:<name>` so they never collide with the
  /// top-level category emojis and can be stored directly on transactions
  /// (`TransactionData.subcat`) and budgets (`Budget.categories`). Subs inherit
  /// their parent's colour.
  static const Map<String, List<CategoryItem>> subcategories = {
    '🍽️': [
      CategoryItem('sub:food:groceries',   'Groceries',    '#FF9800', Icons.local_grocery_store_rounded),
      CategoryItem('sub:food:restaurant',  'Restaurants',  '#FF9800', Icons.restaurant_menu_rounded),
      CategoryItem('sub:food:coffee',      'Coffee & Tea', '#FF9800', Icons.local_cafe_rounded),
      CategoryItem('sub:food:takeout',     'Takeout',      '#FF9800', Icons.takeout_dining_rounded),
      CategoryItem('sub:food:snacks',      'Snacks',       '#FF9800', Icons.icecream_rounded),
    ],
    '🚌': [
      CategoryItem('sub:transport:fuel',        'Fuel',            '#448AFF', Icons.local_gas_station_rounded),
      CategoryItem('sub:transport:transit',     'Public Transit',  '#448AFF', Icons.directions_subway_rounded),
      CategoryItem('sub:transport:taxi',        'Taxi & Rideshare','#448AFF', Icons.local_taxi_rounded),
      CategoryItem('sub:transport:parking',     'Parking',         '#448AFF', Icons.local_parking_rounded),
      CategoryItem('sub:transport:maintenance', 'Maintenance',     '#448AFF', Icons.build_rounded),
    ],
    '🛒': [
      CategoryItem('sub:shopping:clothing',    'Clothing',      '#FFC107', Icons.checkroom_rounded),
      CategoryItem('sub:shopping:electronics', 'Electronics',   '#FFC107', Icons.devices_rounded),
      CategoryItem('sub:shopping:home',        'Home & Garden', '#FFC107', Icons.chair_rounded),
      CategoryItem('sub:shopping:gifts',       'Gifts',         '#FFC107', Icons.card_giftcard_rounded),
      CategoryItem('sub:shopping:beauty',      'Personal Care', '#FFC107', Icons.spa_rounded),
    ],
    '🎫': [
      CategoryItem('sub:activity:movies',  'Movies',  '#E040FB', Icons.movie_rounded),
      CategoryItem('sub:activity:events',  'Events',  '#E040FB', Icons.confirmation_number_rounded),
      CategoryItem('sub:activity:sports',  'Sports',  '#E040FB', Icons.sports_basketball_rounded),
      CategoryItem('sub:activity:hobbies', 'Hobbies', '#E040FB', Icons.palette_rounded),
    ],
    '💡': [
      CategoryItem('sub:bills:electricity',   'Electricity',   '#00E676', Icons.bolt_rounded),
      CategoryItem('sub:bills:water',         'Water',         '#00E676', Icons.water_drop_rounded),
      CategoryItem('sub:bills:internet',      'Internet',      '#00E676', Icons.wifi_rounded),
      CategoryItem('sub:bills:phone',         'Phone',         '#00E676', Icons.phone_iphone_rounded),
      CategoryItem('sub:bills:subscriptions', 'Subscriptions', '#00E676', Icons.subscriptions_rounded),
    ],
    '🏠': [
      CategoryItem('sub:rent:rent',      'Rent',      '#FF9100', Icons.home_rounded),
      CategoryItem('sub:rent:mortgage',  'Mortgage',  '#FF9100', Icons.account_balance_rounded),
      CategoryItem('sub:rent:utilities', 'Utilities', '#FF9100', Icons.handyman_rounded),
      CategoryItem('sub:rent:insurance', 'Insurance', '#FF9100', Icons.shield_rounded),
    ],
    '🎉': [
      CategoryItem('sub:fun:nightlife', 'Nightlife', '#7C4DFF', Icons.nightlife_rounded),
      CategoryItem('sub:fun:games',     'Games',     '#7C4DFF', Icons.sports_esports_rounded),
      CategoryItem('sub:fun:parties',   'Parties',   '#7C4DFF', Icons.celebration_rounded),
    ],
    '💊': [
      CategoryItem('sub:health:pharmacy',  'Pharmacy', '#1DE9B6', Icons.medication_rounded),
      CategoryItem('sub:health:doctor',    'Doctor',   '#1DE9B6', Icons.medical_services_rounded),
      CategoryItem('sub:health:fitness',   'Fitness',  '#1DE9B6', Icons.fitness_center_rounded),
      CategoryItem('sub:health:insurance', 'Insurance','#1DE9B6', Icons.health_and_safety_rounded),
    ],
    '📚': [
      CategoryItem('sub:education:tuition', 'Tuition', '#546E7A', Icons.school_rounded),
      CategoryItem('sub:education:books',   'Books',   '#546E7A', Icons.menu_book_rounded),
      CategoryItem('sub:education:courses', 'Courses', '#546E7A', Icons.cast_for_education_rounded),
    ],
    '✈️': [
      CategoryItem('sub:travel:flights',   'Flights',   '#00B0FF', Icons.flight_rounded),
      CategoryItem('sub:travel:hotels',    'Hotels',    '#00B0FF', Icons.hotel_rounded),
      CategoryItem('sub:travel:transport', 'Transport', '#00B0FF', Icons.directions_car_rounded),
      CategoryItem('sub:travel:food',      'Food',      '#00B0FF', Icons.restaurant_rounded),
    ],
  };

  /// Sub-categories for a parent category emoji (empty if none defined).
  static List<CategoryItem> subsFor(String parentIcon) =>
      subcategories[parentIcon] ?? const [];

  /// Look up a sub-category by its `sub:...` key.
  static CategoryItem? subByKey(String key) {
    for (final subs in subcategories.values) {
      for (final s in subs) {
        if (s.icon == key) return s;
      }
    }
    return null;
  }

  /// Parent category emoji that owns a given `sub:...` key (null if unknown).
  static String? parentOfSub(String key) {
    for (final e in subcategories.entries) {
      for (final s in e.value) {
        if (s.icon == key) return e.key;
      }
    }
    return null;
  }

  /// Human label for either a category emoji or a `sub:...` key.
  static String labelForKey(String key) {
    if (key.startsWith('sub:')) return subByKey(key)?.label ?? 'Other';
    final c = expenseCategories.firstWhere((c) => c.icon == key,
        orElse: () => incomeCategories.firstWhere((c) => c.icon == key,
            orElse: () => const CategoryItem('💰', 'Other', '#9E9E9E')));
    return c.label;
  }

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
  List<Budget> budgets = []; // named budgets (Phase A) — local SQLite only
  GroupData? currentGroup;

  /// Globally selected currency for Home and Overview tabs
  String? dashboardCurrency;
  String? homeCurrency;

  /// Custom date range for Overview tab (if null, defaults to current month)
  DateTime? overviewStartDate;
  DateTime? overviewEndDate;

  /// Real-time Firestore expense watchers keyed by group ID.
  /// Active only when signed in; automatically updated when any group member
  /// adds / edits / deletes an expense — so every user sees changes live.
  final Map<int, StreamSubscription<List<ExpenseData>>> _expenseWatchers = {};

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

  void stopRealtimeServices() {
    _cancelExpenseWatchers();
    _entitlementSub?.cancel();
    _entitlementSub = null;
    unawaited(PushNotificationService.instance.dispose());
  }

  @override
  void dispose() {
    stopRealtimeServices();
    super.dispose();
  }

  Future<void> _load() async {
    isLoading = true;
    // Do NOT call notifyListeners() here — we're inside initState's
    // postFrameCallback and the widget tree is still building.
    // The first notify happens after data has been loaded below.

    final db = DatabaseService.instance;

    if (_useCloud) {
      // ── Cloud path ──
      // Show cached SQLite data instantly
      final localGroups = await db.loadGroups();
      groups = localGroups;
      transactions = await db.loadTransactions();
      wallets = await db.loadWallets();
      groupWallets = await db.loadGroupWallets();
      budgetLimits = await db.loadBudgetLimits();
      savingGoals = (await db.loadSavingGoals()).map((r) => SavingGoal.fromMap(r)).toList();
      budgets = (await db.loadBudgets()).map((r) => Budget.fromMap(r)).toList();
      subscriptions = await db.loadSubscriptions();
      reminders = await db.loadReminders();

    // PERSISTENCE FIX: Rebuild the in-memory Firestore doc-ID cache from
    // SQLite-stored firestoreId values. This ensures mutations (add expense,
    // settle up, etc.) work immediately after a cold start — even before
    // Firestore data has been fetched — without needing a network round-trip.
      for (final g in localGroups) {
        if (g.firestoreId != null) {
          FirestoreService.instance.cacheDocId(g.id, g.firestoreId!);
        }
      }

      // Show cached data immediately while Firestore loads.
      // Defer the notify to avoid firing during the build phase
      // (SQLite reads can return near-synchronously from cache).
      isLoading = false;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });

      // 2. Migrate local-only groups to Firestore before fetching cloud data.
      //    This prevents data loss when switching from local → cloud mode
      //    (e.g. after reinstalling the app and signing back in).
      //
      //    CRITICAL: only FULL accounts migrate. A guest (anonymous) session
      //    must NEVER upload the device's local SQLite history onto a
      //    throwaway anonymous uid — see shouldMigrateLocalData().
      final fs = FirestoreService.instance;
      if (shouldMigrateLocalData(tier)) {
        await _migrateLocalGroupsToCloud(fs, localGroups);
        await _migrateLocalTransactionsToCloud(fs, transactions);
        await _migrateLocalRemindersToCloud(fs, reminders);
      } else {
        debugPrint('[AppState] Guest session — skipping local→cloud migration');
      }

      // 3. Fetch fresh data from Firestore (now includes migrated data)
      try {
        final cloudGroups = await fs.loadGroups();
        final cloudTxns = await fs.loadTransactions();
        final cloudWallets = await fs.loadWallets();
        final cloudGroupWallets = await fs.loadGroupWallets();
        final cloudBudgets = await fs.loadBudgetLimits();
        final cloudGoals = (await fs.loadSavingGoals()).map((r) => SavingGoal.fromMap(r)).toList();
        final cloudReminders = await fs.loadReminders();

        groups = cloudGroups;
        transactions = cloudTxns;
        wallets = cloudWallets;
        groupWallets = cloudGroupWallets;
        budgetLimits = cloudBudgets;
        savingGoals = cloudGoals;
        reminders = cloudReminders..sort((a, b) => a.date.compareTo(b.date));

        // 4. Cache cloud data to SQLite — AWAITED so the transaction commits
        //    before the app can be backgrounded. Uses an atomic SQLite
        //    transaction so an app kill mid-write rolls back instead of
        //    leaving tables empty.
        await _cacheToSQLite(db, cloudGroups, cloudTxns, cloudWallets, cloudGroupWallets, cloudBudgets, cloudReminders);
      } catch (e) {
        debugPrint('[AppState] Firestore load failed, using SQLite cache: $e');
        // Already loaded from SQLite above, so data is still available
      }

      // Initialize push notifications
      PushNotificationService.instance.init();

      // ── Real-time expense watchers ────────────────────────────────────────
      // Start a Firestore snapshot listener for each active group so that
      // expenses added by OTHER group members appear immediately in the
      // Activity screen without requiring an app restart.
      _startExpenseWatchers();

      // ── Premium entitlement ───────────────────────────────────────────────
      // Only full accounts can hold an entitlement; guests never pay.
      if (tier == AccountTier.full) {
        await _initEntitlement();
      }
    } else {
      // ── Local path: same as before ──
      groups = await db.loadGroups();
      transactions = await db.loadTransactions();
      wallets = await db.loadWallets();
      groupWallets = await db.loadGroupWallets();
      budgetLimits = await db.loadBudgetLimits();
      subscriptions = await db.loadSubscriptions();
      reminders = await db.loadReminders();
      savingGoals = (await db.loadSavingGoals()).map((r) => SavingGoal.fromMap(r)).toList();
      budgets = (await db.loadBudgets()).map((r) => Budget.fromMap(r)).toList();

      // (Sample data seeding has been removed for production)
    }

    // Restore last-selected currencies (works for both cloud and local paths)
    await _loadCurrencyPrefs();

    isLoading = false;
    notifyListeners();
  }

  // ─── Real-time group expense watchers ────────────────────────────────────

  /// Start a Firestore snapshot listener for every active (non-archived) group.
  /// When any group member adds / edits / deletes an expense, the listener
  /// updates that group's expense list and notifies listeners so the UI
  /// (Activity, Overview, GroupDetail) reflects the change immediately.
  void _startExpenseWatchers() {
    if (!_useCloud) return;
    // Cancel old watchers before starting fresh (e.g. after reload).
    _cancelExpenseWatchers();

    for (final g in groups) {
      _watchGroupExpenses(g);
    }
  }

  void _watchGroupExpenses(GroupData g) {
    if (!_useCloud) return;
    final docId = g.firestoreId;
    if (docId == null) return;

    _expenseWatchers[g.id]?.cancel();
    _expenseWatchers[g.id] = FirestoreService.instance
        .watchGroupExpenses(docId)
        .listen((updatedExpenses) {
      final idx = groups.indexWhere((x) => x.id == g.id);
      if (idx >= 0) {
        groups[idx].expenses = updatedExpenses;
        groups = List.of(groups); // new list reference → triggers rebuild
        _cachedAllTxns = null;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('[AppState] Expense watcher error for group ${g.name}: $e');
    });
  }

  void _cancelExpenseWatchers() {
    for (final sub in _expenseWatchers.values) {
      sub.cancel();
    }
    _expenseWatchers.clear();
  }

  /// Migrate local SQLite groups to Firestore so they aren't lost when
  /// switching from offline → cloud mode (e.g. reinstall + sign-in).
  /// Only uploads groups that don't already exist in Firestore.
  Future<void> _migrateLocalGroupsToCloud(
    FirestoreService fs, List<GroupData> localGroups,
  ) async {
    if (localGroups.isEmpty) return;
    try {
      // Check which groups already exist in Firestore for this user
      final cloudGroups = await fs.loadGroups();
      final cloudNames = cloudGroups
          .map((g) => '${g.name.toLowerCase()}|${g.currency}')
          .toSet();

      for (final localGroup in localGroups) {
        final key = '${localGroup.name.toLowerCase()}|${localGroup.currency}';
        // Skip sample/seed data groups and groups that already exist in cloud
        if (cloudNames.contains(key)) continue;

        // Upload group to Firestore
        try {
          final result = await fs.insertGroup(localGroup);
          localGroup.inviteCode = result['inviteCode'];

          // Upload expenses
          for (final e in localGroup.expenses) {
            await fs.insertExpense(localGroup.id, e);
          }
          // Upload settlements
          for (final s in localGroup.settlements) {
            await fs.insertSettlement(localGroup.id, s);
          }
          debugPrint('[AppState] Migrated local group to cloud: ${localGroup.name}');
        } catch (e) {
          debugPrint('[AppState] Failed to migrate group ${localGroup.name}: $e');
        }
      }
    } catch (e) {
      debugPrint('[AppState] Local→Cloud group migration failed (non-fatal): $e');
    }
  }

  /// Migrate local SQLite personal transactions to Firestore.
  /// Only uploads transactions that don't already exist in cloud.
  Future<void> _migrateLocalTransactionsToCloud(
    FirestoreService fs, List<TransactionData> localTxns,
  ) async {
    if (localTxns.isEmpty) return;
    try {
      final cloudTxns = await fs.loadTransactions();
      // Build a set of "desc|amount|date" keys for dedup
      final cloudKeys = cloudTxns
          .map((t) => '${t.desc}|${t.amount}|${t.date}')
          .toSet();

      for (final t in localTxns) {
        final key = '${t.desc}|${t.amount}|${t.date}';
        if (cloudKeys.contains(key)) continue;
        try {
          await fs.insertTransaction(t);
          debugPrint('[AppState] Migrated local txn to cloud: ${t.desc}');
        } catch (e) {
          debugPrint('[AppState] Failed to migrate txn ${t.desc}: $e');
        }
      }
    } catch (e) {
      debugPrint('[AppState] Local→Cloud txn migration failed (non-fatal): $e');
    }
  }

  /// Migrate local SQLite reminders to Firestore.
  Future<void> _migrateLocalRemindersToCloud(
    FirestoreService fs, List<ReminderData> localReminders,
  ) async {
    if (localReminders.isEmpty) return;
    try {
      final cloudReminders = await fs.loadReminders();
      final cloudKeys = cloudReminders
          .map((r) => '${r.title}|${r.amountStr}|${r.date}')
          .toSet();

      for (final r in localReminders) {
        final key = '${r.title}|${r.amountStr}|${r.date}';
        if (cloudKeys.contains(key)) continue;
        try {
          await fs.insertReminder(r);
          debugPrint('[AppState] Migrated local reminder to cloud: ${r.title}');
        } catch (e) {
          debugPrint('[AppState] Failed to migrate reminder ${r.title}: $e');
        }
      }
    } catch (e) {
      debugPrint('[AppState] Local→Cloud reminder migration failed (non-fatal): $e');
    }
  }

  /// Public reload — called by BackupService after a restore so the UI
  /// reflects the newly imported data without restarting the app.
  Future<void> reloadFromDatabase() async {
    await _load();
  }

  /// Pull-to-refresh handler — re-syncs data from Firestore (cloud) or
  /// SQLite (local) and notifies listeners so all tabs update instantly.
  Future<void> refresh() async {
    await _load();
  }

  /// Cache cloud data to local SQLite for offline resilience.
  ///
  /// CRASH-SAFE: Groups are replaced inside a single SQLite transaction via
  /// [DatabaseService.atomicReplaceGroups]. If the app is killed mid-write
  /// the transaction rolls back, leaving the OLD cached data intact rather
  /// than an empty table.
  ///
  /// SAFETY: If Firestore returned completely empty data (possibly due to a
  /// failed query that silently returned []), we skip the write entirely to
  /// avoid wiping valid cached data.
  Future<void> _cacheToSQLite(
    DatabaseService db,
    List<GroupData> cloudGroups,
    List<TransactionData> cloudTxns,
    Map<String, double> cloudWallets,
    Map<String, double> cloudGroupWallets,
    Map<String, double> cloudBudgets,
    List<ReminderData> cloudReminders,
  ) async {
    try {
      // Safety net 1: if cloud returned nothing at all, don't wipe local cache.
      if (cloudGroups.isEmpty && cloudTxns.isEmpty && cloudWallets.isEmpty && cloudReminders.isEmpty) {
        debugPrint('[AppState] Cloud data entirely empty — skipping SQLite cache wipe');
        return;
      }

      // CRASH-SAFE group replacement (atomic transaction — rollback on kill).
      // This replaces the old clear+loop pattern that could leave SQLite empty.
      await db.atomicReplaceGroups(cloudGroups);
      await db.atomicReplaceReminders(cloudReminders);

      // Transactions: upsert each one (non-destructive, safe individually)
      for (final t in cloudTxns) {
        try { await db.insertTransactionRaw(t); } catch (_) {}
      }
      // Wallets
      for (final entry in cloudWallets.entries) {
        try { await db.upsertWallet(entry.key, entry.value); } catch (_) {}
      }
      for (final entry in cloudGroupWallets.entries) {
        try { await db.upsertGroupWallet(entry.key, entry.value); } catch (_) {}
      }
      // Budget limits
      for (final entry in cloudBudgets.entries) {
        try { await db.upsertBudgetLimit(entry.key, entry.value); } catch (_) {}
      }
      debugPrint('[AppState] Cloud data cached to SQLite successfully (atomic group write)');
    } catch (e) {
      debugPrint('[AppState] SQLite cache write failed (non-fatal): $e');
    }
  }



  // ─── Premium entitlement lifecycle ───────────────────────────────────────

  /// Load the cached entitlement (instant, offline) then start a live watcher
  /// against the server-written `users/{uid}.entitlement`.
  Future<void> _initEntitlement() async {
    // 1. Instant offline mirror.
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kEntitlementPrefsKey);
      if (cached != null) {
        _entitlement = Entitlement.fromMap(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
      }
    } catch (_) {}

    // 2. Authoritative read + live updates.
    try {
      final initial = await FirestoreService.instance.loadEntitlement();
      _applyEntitlement(initial);
    } catch (e) {
      debugPrint('[AppState] entitlement load failed: $e');
    }

    _entitlementSub?.cancel();
    _entitlementSub = FirestoreService.instance.watchEntitlement().listen(
      _applyEntitlement,
      onError: (e) => debugPrint('[AppState] entitlement watch error: $e'),
    );
  }

  void _applyEntitlement(Map<String, dynamic>? map) {
    _entitlement = Entitlement.fromMap(map);
    // Mirror to prefs for offline.
    SharedPreferences.getInstance().then(
      (p) => p.setString(_kEntitlementPrefsKey, jsonEncode(_entitlement.toMap())),
    );
    notifyListeners();
  }

  /// Called by IapService after a verified purchase so the UI unlocks without
  /// waiting for the Firestore snapshot. Also forces a token refresh so the
  /// `premium` custom claim is visible to security rules immediately.
  Future<void> onPurchaseVerified(Entitlement e) async {
    _entitlement = e;
    await AuthService.instance.refreshIdToken();
    notifyListeners();
  }

  /// Owner enables/disables guest joining for a group they own.
  /// Requires an active entitlement (enforced again by security rules).
  Future<bool> setGroupGuestAccess(GroupData g, bool enabled) async {
    if (enabled && !canEnableGuestAccess(_entitlement)) return false;
    if (!_useCloud) return false;
    try {
      await FirestoreService.instance.setGroupGuestAccess(g.id, enabled);
      return true;
    } catch (e) {
      debugPrint('[AppState] setGroupGuestAccess failed: $e');
      return false;
    }
  }

  // ─── Guest join ───────────────────────────────────────────────────────────

  /// Join a group as an accountless guest via an invite code.
  ///
  /// Flow: probe the code (is the group premium?) → if allowed, create an
  /// anonymous session → join → pull the group into local state. The chosen
  /// [guestName] becomes this device's member identity (persisted so balances
  /// resolve correctly).
  ///
  /// Returns the joined [GroupData], or null with the reason in [lastGuestJoinError].
  String? lastGuestJoinError;

  Future<GroupData?> joinAsGuest(String inviteCode, String guestName) async {
    lastGuestJoinError = null;
    final auth = AuthService.instance;
    final fs = FirestoreService.instance;

    // 1. Ensure a session — Firestore rules require auth even to PROBE the
    //    invite code. If the user is fully signed in, this is a free full
    //    join; otherwise we mint an anonymous (guest) session that we will
    //    roll back if the join is rejected (no orphan accounts).
    bool createdAnon = false;
    if (!auth.isSignedIn) {
      try {
        await auth.signInAnonymously();
        createdAnon = true;
      } catch (e) {
        lastGuestJoinError = 'Could not start a guest session. Try again.';
        return null;
      }
    }
    final isGuestJoin = auth.isGuest;

    Future<void> rollback() async {
      if (createdAnon) await auth.deleteAnonymousUser();
    }

    // 2. Probe (now authenticated).
    final probe = await fs.probeInviteCode(inviteCode);
    if (probe == null) {
      lastGuestJoinError = 'Invalid or expired invite code.';
      await rollback();
      return null;
    }

    // 3. Gate. Only GUESTS are premium-gated; full accounts join free.
    if (isGuestJoin) {
      final decision = evaluateGuestJoin(
        isPremiumGroup: probe['isPremiumGroup'] == true,
        memberCount: probe['memberCount'] as int? ?? 0,
        maxMembers: 50,
      );
      if (decision != GuestJoinDecision.allowed) {
        lastGuestJoinError = guestJoinDenialMessage(decision);
        await rollback();
        return null;
      }
    }

    // 4. Resolve + persist this device's member name.
    final trimmed = guestName.trim();
    final safeName = trimmed.isEmpty
        ? 'Guest'
        : (trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed);
    if (isGuestJoin) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('guest_member_name', safeName);
        _guestMemberName = safeName;
      } catch (_) {}
    }

    // 5. Join.
    final group = await fs.joinGroupByInviteCode(inviteCode, safeName);
    if (group == null) {
      lastGuestJoinError = 'Could not join the group. Try again.';
      await rollback();
      return null;
    }
    await joinGroupLocally(group);
    return group;
  }

  /// Cached guest member name (the balance-map key for a guest device),
  /// loaded from prefs at startup. Null for non-guest sessions.
  String? _guestMemberName;

  // ─── Balance logic ───────────────────────────────────────────────────────

  /// Canonical balances keyed by STABLE member id. This is the correctness-
  /// critical engine: two members with the same display name keep separate
  /// balances because they have distinct ids.
  ///
  /// Backward-compatible: legacy rows that only carry names are resolved to ids
  /// via the roster when the name is unambiguous, otherwise keyed by the pseudo
  /// id `name:<name>` (which reproduces the old name-based behavior exactly).
  Map<String, double> getBalancesById(GroupData g) {
    final useRoster = g.roster.isNotEmpty;
    // Ids we can map back to a display name. A balance key MUST be either one of
    // these or a `name:<name>` pseudo-key, so the UI never shows a raw id.
    final validIds = g.roster.map((m) => m.id).toSet();
    final List<String> memberKeys = useRoster
        ? g.roster.map((m) => m.id).toList()
        : g.members.map((n) => 'name:$n').toList();

    // Resolve a (name, explicitId) reference to a DISPLAYABLE canonical key.
    // An explicit id is only trusted when it exists in the roster (so it can be
    // resolved back to a name); otherwise we fall back to name-keying. This
    // prevents raw uids / `local:` ids from leaking into the UI for multi-user
    // or partially-synced groups.
    String refId(String name, String? explicitId) {
      if (explicitId != null && explicitId.isNotEmpty && validIds.contains(explicitId)) {
        return explicitId;
      }
      return g.memberIdForName(name) ?? 'name:$name';
    }

    final bal = <String, double>{};
    for (final k in memberKeys) {
      bal[k] = 0;
    }

    for (final e in g.expenses) {
      final payerKey = refId(e.paidBy, e.paidById);

      // Prefer id-keyed splits — but ONLY if every split id is resolvable to a
      // roster member; otherwise project the name-keyed splits onto ids so the
      // UI can always show names.
      Map<String, double>? splitById;
      if (e.splitIds != null &&
          e.splitIds!.isNotEmpty &&
          e.splitIds!.keys.every(validIds.contains)) {
        splitById = e.splitIds;
      } else if (e.splits != null && e.splits!.isNotEmpty) {
        splitById = <String, double>{};
        e.splits!.forEach((name, v) {
          final key = refId(name, null);
          splitById![key] = (splitById[key] ?? 0) + v;
        });
      }

      if (splitById != null && splitById.isNotEmpty) {
        final rawTotal = splitById.values.fold(0.0, (s, v) => s + v);
        final needsNormalize =
            rawTotal > 0 && (rawTotal - e.amount).abs() > 0.01;
        final scale = needsNormalize ? e.amount / rawTotal : 1.0;
        splitById.forEach((key, v) {
          bal[key] = (bal[key] ?? 0) - v * scale;
        });
        bal[payerKey] = (bal[payerKey] ?? 0) + e.amount;
      } else {
        // Equal split. UI-3 FIX: guard against division by zero.
        if (memberKeys.isEmpty) continue;
        final share = e.amount / memberKeys.length;
        for (final key in memberKeys) {
          bal[key] = (bal[key] ?? 0) - share;
        }
        bal[payerKey] = (bal[payerKey] ?? 0) + e.amount;
      }
    }

    for (final s in g.settlements) {
      final fromKey = refId(s.from, s.fromId);
      final toKey = refId(s.to, s.toId);
      bal[fromKey] = (bal[fromKey] ?? 0) + s.amount;
      bal[toKey] = (bal[toKey] ?? 0) - s.amount;
    }

    bal.updateAll((k, v) => double.parse(v.toStringAsFixed(2)));
    return bal;
  }

  /// Name-keyed balances (display/back-compat). A projection of
  /// [getBalancesById]; identical to the old behavior when names are unique.
  /// NOTE: where two members share a name their balances are SUMMED here — use
  /// [getBalancesById] anywhere correctness for duplicates matters.
  Map<String, double> getAllBalances(GroupData g) {
    final byId = getBalancesById(g);
    final byName = <String, double>{};
    byId.forEach((key, v) {
      final name = g.displayNameForKey(key);
      byName[name] = (byName[name] ?? 0) + v;
    });
    byName.updateAll((k, v) => double.parse(v.toStringAsFixed(2)));
    return byName;
  }

  /// Returns a set of all active currencies across personal wallets and groups.
  Set<String> get activeCurrencies {
    final curs = <String>{};
    curs.addAll(wallets.keys);
    for (final g in groups) {
      if (g.expenses.isNotEmpty || g.settlements.isNotEmpty) {
        curs.add(g.currency);
      }
    }
    return curs;
  }

  // ARCH-3 FIX: Resolve the current user's stable member id, then read the
  // id-keyed balance. Falls back through uid → guest name → 'You' → real name.
  double getMyBalance(GroupData g) {
    final byId = getBalancesById(g);

    // 1. Cloud: match my Firebase uid against the roster.
    final myUid = AuthService.instance.uid;
    if (myUid != null) {
      for (final m in g.roster) {
        if (m.uid == myUid && byId.containsKey(m.id)) return byId[m.id]!;
      }
    }
    // 2. Guest: their chosen member name.
    if (isGuest && _guestMemberName != null) {
      final id = g.memberIdForName(_guestMemberName!) ?? 'name:${_guestMemberName!}';
      if (byId.containsKey(id)) return byId[id]!;
    }
    // 3. 'You' (local/offline groups always use 'You').
    final youId = g.memberIdForName('You') ?? 'name:You';
    if (byId.containsKey(youId)) return byId[youId]!;
    // 4. The user's real display name (cloud groups without uid match).
    final userName = AuthService.instance.currentUser?.displayName;
    if (userName != null) {
      final id = g.memberIdForName(userName) ?? 'name:$userName';
      if (byId.containsKey(id)) return byId[id]!;
    }
    return 0;
  }

  double getGroupWalletBalance(String currency) {
    double total = 0.0;
    for (final g in activeGroups.where((x) => x.currency == currency)) {
      total += getMyBalance(g);
    }
    return total;
  }

  List<SettlePair> buildSettlePlan(GroupData g) {
    // Work in id-space so same-named members settle independently.
    final balances = getBalancesById(g);

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
        // _Pair.name holds the canonical id key; expose both id + display name.
        plan.add(SettlePair(
          g.displayNameForKey(debtors[j].name),
          g.displayNameForKey(creditors[i].name),
          amt,
          fromId: debtors[j].name,
          toId: creditors[i].name,
        ));
      }

      creditors[i].amt -= amt;
      debtors[j].amt -= amt;

      if (creditors[i].amt < 0.01) i++;
      if (debtors[j].amt < 0.01) j++;
    }

    return plan;
  }

  // ─── Mutations ───────────────────────────────────────────────────────────

  void setDashboardCurrency(String currencyCode) {
    dashboardCurrency = currencyCode;
    SharedPreferences.getInstance().then((p) => p.setString('dashboard_currency', currencyCode));
    notifyListeners();
  }

  void setHomeCurrency(String currencyCode) {
    homeCurrency = currencyCode;
    SharedPreferences.getInstance().then((p) => p.setString('home_currency', currencyCode));
    notifyListeners();
  }

  /// Load last-used currencies from SharedPreferences (called at startup).
  Future<void> _loadCurrencyPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDashboard = prefs.getString('dashboard_currency');
    final savedHome      = prefs.getString('home_currency');
    if (savedDashboard != null) dashboardCurrency = savedDashboard;
    if (savedHome      != null) homeCurrency      = savedHome;
    _guestMemberName = prefs.getString('guest_member_name');
  }

  void setOverviewDateRange(DateTime? start, DateTime? end) {
    overviewStartDate = start;
    overviewEndDate = end;
    notifyListeners();
  }

  Future<void> addGroup(GroupData g) async {
    if (_useCloud) {
      final result = await FirestoreService.instance.insertGroup(g);
      g.inviteCode = result['inviteCode'];
      // Persist the Firestore doc ID so SQLite cache survives app kills.
      g.firestoreId = result['docId'];
      // Also cache to SQLite for offline resilience
      await DatabaseService.instance.insertGroup(g);
    } else {
      await DatabaseService.instance.insertGroup(g);
    }
    groups = [g, ...groups];
    _cachedAllTxns = null;
    // Start real-time expense watcher for the new group (cloud only).
    _watchGroupExpenses(g);
    notifyListeners();
  }

  /// Manually insert a newly joined cloud group into local state.
  /// This avoids the ~500ms Firestore index latency that occurs if we
  /// try to do a full reloadFromDatabase immediately after joining.
  Future<void> joinGroupLocally(GroupData g) async {
    final idx = groups.indexWhere((x) => x.id == g.id);
    if (idx >= 0) {
      groups[idx] = g;
    } else {
      groups = [g, ...groups];
    }
    
    await DatabaseService.instance.insertGroup(g);
    for (final e in g.expenses) {
      await DatabaseService.instance.insertExpense(g.id, e);
    }
    for (final s in g.settlements) {
      await DatabaseService.instance.insertSettlement(g.id, s);
    }
    
    _cachedAllTxns = null;
    if (_useCloud) {
      _watchGroupExpenses(g);
    }
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
            final s = e.toString();
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

      if (_useCloud) {
        final result = await FirestoreService.instance.insertGroup(g);
        g.inviteCode = result['inviteCode'];
        // Persist the Firestore doc ID so SQLite cache survives app kills.
        g.firestoreId = result['docId'];
        // BUG-5 fix: also cache to SQLite so the group survives offline
        try {
          await DatabaseService.instance.insertGroup(g);
        } catch (_) {}
      } else {
        await DatabaseService.instance.insertGroup(g);
      }
      
      groups = [g, ...groups];
      _cachedAllTxns = null;
      notifyListeners();
      return g;
    } catch (_) {
      return null;
    }
  }

  Future<void> addExpenseToGroup(GroupData g, ExpenseData e) async {
    var expenseToSave = e;

    // Upload receipt to Firebase Storage if in cloud mode
    if (_useCloud && e.receipt && e.receiptPath != null) {
      try {
        final url = await StorageService.instance.uploadReceipt(
          g.id, e.id, e.receiptPath!,
        );
        if (url != null) {
          expenseToSave = ExpenseData(
            id: e.id,
            desc: e.desc,
            amount: e.amount,
            cat: e.cat,
            paidBy: e.paidBy,
            paidById: e.paidById, // preserve stable member ids
            date: e.date,
            receipt: true,
            receiptPath: url, // Cloud URL instead of local path
            splits: e.splits,
            splitIds: e.splitIds,
            createdBy: e.createdBy, // preserve audit/edit metadata
            updatedBy: e.updatedBy,
          );
        }
      } catch (err) {
        debugPrint('[AppState] Receipt upload failed, keeping local path: $err');
      }
    }

    // Local-first: SQLite write completes instantly and is the offline source
    // of truth. Awaiting the Firestore write here would hang the UI offline.
    await DatabaseService.instance.insertExpense(g.id, expenseToSave);
    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance.insertExpense(g.id, expenseToSave);
        } catch (e) {
          debugPrint('[cloud] expense sync deferred: $e');
        }
      }());
    }
    g.expenses = [expenseToSave, ...g.expenses];
    groups = List.of(groups);
    _cachedAllTxns = null;
    notifyListeners();
  }

  Future<void> editExpenseInGroup(
    GroupData g,
    ExpenseData oldExp,
    ExpenseData newExp,
  ) async {
    if (_useCloud) {
      await FirestoreService.instance.updateExpense(g.id, newExp);
    } else {
      await DatabaseService.instance.updateExpense(g.id, newExp);
    }
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

  Future<bool> deleteExpense(GroupData g, ExpenseData e) async {
    try {
      if (_useCloud) {
        await FirestoreService.instance.deleteExpense(g.id, e.id);
      } else {
        await DatabaseService.instance.deleteExpense(e.id);
      }
      g.expenses = g.expenses.where((x) => x.id != e.id).toList();
      groups = List.of(groups);
      _cachedAllTxns = null;
      notifyListeners();
      return true;
    } catch (e2) {
      debugPrint('[AppState] deleteExpense failed: $e2');
      // Re-sync to revert any optimistic cache changes
      notifyListeners();
      return false;
    }
  }

  Future<void> recordSettlement(GroupData g, SettlementData s) async {
    if (_useCloud) {
      await FirestoreService.instance.insertSettlement(g.id, s);
    } else {
      await DatabaseService.instance.insertSettlement(g.id, s);
    }
    g.settlements = [...g.settlements, s];
    groups = List.of(groups);
    _cachedAllTxns = null; // BUG-11 fix: invalidate cache after settlement
    notifyListeners();
  }

  Future<void> editGroup(GroupData g, {String? name, String? emoji, List<String>? members}) async {
    if (name != null) g.name = name;
    if (emoji != null) g.emoji = emoji;
    if (members != null) g.members = members;
    if (_useCloud) {
      await FirestoreService.instance.updateGroup(g);
    } else {
      await DatabaseService.instance.updateGroup(g);
    }
    groups = List.of(groups);
    _cachedAllTxns = null;
    notifyListeners();
  }

  Future<void> archiveGroup(GroupData g) async {
    if (_useCloud) {
      await FirestoreService.instance.setGroupArchived(g.id, true);
    } else {
      await DatabaseService.instance.setGroupArchived(g.id, true);
    }
    g.isArchived = true;
    groups = List.of(groups);
    notifyListeners();
  }

  Future<void> unarchiveGroup(GroupData g) async {
    if (_useCloud) {
      await FirestoreService.instance.setGroupArchived(g.id, false);
    } else {
      await DatabaseService.instance.setGroupArchived(g.id, false);
    }
    g.isArchived = false;
    groups = List.of(groups);
    notifyListeners();
  }

  Future<void> deleteGroup(GroupData g) async {
    if (_useCloud) {
      try {
        await FirestoreService.instance.deleteGroup(g);
      } catch (e) {
        debugPrint('[AppState] Failed to delete group from cloud: $e');
        // We still proceed to delete locally so the UI updates
      }
    }
    await DatabaseService.instance.deleteGroup(g.id);
    groups = groups.where((x) => x.id != g.id).toList();
    if (currentGroup?.id == g.id) currentGroup = null;
    _cachedAllTxns = null;
    notifyListeners();
  }

  /// Current user leaves a group: removes the group from THIS device and drops
  /// the user's own uid/name from the cloud member list (others keep the group).
  /// Local-first so it never hangs offline.
  Future<void> leaveGroup(GroupData g) async {
    final myUid = AuthService.instance.uid;
    // Resolve the current user's display name within this group.
    String? myName;
    if (myUid != null) {
      for (final m in g.roster) {
        if (m.uid == myUid) { myName = m.name; break; }
      }
    }
    myName ??= (isGuest ? _guestMemberName : null);
    myName ??= g.members.contains('You')
        ? 'You'
        : AuthService.instance.currentUser?.displayName;

    // Remove from this device immediately.
    await DatabaseService.instance.deleteGroup(g.id);
    groups = groups.where((x) => x.id != g.id).toList();
    if (currentGroup?.id == g.id) currentGroup = null;
    _cachedAllTxns = null;
    notifyListeners();

    // Cloud: remove only myself (fire-and-forget; offline-safe).
    if (_useCloud && myUid != null) {
      final name = myName ?? '';
      unawaited(() async {
        try {
          await FirestoreService.instance.removeMemberFromGroup(g.id, myUid, name);
        } catch (e) {
          debugPrint('[cloud] leaveGroup deferred: $e');
        }
      }());
    }
  }

  /// Creator removes another member from the group. Updates the roster + member
  /// list locally, persists, and revokes the member's cloud access (memberUids).
  Future<void> removeMember(GroupData g, GroupMember m) async {
    g.roster = g.roster.where((x) => x.id != m.id).toList();
    if (g.roster.isNotEmpty) {
      g.members = g.roster.map((x) => x.name).toList();
    } else {
      final idx = g.members.indexOf(m.name);
      if (idx >= 0) g.members = (List.of(g.members)..removeAt(idx));
    }
    await DatabaseService.instance.updateGroup(g);
    groups = List.of(groups);
    _cachedAllTxns = null;
    notifyListeners();

    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance
              .removeMemberFromGroup(g.id, m.uid ?? m.id, m.name);
        } catch (e) {
          debugPrint('[cloud] removeMember deferred: $e');
        }
      }());
    }
  }

  Future<void> addTransaction(TransactionData t) async {
    final isNewWallet = !wallets.containsKey(t.currency);
    final cur = wallets[t.currency] ?? 0;
    final newBal = double.parse(
      (t.type == 'expense' ? cur - t.amount : cur + t.amount)
          .toStringAsFixed(2),
    );

    // Local-first: persist to SQLite synchronously so the save completes
    // instantly and survives an app restart. This is the offline source of
    // truth. Awaiting Firestore here would HANG the UI when offline, because
    // Firestore write Futures only resolve after a server ack.
    await DatabaseService.instance.insertTransactionAtomic(t, newBal);

    // Cloud sync runs in the background; offline persistence flushes it
    // automatically when connectivity returns.
    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance.insertTransaction(t);
          await FirestoreService.instance.upsertWallet(t.currency, newBal);
        } catch (e) {
          debugPrint('[cloud] transaction sync deferred: $e');
        }
      }());
    }

    transactions = [t, ...transactions];
    wallets = Map.of(wallets)..[t.currency] = newBal;
    _cachedAllTxns = null;

    // Auto-switch dashboard to the new currency so balance card is visible
    if (isNewWallet) {
      homeCurrency = t.currency;
      SharedPreferences.getInstance()
          .then((p) => p.setString('home_currency', t.currency));
    }

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

    if (_useCloud) {
      await FirestoreService.instance.updateTransaction(updated);
      await FirestoreService.instance.upsertWallet(old.currency, reversedOld);
      await FirestoreService.instance.upsertWallet(updated.currency, newBal);
      // FIX: also persist wallet changes to SQLite cache so balance survives restart
      await DatabaseService.instance.updateTransactionAtomic(updated, old.currency, reversedOld, newBal);
    } else {
      await DatabaseService.instance.updateTransactionAtomic(updated, old.currency, reversedOld, newBal);
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

    // Local-first: persist to SQLite and update in-memory state immediately so
    // the UI (incl. swipe-to-delete Dismissibles) reflects the change at once.
    // Awaiting Firestore here would hang while offline (the "save does nothing"
    // class of bug) and leave a dismissed Dismissible still in the tree.
    await DatabaseService.instance.deleteTransactionAtomic(t.id, t.currency, newBal);

    transactions = transactions.where((x) => x.id != t.id).toList();
    wallets = Map.of(wallets)..[t.currency] = newBal;
    _cachedAllTxns = null;
    notifyListeners();

    // Cloud writes fire-and-forget — they don't resolve while offline.
    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance.deleteTransaction(t.id);
          await FirestoreService.instance.upsertWallet(t.currency, newBal);
        } catch (e) {
          debugPrint('[cloud] delete tx deferred: $e');
        }
      }());
    }
  }

  Future<void> resetAllData() async {
    // Cancel real-time watchers BEFORE wiping cloud data.
    _cancelExpenseWatchers();

    if (_useCloud) {
      await FirestoreService.instance.clearAll();
    }
    await DatabaseService.instance.clearAll();

    // Clear ALL persisted settings so they don't leak into a fresh state
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dashboard_currency');
    await prefs.remove('home_currency');
    await prefs.remove('notify_before_days');    // FIX: persisted after reset
    await prefs.remove('auto_backup_enabled');   // FIX: persisted after reset
    await prefs.remove('last_auto_backup_ms');   // FIX: persisted after reset

    groups = [];
    transactions = [];
    wallets = {};
    groupWallets = {};
    budgetLimits = {};
    subscriptions = [];
    reminders = [];
    budgets = [];
    savingGoals = [];      // FIX: was missing — savingGoals persisted after reset
    currentGroup = null;
    dashboardCurrency = null;
    homeCurrency = null;
    _cachedAllTxns = null; // FIX: was missing — stale cache survived reset
    notifyListeners();
  }

  // ─── Wallet management ───────────────────────────────────────────────────

  Future<void> createWallet(String currency, double initialBalance) async {
    if (_useCloud) {
      await FirestoreService.instance.upsertWallet(currency, initialBalance);
    } else {
      await DatabaseService.instance.upsertWallet(currency, initialBalance);
    }
    wallets = Map.of(wallets)..[currency] = initialBalance;
    notifyListeners();
  }

  Future<void> deleteWallet(String currency) async {
    // Local-first: remove from SQLite immediately; cloud delete in background.
    await DatabaseService.instance.deleteWallet(currency);
    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance.deleteWallet(currency);
        } catch (e) {
          debugPrint('[cloud] wallet delete deferred: $e');
        }
      }());
    }
    wallets = Map.of(wallets)..remove(currency);
    // If the deleted wallet was the open/home account, switch to another (or none).
    if (homeCurrency == currency) {
      final next = wallets.keys.isNotEmpty ? wallets.keys.first : null;
      homeCurrency = next;
      SharedPreferences.getInstance().then((p) {
        if (next != null) {
          p.setString('home_currency', next);
        } else {
          p.remove('home_currency');
        }
      });
    }
    notifyListeners();
  }

  Future<void> createGroupWallet(String currency, double initialBalance) async {
    if (_useCloud) {
      await FirestoreService.instance.upsertGroupWallet(currency, initialBalance);
    } else {
      await DatabaseService.instance.upsertGroupWallet(currency, initialBalance);
    }
    groupWallets = Map.of(groupWallets)..[currency] = initialBalance;
    notifyListeners();
  }

  Future<void> deleteGroupWallet(String currency) async {
    if (_useCloud) {
      await FirestoreService.instance.deleteGroupWallet(currency);
    } else {
      await DatabaseService.instance.deleteGroupWallet(currency);
    }
    groupWallets = Map.of(groupWallets)..remove(currency);
    notifyListeners();
  }

  // ─── Budget limits ───────────────────────────────────────────────────────

  Future<void> setBudgetLimit(String catIcon, String currency, double limit) async {
    final key = '${catIcon}_$currency';
    if (_useCloud) {
      await FirestoreService.instance.upsertBudgetLimit(key, limit);
    } else {
      await DatabaseService.instance.upsertBudgetLimit(key, limit);
    }
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
    int newId;
    if (_useCloud) {
      newId = await FirestoreService.instance.insertReminder(r);
      await DatabaseService.instance.insertReminder(r.copyWith(id: newId));
    } else {
      newId = await DatabaseService.instance.insertReminder(r);
    }
    final saved = r.copyWith(id: newId);
    reminders = ([saved, ...reminders]..sort((a, b) => a.date.compareTo(b.date)));
    await NotificationService.scheduleReminder(saved);
    notifyListeners();
  }

  Future<void> updateReminder(ReminderData r) async {
    // Local-first: SQLite + state immediately; cloud fire-and-forget (offline-safe).
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
    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance.updateReminder(r);
        } catch (e) {
          debugPrint('[cloud] update reminder deferred: $e');
        }
      }());
    }
  }

  Future<void> deleteReminder(ReminderData r) async {
    // Local-first: removing from state immediately keeps swipe-to-delete
    // Dismissibles consistent and avoids the offline Firestore hang.
    await DatabaseService.instance.deleteReminder(r.id);
    reminders = reminders.where((x) => x.id != r.id).toList();
    await NotificationService.cancelReminder(r.id);
    notifyListeners();
    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance.deleteReminder(r.id);
        } catch (e) {
          debugPrint('[cloud] delete reminder deferred: $e');
        }
      }());
    }
  }

  Future<void> toggleReminderCompleted(ReminderData r) async {
    final updated = r.copyWith(isCompleted: !r.isCompleted);
    await updateReminder(updated);
  }

  // ─── Saving Goals ─────────────────────────────────────────────────────────

  Future<void> addSavingGoal(String currency, String title, double targetAmount, {DateTime? targetDate, double savedAmount = 0.0, String? icon, String? color}) async {
    final data = {
      'currency': currency,
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'target_date': targetDate?.toIso8601String(),
      'icon': icon,
      'color': color,
    };
    int id;
    if (_useCloud) {
      id = await FirestoreService.instance.insertSavingGoal(data);
    } else {
      id = await DatabaseService.instance.insertSavingGoal(data);
    }
    savingGoals.add(SavingGoal(id: id, currency: currency, title: title, targetAmount: targetAmount, savedAmount: savedAmount, targetDate: targetDate, icon: icon, color: color));
    notifyListeners();
  }

  Future<void> updateSavingGoal(SavingGoal g, {String? title, double? targetAmount, double? savedAmount, DateTime? targetDate, String? icon, String? color, List<GoalDeposit>? deposits}) async {
    final updated = SavingGoal(
      id: g.id,
      currency: g.currency,
      title: title ?? g.title,
      targetAmount: targetAmount ?? g.targetAmount,
      savedAmount: savedAmount ?? g.savedAmount,
      targetDate: targetDate ?? g.targetDate,
      icon: icon ?? g.icon,
      color: color ?? g.color,
      deposits: deposits ?? g.deposits,   // ← carry existing deposits forward
    );
    if (_useCloud) {
      await FirestoreService.instance.updateSavingGoal(g.id, updated.toMap());
    } else {
      await DatabaseService.instance.updateSavingGoal(g.id, updated.toMap());
    }
    final idx = savingGoals.indexWhere((x) => x.id == g.id);
    if (idx >= 0) {
      savingGoals[idx] = updated;
      notifyListeners();
    }
  }

  /// Records a deposit and updates savedAmount. Prefer this over updateSavingGoal
  /// for the +Money flow so History is automatically populated.
  Future<void> depositToGoal(SavingGoal g, double amount, {String note = ''}) async {
    final newDeposit = GoalDeposit(amount: amount, date: DateTime.now(), note: note);
    final newDeposits = [...g.deposits, newDeposit];
    await updateSavingGoal(g,
      savedAmount: g.savedAmount + amount,
      deposits: newDeposits,
    );
  }

  Future<void> deleteSavingGoal(int id) async {
    // Local-first: always remove from SQLite (so it can't resurrect from the
    // local cache on next launch) and update state immediately; cloud delete
    // fire-and-forget so it never hangs while offline.
    await DatabaseService.instance.deleteSavingGoal(id);
    savingGoals.removeWhere((g) => g.id == id);
    notifyListeners();
    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance.deleteSavingGoal(id);
        } catch (e) {
          debugPrint('[cloud] delete saving goal deferred: $e');
        }
      }());
    }
  }

  // ─── Budgets (named, Phase A — local SQLite only) ───────────────────────────
  Future<void> addBudget({
    required String name,
    required double amount,
    required String currency,
    String period = 'monthly',
    List<String> categories = const [],
    bool notifyOverspent = true,
  }) async {
    final tmp = Budget(
        id: 0, name: name, amount: amount, currency: currency,
        period: period, categories: categories, notifyOverspent: notifyOverspent);
    final id = await DatabaseService.instance.insertBudget(tmp.toMap());
    budgets.insert(0, Budget(
        id: id, name: name, amount: amount, currency: currency,
        period: period, categories: categories, notifyOverspent: notifyOverspent));
    notifyListeners();
  }

  Future<void> updateBudget(Budget b) async {
    await DatabaseService.instance.updateBudget(b.id, b.toMap());
    final i = budgets.indexWhere((x) => x.id == b.id);
    if (i >= 0) budgets[i] = b;
    notifyListeners();
  }

  Future<void> deleteBudget(int id) async {
    await DatabaseService.instance.deleteBudget(id);
    budgets.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  /// Amount spent against a budget in its current period (single currency).
  double budgetSpent(Budget b) {
    final now = DateTime.now();
    DateTime start;
    switch (b.period) {
      case 'weekly':
        final s = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(s.year, s.month, s.day);
        break;
      case 'yearly':
        start = DateTime(now.year, 1, 1);
        break;
      default: // monthly
        start = DateTime(now.year, now.month, 1);
    }
    double total = 0;
    for (final t in allTransactionsWithGroupShares) {
      if (t.type.toLowerCase() != 'expense') continue;
      if (t.currency != b.currency) continue;
      if (!b.coversCategoryOf(t)) continue;
      final d = t.rawDate ?? DateTime.tryParse(t.date);
      if (d == null || d.isBefore(start)) continue;
      total += t.amount;
    }
    return total;
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
  final IconData? materialIcon;
  const CategoryItem(this.icon, this.label, this.color, [this.materialIcon]);
}

/// A group member with a STABLE identity. [id] is the canonical key used for
/// balances/splits/settlements: the Firebase UID for app users, or a generated
/// `local:<...>` id for typed/offline members. [name] is display-only.
class GroupMember {
  final String id;
  String name;
  final String? uid; // Firebase UID when this member is an app user.
  final bool isGuest;

  GroupMember({
    required this.id,
    required this.name,
    this.uid,
    this.isGuest = false,
  });

  /// Monotonic counter so ids generated in a tight loop never collide.
  static int _seq = 0;

  /// Generate a stable id for a typed/offline member.
  static String generateLocalId() =>
      'local:${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (uid != null) 'uid': uid,
        'isGuest': isGuest,
      };

  factory GroupMember.fromMap(String id, Map<String, dynamic> m) => GroupMember(
        id: id,
        name: (m['name'] ?? '').toString(),
        uid: m['uid'] as String?,
        isGuest: m['isGuest'] == true,
      );
}

class GroupData {
  final int id;
  String name, emoji, currency, sym;
  bool isArchived;
  /// True when the group owner has Premium and has enabled guest joining.
  /// Mirrors `groups/{id}.isPremiumGroup` in Firestore.
  bool isPremiumGroup;
  String? inviteCode;
  /// Firebase UID of the group creator (owner). Only the creator may edit the
  /// group; everyone else gets a read-only view + the ability to leave. Null for
  /// legacy local groups created before this was tracked (see [isCreatedBy]).
  String? createdBy;
  /// Raw Firestore document ID (e.g. "abc123xyz"). Stored in SQLite so that
  /// FirestoreService._docIdCache can be rebuilt after an app kill/restart.
  String? firestoreId;
  List<String> members;
  /// Canonical id+name roster. May be empty for purely-legacy groups, in which
  /// case the app falls back to name-keyed behavior using [members].
  List<GroupMember> roster;
  List<ExpenseData> expenses;
  List<SettlementData> settlements;

  GroupData({
    required this.id,
    required this.name,
    required this.emoji,
    required this.currency,
    required this.sym,
    required this.members,
    List<GroupMember>? roster,
    List<ExpenseData>? expenses,
    List<SettlementData>? settlements,
    this.isArchived = false,
    this.isPremiumGroup = false,
    this.inviteCode,
    this.createdBy,
    this.firestoreId,
  })  : roster = roster ?? const [],
        expenses = expenses ?? [],
        settlements = settlements ?? [];

  /// True when [uid] is the group creator. For legacy groups with no stored
  /// [createdBy], fall back to the convention that the first member is the
  /// creator ('You' on this device, or their display name) so old local groups
  /// remain manageable by their owner.
  bool isCreatedBy(String? uid, {String? displayName}) {
    if (createdBy != null) return uid != null && createdBy == uid;
    // Legacy fallback (no createdBy recorded).
    if (members.isEmpty) return true;
    final first = members.first;
    return first == 'You' || (displayName != null && first == displayName);
  }

  /// Display names — prefer the canonical roster, fall back to [members].
  List<String> get memberNames =>
      roster.isNotEmpty ? roster.map((m) => m.name).toList() : members;

  /// Resolve a display name to a member id, but ONLY when the name is
  /// unambiguous in the roster. Returns null for absent or duplicate names
  /// (the duplicate case is exactly what id-keying exists to disambiguate).
  String? memberIdForName(String name) {
    if (roster.isEmpty) return null;
    final matches = roster.where((m) => m.name == name).toList();
    return matches.length == 1 ? matches.first.id : null;
  }

  /// The display name for a balance key produced by the engine. Handles both
  /// real member ids and the legacy `name:<name>` fallback keys.
  String displayNameForKey(String key) {
    if (key.startsWith('name:')) return key.substring(5);
    for (final m in roster) {
      if (m.id == key) return m.name;
    }
    return key;
  }
}

class ExpenseData {
  final int id;
  final String desc, cat, paidBy, date;
  final double amount;
  final bool receipt;
  final String? receiptPath;

  final String? createdBy;
  final String? updatedBy;

  /// Custom per-member split amounts. null = equal split.
  /// Key = member name, value = amount that member owes.
  final Map<String, double>? splits;

  /// Stable member id of the payer (preferred over [paidBy] name). Nullable for
  /// legacy rows written before id-keying.
  final String? paidById;

  /// Custom split amounts keyed by stable member id (preferred over [splits]).
  final Map<String, double>? splitIds;

  /// JSON encoding of [splits] for database storage.
  String? get splitsJson {
    if (splits == null || splits!.isEmpty) return null;
    return jsonEncode(splits);
  }

  /// JSON encoding of [splitIds] for database storage.
  String? get splitIdsJson {
    if (splitIds == null || splitIds!.isEmpty) return null;
    return jsonEncode(splitIds);
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
    this.paidById,
    this.splitIds,
    this.createdBy,
    this.updatedBy,
  });
}

class TransactionData {
  final int id;
  final String type, desc, cat, currency, sym, date;
  final double amount;
  final String? receiptPath;
  /// Optional sub-category key (`sub:...`) for finer-grained budgeting.
  final String? subcat;
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

  static String formatDate(String d) {
    final dt = parseDate(d);
    if (dt == null) return d;
    return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
  }

  static String _monthName(int m) {
    const names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    if (m < 1 || m > 12) return '';
    return names[m - 1];
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
    this.subcat,
    this.isGroupShare = false,
    this.groupId,
  });
}

class SettlementData {
  final String from, to, method, date;
  final double amount;
  /// Stable member ids of payer/payee (preferred over [from]/[to] names).
  final String? fromId, toId;

  const SettlementData({
    required this.from,
    required this.to,
    required this.amount,
    required this.method,
    required this.date,
    this.fromId,
    this.toId,
  });
}

class SettlePair {
  final String from, to;
  final double amount;
  /// Stable member ids of payer/payee (for unambiguous settle actions).
  final String? fromId, toId;
  const SettlePair(this.from, this.to, this.amount, {this.fromId, this.toId});
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

// ─── Deposit entry for a saving goal ─────────────────────────────────────────
class GoalDeposit {
  final double amount;
  final DateTime date;
  final String note;
  GoalDeposit({required this.amount, required this.date, this.note = ''});

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory GoalDeposit.fromMap(Map<String, dynamic> m) => GoalDeposit(
    amount: (m['amount'] as num).toDouble(),
    date: DateTime.parse(m['date'] as String),
    note: (m['note'] as String?) ?? '',
  );
}

class SavingGoal {
  final int id;
  final String currency;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;
  final String? icon;   // optional custom emoji; null = auto from title
  final String? color;  // optional hex string e.g. "#D97706"; null = auto palette
  final List<GoalDeposit> deposits;

  SavingGoal({
    required this.id,
    required this.currency,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0.0,
    this.targetDate,
    this.icon,
    this.color,
    List<GoalDeposit>? deposits,
  }) : deposits = deposits ?? [];

  factory SavingGoal.fromMap(Map<String, dynamic> map) {
    List<GoalDeposit> deps = [];
    try {
      final raw = map['deposits'];
      if (raw != null && raw is String && raw.isNotEmpty) {
        deps = raw.split('||').map<GoalDeposit?>((s) {
          final parts = s.split('|');
          if (parts.length < 2) return null;
          return GoalDeposit(
            amount: double.tryParse(parts[0]) ?? 0,
            date: DateTime.tryParse(parts[1]) ?? DateTime.now(),
            note: parts.length > 2 ? parts[2] : '',
          );
        }).whereType<GoalDeposit>().toList();
      }
    } catch (_) {}
    return SavingGoal(
      id: map['id'] as int,
      currency: (map['currency'] as String?) ?? 'USD',
      title: (map['title'] as String?) ?? '',
      targetAmount: (map['target_amount'] as num?)?.toDouble() ?? 0.0,
      savedAmount: (map['saved_amount'] as num?)?.toDouble() ?? 0.0,
      targetDate: map['target_date'] != null ? DateTime.tryParse(map['target_date']) : null,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      deposits: deps,
    );
  }

  Map<String, dynamic> toMap() {
    final depsStr = deposits.map((d) =>
      '${d.amount}|${d.date.toIso8601String()}|${d.note}'
    ).join('||');
    return {
      'currency': currency,
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'target_date': targetDate?.toIso8601String(),
      'icon': icon,
      'color': color,
      'deposits': depsStr,
    };
  }

  SavingGoal copyWith({
    double? savedAmount,
    double? targetAmount,
    String? title,
    DateTime? targetDate,
    String? icon,
    String? color,
    List<GoalDeposit>? deposits,
  }) {
    return SavingGoal(
      id: id,
      currency: currency,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      targetDate: targetDate ?? this.targetDate,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      deposits: deposits ?? this.deposits,
    );
  }
}

// ─── Budget (named, Phase A) ──────────────────────────────────────────────────
class Budget {
  final int id;
  final String name;
  final String period;   // 'monthly' | 'weekly' | 'yearly'
  final double amount;
  final String currency;
  final List<String> categories; // category emojis; empty = All
  final bool notifyOverspent;

  Budget({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    this.period = 'monthly',
    List<String>? categories,
    this.notifyOverspent = true,
  }) : categories = categories ?? const [];

  /// Single source of truth for whether this budget targets a transaction by
  /// category. Empty [categories] = "all categories" (matches everything);
  /// otherwise matches the transaction's parent category emoji OR its specific
  /// `sub:` key. Used by both [AppState.budgetSpent] and the budget detail
  /// chart so the matching rule can never drift between the two.
  bool coversCategoryOf(TransactionData t) {
    if (categories.isEmpty) return true;
    return categories.contains(t.cat) ||
        (t.subcat != null && categories.contains(t.subcat));
  }

  factory Budget.fromMap(Map<String, dynamic> m) {
    final catRaw = (m['categories'] as String?) ?? '';
    return Budget(
      id: (m['id'] as num).toInt(),
      name: (m['name'] as String?) ?? 'Budget',
      period: (m['period'] as String?) ?? 'monthly',
      amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (m['currency'] as String?) ?? 'USD',
      categories: catRaw.isEmpty ? const [] : catRaw.split('||'),
      notifyOverspent: ((m['notify_overspent'] as num?)?.toInt() ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'period': period,
        'amount': amount,
        'currency': currency,
        'categories': categories.join('||'),
        'notify_overspent': notifyOverspent ? 1 : 0,
      };

  Budget copyWith({
    String? name,
    String? period,
    double? amount,
    String? currency,
    List<String>? categories,
    bool? notifyOverspent,
  }) {
    return Budget(
      id: id,
      name: name ?? this.name,
      period: period ?? this.period,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categories: categories ?? this.categories,
      notifyOverspent: notifyOverspent ?? this.notifyOverspent,
    );
  }
}
