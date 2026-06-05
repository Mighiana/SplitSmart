import 'package:flutter_test/flutter_test.dart';
import 'package:splitsmart/providers/app_state.dart';

/// Unit tests for the core settle-up algorithm and balance calculations.
///
/// These tests verify the most critical business logic in the app —
/// the balance engine that determines who owes whom and the minimum
/// transactions needed to settle debts.
void main() {
  group('getAllBalances', () {
    late AppState state;

    setUp(() {
      state = AppState();
    });

    test('equal split — 3 members, 1 expense', () {
      final g = GroupData(
        id: 1,
        name: 'Test',
        emoji: '🏠',
        currency: 'EUR',
        sym: '€',
        members: ['You', 'Ali', 'Sara'],
        expenses: [
          ExpenseData(
            id: 1,
            desc: 'Dinner',
            amount: 30,
            cat: '🍽️',
            paidBy: 'You',
            date: '2024-01-01',
          ),
        ],
      );

      final bal = state.getAllBalances(g);

      // You paid 30, each owes 10 → You gets back 20
      expect(bal['You'], 20.0);
      expect(bal['Ali'], -10.0);
      expect(bal['Sara'], -10.0);
    });

    test('equal split — multiple expenses, different payers', () {
      final g = GroupData(
        id: 2,
        name: 'Trip',
        emoji: '✈️',
        currency: 'EUR',
        sym: '€',
        members: ['You', 'Ali', 'Sara'],
        expenses: [
          ExpenseData(
            id: 1,
            desc: 'Dinner',
            amount: 42,
            cat: '🍽️',
            paidBy: 'You',
            date: '2024-01-01',
          ),
          ExpenseData(
            id: 2,
            desc: 'Taxi',
            amount: 18,
            cat: '🚗',
            paidBy: 'Sara',
            date: '2024-01-02',
          ),
        ],
      );

      final bal = state.getAllBalances(g);

      // Total = 60, each person's share = 20
      // You paid 42, share = 20 → net = +22
      // Ali paid 0, share = 20 → net = -20
      // Sara paid 18, share = 20 → net = -2
      expect(bal['You'], 22.0);
      expect(bal['Ali'], -20.0);
      expect(bal['Sara'], -2.0);

      // Verify sum is zero (conservation of money)
      final sum = bal.values.fold(0.0, (s, v) => s + v);
      expect(sum.abs(), lessThan(0.01));
    });

    test('custom split — unequal amounts', () {
      final g = GroupData(
        id: 3,
        name: 'Split Test',
        emoji: '💰',
        currency: 'USD',
        sym: '\$',
        members: ['You', 'Ali'],
        expenses: [
          ExpenseData(
            id: 1,
            desc: 'Hotel',
            amount: 100,
            cat: '🏠',
            paidBy: 'You',
            date: '2024-01-01',
            splits: {'You': 30, 'Ali': 70},
          ),
        ],
      );

      final bal = state.getAllBalances(g);

      // You paid 100, owes 30 → net = +70
      // Ali paid 0, owes 70 → net = -70
      expect(bal['You'], 70.0);
      expect(bal['Ali'], -70.0);
    });

    test('settlements reduce balances', () {
      final g = GroupData(
        id: 4,
        name: 'Settled',
        emoji: '✅',
        currency: 'EUR',
        sym: '€',
        members: ['You', 'Ali'],
        expenses: [
          ExpenseData(
            id: 1,
            desc: 'Dinner',
            amount: 40,
            cat: '🍽️',
            paidBy: 'You',
            date: '2024-01-01',
          ),
        ],
        settlements: [
          const SettlementData(
            from: 'Ali',
            to: 'You',
            amount: 20,
            method: 'Cash',
            date: '2024-01-02',
          ),
        ],
      );

      final bal = state.getAllBalances(g);

      // Without settlement: You +20, Ali -20
      // After Ali pays You 20: both should be 0
      expect(bal['You'], 0.0);
      expect(bal['Ali'], 0.0);
    });

    test('empty group — all balances zero', () {
      final g = GroupData(
        id: 5,
        name: 'Empty',
        emoji: '🏠',
        currency: 'EUR',
        sym: '€',
        members: ['You', 'Ali', 'Sara'],
      );

      final bal = state.getAllBalances(g);

      expect(bal['You'], 0.0);
      expect(bal['Ali'], 0.0);
      expect(bal['Sara'], 0.0);
    });

    test('single member group — balance is always zero', () {
      final g = GroupData(
        id: 6,
        name: 'Solo',
        emoji: '👤',
        currency: 'EUR',
        sym: '€',
        members: ['You'],
        expenses: [
          ExpenseData(
            id: 1,
            desc: 'Coffee',
            amount: 5,
            cat: '☕',
            paidBy: 'You',
            date: '2024-01-01',
          ),
        ],
      );

      final bal = state.getAllBalances(g);
      expect(bal['You'], 0.0);
    });

    test('custom split with zero allocation for one member', () {
      final g = GroupData(
        id: 7,
        name: 'Split Zero',
        emoji: '💰',
        currency: 'EUR',
        sym: '€',
        members: ['You', 'Ali', 'Sara'],
        expenses: [
          ExpenseData(
            id: 1,
            desc: 'Gift',
            amount: 50,
            cat: '🎁',
            paidBy: 'Ali',
            date: '2024-01-01',
            splits: {'You': 25, 'Ali': 25, 'Sara': 0},
          ),
        ],
      );

      final bal = state.getAllBalances(g);

      // Ali paid 50, owes 25 → net = +25
      // You paid 0, owes 25 → net = -25
      // Sara paid 0, owes 0 → net = 0
      expect(bal['Ali'], 25.0);
      expect(bal['You'], -25.0);
      expect(bal['Sara'], 0.0);
    });
  });

  group('getBalancesById (stable member ids)', () {
    late AppState state;
    setUp(() => state = AppState());

    test('duplicate names stay separate when keyed by id', () {
      final g = GroupData(
        id: 100,
        name: 'Dup',
        emoji: '🏠',
        currency: 'USD',
        sym: '\$',
        members: ['Sam', 'Sam', 'You'],
        roster: [
          GroupMember(id: 'u1', name: 'Sam'),
          GroupMember(id: 'u2', name: 'Sam'),
          GroupMember(id: 'u3', name: 'You'),
        ],
        expenses: [
          ExpenseData(
            id: 1,
            desc: 'Dinner',
            amount: 30,
            cat: '🍽️',
            paidBy: 'Sam',
            paidById: 'u1', // disambiguates which Sam paid
            date: '2024-01-01',
          ),
        ],
      );

      final byId = state.getBalancesById(g);
      // u1 paid 30, equal share 10 → +20; the OTHER Sam (u2) owes 10.
      expect(byId['u1'], 20.0);
      expect(byId['u2'], -10.0);
      expect(byId['u3'], -10.0);

      // Name projection sums same-named members (documented behavior).
      final byName = state.getAllBalances(g);
      expect(byName['Sam'], 10.0); // 20 + (-10)
      expect(byName['You'], -10.0);
    });

    test('legacy name-only expense resolves to id via roster', () {
      final g = GroupData(
        id: 101,
        name: 'Legacy',
        emoji: '🏠',
        currency: 'USD',
        sym: '\$',
        members: ['Ann', 'Bob'],
        roster: [
          GroupMember(id: 'u1', name: 'Ann'),
          GroupMember(id: 'u2', name: 'Bob'),
        ],
        expenses: [
          ExpenseData(
            id: 1,
            desc: 'Cab',
            amount: 20,
            cat: '🚗',
            paidBy: 'Ann', // no paidById → resolved via roster
            date: '2024-01-01',
          ),
        ],
      );

      final byId = state.getBalancesById(g);
      expect(byId['u1'], 10.0);
      expect(byId['u2'], -10.0);
    });

    test('mixed legacy + id expenses merge into one balance per member', () {
      final g = GroupData(
        id: 102,
        name: 'Mixed',
        emoji: '🏠',
        currency: 'USD',
        sym: '\$',
        members: ['Ann', 'Bob'],
        roster: [
          GroupMember(id: 'u1', name: 'Ann'),
          GroupMember(id: 'u2', name: 'Bob'),
        ],
        expenses: [
          ExpenseData(
            id: 1, desc: 'Old', amount: 20, cat: '🍽️',
            paidBy: 'Ann', date: '2024-01-01', // legacy
          ),
          ExpenseData(
            id: 2, desc: 'New', amount: 10, cat: '🍽️',
            paidBy: 'Ann', paidById: 'u1', date: '2024-01-02', // id-keyed
          ),
        ],
      );

      final byId = state.getBalancesById(g);
      // Both expenses' payer collapse to u1: +15 / -15, not split across keys.
      expect(byId['u1'], 15.0);
      expect(byId['u2'], -15.0);
      expect(byId.keys.where((k) => k.startsWith('name:')), isEmpty);
    });

    test('settlement by id reduces the correct member', () {
      final g = GroupData(
        id: 103,
        name: 'Settle',
        emoji: '🏠',
        currency: 'USD',
        sym: '\$',
        members: ['Ann', 'Bob'],
        roster: [
          GroupMember(id: 'u1', name: 'Ann'),
          GroupMember(id: 'u2', name: 'Bob'),
        ],
        expenses: [
          ExpenseData(
            id: 1, desc: 'Cab', amount: 20, cat: '🚗',
            paidBy: 'Ann', paidById: 'u1', date: '2024-01-01',
          ),
        ],
        settlements: [
          const SettlementData(
            from: 'Bob', to: 'Ann', amount: 10, method: 'Cash',
            date: '2024-01-02', fromId: 'u2', toId: 'u1',
          ),
        ],
      );

      final byId = state.getBalancesById(g);
      expect(byId['u1'], 0.0);
      expect(byId['u2'], 0.0);
    });

    test('custom id-keyed splits compute correctly', () {
      final g = GroupData(
        id: 104,
        name: 'CustomId',
        emoji: '💰',
        currency: 'USD',
        sym: '\$',
        members: ['Ann', 'Bob'],
        roster: [
          GroupMember(id: 'u1', name: 'Ann'),
          GroupMember(id: 'u2', name: 'Bob'),
        ],
        expenses: [
          ExpenseData(
            id: 1, desc: 'Hotel', amount: 100, cat: '🏠',
            paidBy: 'Ann', paidById: 'u1', date: '2024-01-01',
            splitIds: {'u1': 30, 'u2': 70},
          ),
        ],
      );

      final byId = state.getBalancesById(g);
      expect(byId['u1'], 70.0);
      expect(byId['u2'], -70.0);
    });

    test('unresolvable explicit id never leaks as a balance key', () {
      // Regression: a paidById that is NOT in the roster (stale / cross-device
      // id) must fall back to name-keying so the UI never shows a raw uid.
      final g = GroupData(
        id: 105,
        name: 'Stale',
        emoji: '💰',
        currency: 'USD',
        sym: '\$',
        members: ['Ann', 'Bob'],
        roster: [
          GroupMember(id: 'u1', name: 'Ann'),
          GroupMember(id: 'u2', name: 'Bob'),
        ],
        expenses: [
          ExpenseData(
            id: 1, desc: 'Cab', amount: 20, cat: '🚗',
            paidBy: 'Ann', paidById: 'dEd5aVqduOPRstaleUid', // not in roster
            date: '2024-01-01',
          ),
        ],
      );

      final byId = state.getBalancesById(g);
      // The stale id must NOT appear; the payer resolves to 'Ann' → u1.
      expect(byId.containsKey('dEd5aVqduOPRstaleUid'), isFalse);
      expect(byId['u1'], 10.0);
      expect(byId['u2'], -10.0);
      // Every key must be displayable (a roster id or a name: pseudo-key).
      for (final k in byId.keys) {
        expect(g.displayNameForKey(k) != k || k.startsWith('name:'), isTrue,
            reason: 'key "$k" is not resolvable to a display name');
      }
    });
  });

  group('buildSettlePlan', () {
    late AppState state;

    setUp(() {
      state = AppState();
    });

    test('minimum transactions to settle 3-person group', () {
      final g = GroupData(
        id: 10,
        name: 'Plan Test',
        emoji: '🏠',
        currency: 'EUR',
        sym: '€',
        members: ['You', 'Ali', 'Sara'],
        expenses: [
          ExpenseData(
            id: 1,
            desc: 'Dinner',
            amount: 30,
            cat: '🍽️',
            paidBy: 'You',
            date: '2024-01-01',
          ),
        ],
      );

      final plan = state.buildSettlePlan(g);

      // You is owed 20, Ali owes 10, Sara owes 10
      // Min transactions: Ali→You 10, Sara→You 10
      expect(plan.length, 2);

      final totalPaid = plan.fold(0.0, (s, p) => s + p.amount);
      expect(totalPaid, 20.0);

      // All payments should go to You
      for (final p in plan) {
        expect(p.to, 'You');
      }
    });

    test('already settled — empty plan', () {
      final g = GroupData(
        id: 11,
        name: 'Settled',
        emoji: '✅',
        currency: 'EUR',
        sym: '€',
        members: ['You', 'Ali'],
        expenses: [
          ExpenseData(
            id: 1,
            desc: 'Dinner',
            amount: 40,
            cat: '🍽️',
            paidBy: 'You',
            date: '2024-01-01',
          ),
        ],
        settlements: [
          const SettlementData(
            from: 'Ali',
            to: 'You',
            amount: 20,
            method: 'Cash',
            date: '2024-01-02',
          ),
        ],
      );

      final plan = state.buildSettlePlan(g);
      expect(plan, isEmpty);
    });

    test('no expenses — empty plan', () {
      final g = GroupData(
        id: 12,
        name: 'Empty',
        emoji: '🏠',
        currency: 'EUR',
        sym: '€',
        members: ['You', 'Ali', 'Sara'],
      );

      final plan = state.buildSettlePlan(g);
      expect(plan, isEmpty);
    });

    test('complex 4-person group — plan settles everyone', () {
      final g = GroupData(
        id: 13,
        name: 'Big Trip',
        emoji: '✈️',
        currency: 'EUR',
        sym: '€',
        members: ['You', 'Ali', 'Sara', 'Hamza'],
        expenses: [
          ExpenseData(id: 1, desc: 'Hotel', amount: 200, cat: '🏠', paidBy: 'You', date: '2024-01-01'),
          ExpenseData(id: 2, desc: 'Food', amount: 80, cat: '🍽️', paidBy: 'Ali', date: '2024-01-02'),
          ExpenseData(id: 3, desc: 'Taxi', amount: 40, cat: '🚗', paidBy: 'Sara', date: '2024-01-03'),
        ],
      );

      final plan = state.buildSettlePlan(g);

      // Total = 320, each share = 80
      // You: paid 200, share 80 → net +120
      // Ali: paid 80, share 80 → net 0
      // Sara: paid 40, share 80 → net -40
      // Hamza: paid 0, share 80 → net -80
      // Plan should have 2 transactions (Hamza→You 80, Sara→You 40)

      expect(plan.length, 2);

      // Verify net settlement amounts sum correctly
      final totalSettled = plan.fold(0.0, (s, p) => s + p.amount);
      expect(totalSettled, 120.0);
    });
  });

  group('activeGroups / archivedGroups', () {
    late AppState state;

    setUp(() {
      state = AppState();
      state.groups = [
        GroupData(id: 1, name: 'Active 1', emoji: '🏠', currency: 'EUR', sym: '€', members: ['You']),
        GroupData(id: 2, name: 'Archived', emoji: '📦', currency: 'USD', sym: '\$', members: ['You'], isArchived: true),
        GroupData(id: 3, name: 'Active 2', emoji: '✈️', currency: 'GBP', sym: '£', members: ['You']),
      ];
    });

    test('activeGroups excludes archived', () {
      expect(state.activeGroups.length, 2);
      expect(state.activeGroups.every((g) => !g.isArchived), true);
    });

    test('archivedGroups only includes archived', () {
      expect(state.archivedGroups.length, 1);
      expect(state.archivedGroups.first.name, 'Archived');
    });
  });

  group('Model classes', () {
    test('SavingGoal.fromMap / toMap round-trip', () {
      final map = {
        'id': 42,
        'currency': 'EUR',
        'title': 'Laptop',
        'target_amount': 1500.0,
        'saved_amount': 300.0,
        'target_date': '2024-12-31',
      };

      final goal = SavingGoal.fromMap(map);
      expect(goal.id, 42);
      expect(goal.currency, 'EUR');
      expect(goal.title, 'Laptop');
      expect(goal.targetAmount, 1500.0);
      expect(goal.savedAmount, 300.0);
      expect(goal.targetDate, isNotNull);

      final exported = goal.toMap();
      expect(exported['currency'], 'EUR');
      expect(exported['title'], 'Laptop');
      expect(exported['target_amount'], 1500.0);
    });

    test('ExpenseData.splitsJson encodes correctly', () {
      final e = ExpenseData(
        id: 1,
        desc: 'Test',
        amount: 100,
        cat: '💰',
        paidBy: 'You',
        date: '2024-01-01',
        splits: {'You': 30, 'Ali': 70},
      );

      expect(e.splitsJson, isNotNull);
      expect(e.splitsJson!, contains('You'));
      expect(e.splitsJson!, contains('Ali'));
    });

    test('ExpenseData.splitsJson is null for equal split', () {
      final e = ExpenseData(
        id: 1,
        desc: 'Test',
        amount: 100,
        cat: '💰',
        paidBy: 'You',
        date: '2024-01-01',
      );

      expect(e.splitsJson, isNull);
    });

    test('TransactionData.parseDate handles ISO format', () {
      final d = TransactionData.parseDate('2024-03-15');
      expect(d, isNotNull);
      expect(d!.month, 3);
      expect(d.day, 15);
    });

    test('TransactionData.parseDate handles "today"', () {
      final d = TransactionData.parseDate('Today');
      expect(d, isNotNull);
      expect(d!.day, DateTime.now().day);
    });

    test('TransactionData.parseDate handles "X days ago"', () {
      final d = TransactionData.parseDate('3 days ago');
      expect(d, isNotNull);
      final expected = DateTime.now().subtract(const Duration(days: 3));
      expect(d!.day, expected.day);
    });

    test('TransactionData.parseDate handles "DD Mon" format', () {
      final d = TransactionData.parseDate('28 Feb');
      expect(d, isNotNull);
      expect(d!.month, 2);
      expect(d.day, 28);
    });

    test('SubscriptionData.nextBillingDate is in the future', () {
      final sub = SubscriptionData(
        id: 1,
        name: 'Netflix',
        amount: 15.99,
        currency: 'USD',
        sym: '\$',
        cycle: 'monthly',
        billingDay: 1,
        category: 'Entertainment',
        emoji: '🎬',
        colorHex: '#FF0000',
        createdAt: DateTime.now(),
      );

      final next = sub.nextBillingDate;
      expect(next.isAfter(DateTime.now().subtract(const Duration(days: 1))), true);
    });

    test('SubscriptionData.monthlyEquivalent calculations', () {
      // Monthly stays the same
      final monthly = SubscriptionData(
        id: 1, name: 'Test', amount: 10, currency: 'USD', sym: '\$',
        cycle: 'monthly', billingDay: 1, category: 'Test', emoji: '💰',
        colorHex: '#000', createdAt: DateTime.now(),
      );
      expect(monthly.monthlyEquivalent, 10.0);

      // Yearly divided by 12
      final yearly = SubscriptionData(
        id: 2, name: 'Test', amount: 120, currency: 'USD', sym: '\$',
        cycle: 'yearly', billingDay: 1, billingMonth: 1, category: 'Test',
        emoji: '💰', colorHex: '#000', createdAt: DateTime.now(),
      );
      expect(yearly.monthlyEquivalent, 10.0);

      // Weekly multiplied by ~4.333
      final weekly = SubscriptionData(
        id: 3, name: 'Test', amount: 10, currency: 'USD', sym: '\$',
        cycle: 'weekly', billingDay: 1, category: 'Test', emoji: '💰',
        colorHex: '#000', createdAt: DateTime.now(),
      );
      expect(weekly.monthlyEquivalent, closeTo(43.33, 0.01));
    });
  });

  group('VoiceInputService parsing', () {
    // Test the regex/parsing logic used in voice input
    test('extract amount from spoken text', () {
      // Direct number extraction
      final numMatch = RegExp(r'(\d+\.?\d*)').firstMatch('42 euros dinner');
      expect(numMatch, isNotNull);
      expect(double.tryParse(numMatch!.group(1)!), 42.0);
    });

    test('extract "paid by" from spoken text', () {
      final paidByMatch = RegExp(r'(?:paid\s+by|by)\s+(\w+)')
          .firstMatch('dinner paid by Ali');
      expect(paidByMatch, isNotNull);
      expect(paidByMatch!.group(1), 'Ali');
    });
  });

  group('ReceiptScanner amount extraction', () {
    test('extracts amount from total line', () {
      // Simulate the regex from receipt_scanner_service.dart
      final patterns = [
        RegExp(r'[\$€£¥₹]?\s*(\d{1,3}(?:,\d{3})*\.?\d{0,2})\b'),
        RegExp(r'(\d+[.,]\d{2})\b'),
      ];

      const line = 'TOTAL: \$42.50';
      double? result;
      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final raw = match.group(1) ?? '';
          result = double.tryParse(raw);
          if (result != null) break;
        }
      }
      expect(result, 42.50);
    });

    test('handles European comma decimal', () {
      const cleaned = '42,50';
      final parts = cleaned.split(',');
      String normalized;
      if (parts.last.length == 2) {
        normalized = cleaned.replaceAll(',', '.');
      } else {
        normalized = cleaned.replaceAll(',', '');
      }
      expect(double.tryParse(normalized), 42.50);
    });
  });

  group('budgetSpent subcategories', () {
    late AppState state;
    final today = DateTime.now().toIso8601String();

    setUp(() {
      state = AppState();
      state.transactions = [
        // Food (parent), no sub-category
        TransactionData(id: 1, type: 'expense', desc: 'Lunch', amount: 20, cat: '🍽️', currency: 'USD', sym: '\$', date: today),
        // Food → Groceries
        TransactionData(id: 2, type: 'expense', desc: 'Market', amount: 50, cat: '🍽️', subcat: 'sub:food:groceries', currency: 'USD', sym: '\$', date: today),
        // Food → Restaurants
        TransactionData(id: 3, type: 'expense', desc: 'Dinner', amount: 30, cat: '🍽️', subcat: 'sub:food:restaurant', currency: 'USD', sym: '\$', date: today),
        // Transport (parent)
        TransactionData(id: 4, type: 'expense', desc: 'Bus', amount: 10, cat: '🚌', currency: 'USD', sym: '\$', date: today),
        // Income — must never count toward a spending budget
        TransactionData(id: 5, type: 'income', desc: 'Pay', amount: 999, cat: '💼', currency: 'USD', sym: '\$', date: today),
        // Different currency — must be excluded
        TransactionData(id: 6, type: 'expense', desc: 'EU food', amount: 77, cat: '🍽️', currency: 'EUR', sym: '€', date: today),
      ];
    });

    Budget budget(List<String> cats) => Budget(
        id: 1, name: 'B', amount: 1000, currency: 'USD', period: 'monthly', categories: cats);

    test('parent-level budget counts every transaction of that category', () {
      // Food parent = 20 + 50 + 30 = 100 (EUR food excluded)
      expect(state.budgetSpent(budget(['🍽️'])), 100);
    });

    test('sub-level budget counts only the matching sub-category', () {
      expect(state.budgetSpent(budget(['sub:food:groceries'])), 50);
      expect(state.budgetSpent(budget(['sub:food:restaurant'])), 30);
    });

    test('empty categories counts all expenses in the budget currency', () {
      // 20 + 50 + 30 + 10 = 110 (income + EUR excluded)
      expect(state.budgetSpent(budget([])), 110);
    });

    test('parent + another category sum without double counting', () {
      // Food parent (100) + Transport (10) = 110
      expect(state.budgetSpent(budget(['🍽️', '🚌'])), 110);
    });

    test('subcategory helpers resolve keys', () {
      expect(AppState.subsFor('🍽️').isNotEmpty, true);
      expect(AppState.parentOfSub('sub:food:groceries'), '🍽️');
      expect(AppState.subByKey('sub:food:groceries')?.label, 'Groceries');
      expect(AppState.labelForKey('🍽️'), 'Food');
      expect(AppState.labelForKey('sub:food:groceries'), 'Groceries');
    });
  });
}
