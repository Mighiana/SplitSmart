part of 'app_state.dart';
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
