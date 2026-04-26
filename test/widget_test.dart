import 'package:flutter_test/flutter_test.dart';
import 'package:Splitsmart/providers/app_state.dart';

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
          SettlementData(
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
          SettlementData(
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
}
