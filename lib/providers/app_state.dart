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

part 'app_state_models.dart';

/// Provider-based state. Routes data through Firestore when signed in,
/// falls back to local SQLite otherwise. Subscriptions & reminders
/// always use local SQLite.
class AppState extends ChangeNotifier {
  // ─── Loading flag ────────────────────────────────────────────────────────
  bool isLoading = true;
  bool _loadInProgress = false;

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

  /// Owner/developer accounts allowed to see in-progress premium controls
  /// (e.g. the guest-join toggle). Premium isn't being sold yet, so it stays
  /// hidden from everyone else until it ships. Add your dev-project uid here to
  /// see these controls on the dev build too.
  static const Set<String> _ownerUids = {
    'qgrU1tc4FCh8mAiF9Pz9D6nEG7Z2', // prod owner
  };
  bool get isOwner {
    final uid = AuthService.instance.uid;
    return uid != null && _ownerUids.contains(uid);
  }

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
      CategoryItem('sub:shopping:salon',       'Salon & Hair',  '#FFC107', Icons.content_cut_rounded),
      CategoryItem('sub:shopping:cosmetics',   'Cosmetics',     '#FFC107', Icons.brush_rounded),
      CategoryItem('sub:shopping:skincare',    'Skincare',      '#FFC107', Icons.face_retouching_natural_rounded),
      CategoryItem('sub:shopping:nails',       'Nails',         '#FFC107', Icons.back_hand_rounded),
      CategoryItem('sub:shopping:spa',         'Spa & Massage', '#FFC107', Icons.self_improvement_rounded),
      CategoryItem('sub:shopping:jewelry',     'Jewelry',       '#FFC107', Icons.diamond_rounded),
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
    if (_loadInProgress) return;
    _loadInProgress = true;
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
      _loadInProgress = false;
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
    _loadInProgress = false;
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
      // Build a set of "id|desc|amount|date" keys for dedup — include id so
      // two legitimate transactions with identical desc/amount/date aren't dropped.
      final cloudKeys = cloudTxns
          .map((t) => '${t.id}|${t.desc}|${t.amount}|${t.date}')
          .toSet();

      for (final t in localTxns) {
        final key = '${t.id}|${t.desc}|${t.amount}|${t.date}';
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
            addedBy: e.addedBy,
            subcat: e.subcat,
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
    // Local-first: write SQLite immediately, sync the cloud in the background
    // so editing an expense doesn't hang on the network.
    await DatabaseService.instance.updateExpense(g.id, newExp);
    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance.updateExpense(g.id, newExp);
        } catch (e) {
          debugPrint('[cloud] expense edit sync deferred: $e');
        }
      }());
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
      // Local-first: always delete from SQLite immediately so the expense
      // can't resurrect from the local cache on next cold start.
      await DatabaseService.instance.deleteExpense(e.id);
      if (_useCloud) {
        unawaited(() async {
          try {
            await FirestoreService.instance.deleteExpense(g.id, e.id);
          } catch (err) {
            debugPrint('[cloud] expense delete sync deferred: $err');
          }
        }());
      }
      g.expenses = g.expenses.where((x) => x.id != e.id).toList();
      groups = List.of(groups);
      _cachedAllTxns = null;
      notifyListeners();
      return true;
    } catch (e2) {
      debugPrint('[AppState] deleteExpense failed: $e2');
      notifyListeners();
      return false;
    }
  }

  Future<void> recordSettlement(GroupData g, SettlementData s) async {
    // Local-first: SQLite write is instant; the cloud sync runs in the
    // background so "Settle up" never spins on the network.
    await DatabaseService.instance.insertSettlement(g.id, s);
    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance.insertSettlement(g.id, s);
        } catch (e) {
          debugPrint('[cloud] settlement sync deferred: $e');
        }
      }());
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

    // Local-first: SQLite (source of truth) is instant; the cloud txn + both
    // wallet balances sync in the background so editing never spins on network.
    await DatabaseService.instance.updateTransactionAtomic(updated, old.currency, reversedOld, newBal);
    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance.updateTransaction(updated);
          await FirestoreService.instance.upsertWallet(old.currency, reversedOld);
          await FirestoreService.instance.upsertWallet(updated.currency, newBal);
        } catch (e) {
          debugPrint('[cloud] transaction edit sync deferred: $e');
        }
      }());
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
            subcat: e.subcat,
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
    // Record any starting balance as a real deposit so the history stays
    // itemized from day one instead of one collective lump.
    final seed = savedAmount > 0
        ? [GoalDeposit(amount: savedAmount, date: DateTime.now(), note: 'Starting balance')]
        : <GoalDeposit>[];
    final data = {
      'currency': currency,
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'target_date': targetDate?.toIso8601String(),
      'icon': icon,
      'color': color,
      if (seed.isNotEmpty)
        'deposits': seed
            .map((d) => '${d.amount}|${d.date.toIso8601String()}|${d.note}')
            .join('||'),
    };
    // Local-first: SQLite write is immediate so the goal survives offline.
    final id = await DatabaseService.instance.insertSavingGoal(data);
    if (_useCloud) {
      unawaited(() async {
        try {
          await FirestoreService.instance.insertSavingGoal(data);
        } catch (e) {
          debugPrint('[cloud] saving goal sync deferred: $e');
        }
      }());
    }
    savingGoals.add(SavingGoal(id: id, currency: currency, title: title, targetAmount: targetAmount, savedAmount: savedAmount, targetDate: targetDate, icon: icon, color: color, deposits: seed));
    notifyListeners();
  }

  Future<void> updateSavingGoal(SavingGoal g, {String? title, double? targetAmount, double? savedAmount, DateTime? targetDate, bool clearTargetDate = false, String? icon, String? color, List<GoalDeposit>? deposits}) async {
    final updated = SavingGoal(
      id: g.id,
      currency: g.currency,
      title: title ?? g.title,
      targetAmount: targetAmount ?? g.targetAmount,
      savedAmount: savedAmount ?? g.savedAmount,
      targetDate: clearTargetDate ? null : (targetDate ?? g.targetDate),
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
    String? icon,
    String? color,
  }) async {
    final tmp = Budget(
        id: 0, name: name, amount: amount, currency: currency,
        period: period, categories: categories, notifyOverspent: notifyOverspent,
        icon: icon, color: color);
    final id = await DatabaseService.instance.insertBudget(tmp.toMap());
    budgets.insert(0, Budget(
        id: id, name: name, amount: amount, currency: currency,
        period: period, categories: categories, notifyOverspent: notifyOverspent,
        icon: icon, color: color));
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
