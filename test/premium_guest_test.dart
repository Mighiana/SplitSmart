import 'package:flutter_test/flutter_test.dart';
import 'package:splitsmart/services/entitlement.dart';
import 'package:splitsmart/providers/app_state.dart';

/// Tests for the guest-join + owner-paid-premium business logic.
/// These cover the pure decision layer that both the client and the
/// Firestore security rules rely on.
void main() {
  group('accountTierFrom', () {
    test('no session → local', () {
      expect(
        accountTierFrom(signedIn: false, isAnonymous: false),
        AccountTier.local,
      );
    });

    test('anonymous session → guest', () {
      expect(
        accountTierFrom(signedIn: true, isAnonymous: true),
        AccountTier.guest,
      );
    });

    test('real account → full', () {
      expect(
        accountTierFrom(signedIn: true, isAnonymous: false),
        AccountTier.full,
      );
    });
  });

  group('cloud routing & migration gating', () {
    test('local tier does not use cloud and does not migrate', () {
      expect(useCloudForTier(AccountTier.local), isFalse);
      expect(shouldMigrateLocalData(AccountTier.local), isFalse);
    });

    test('guest uses cloud but NEVER migrates personal data', () {
      expect(useCloudForTier(AccountTier.guest), isTrue);
      // This is the critical safety property: guests must not upload their
      // local SQLite history onto a throwaway anonymous uid.
      expect(shouldMigrateLocalData(AccountTier.guest), isFalse);
    });

    test('full account uses cloud and migrates', () {
      expect(useCloudForTier(AccountTier.full), isTrue);
      expect(shouldMigrateLocalData(AccountTier.full), isTrue);
    });
  });

  group('Entitlement.isActiveAt', () {
    final now = DateTime(2026, 6, 2, 12);

    test('not premium is never active', () {
      const e = Entitlement(premium: false);
      expect(e.isActiveAt(now), isFalse);
    });

    test('premium with no expiry is active (lifetime)', () {
      const e = Entitlement(premium: true);
      expect(e.isActiveAt(now), isTrue);
    });

    test('premium before expiry is active', () {
      final e = Entitlement(premium: true, until: now.add(const Duration(days: 10)));
      expect(e.isActiveAt(now), isTrue);
    });

    test('premium just past expiry is still active within grace window', () {
      final e = Entitlement(premium: true, until: now.subtract(const Duration(days: 1)));
      // default 3-day grace
      expect(e.isActiveAt(now), isTrue);
    });

    test('premium well past expiry + grace is inactive', () {
      final e = Entitlement(premium: true, until: now.subtract(const Duration(days: 5)));
      expect(e.isActiveAt(now), isFalse);
    });

    test('grace window is configurable', () {
      final e = Entitlement(premium: true, until: now.subtract(const Duration(days: 1)));
      expect(e.isActiveAt(now, grace: Duration.zero), isFalse);
    });
  });

  group('Entitlement serialization', () {
    test('round-trips through map', () {
      final e = Entitlement(
        premium: true,
        until: DateTime.fromMillisecondsSinceEpoch(1800000000000),
        productId: 'premium_monthly',
        store: 'play',
      );
      final restored = Entitlement.fromMap(e.toMap());
      expect(restored.premium, isTrue);
      expect(restored.until, e.until);
      expect(restored.productId, 'premium_monthly');
      expect(restored.store, 'play');
    });

    test('null map → none', () {
      final e = Entitlement.fromMap(null);
      expect(e.premium, isFalse);
      expect(e.isActive, isFalse);
    });

    test('parses ISO string until', () {
      final e = Entitlement.fromMap({'premium': true, 'until': '2030-01-01T00:00:00Z'});
      expect(e.premium, isTrue);
      expect(e.until, isNotNull);
    });
  });

  group('evaluateGuestJoin gate', () {
    test('allowed on a premium group with room', () {
      final d = evaluateGuestJoin(
        isPremiumGroup: true,
        memberCount: 3,
        maxMembers: 50,
      );
      expect(d, GuestJoinDecision.allowed);
    });

    test('blocked when group owner is not premium', () {
      final d = evaluateGuestJoin(
        isPremiumGroup: false,
        memberCount: 3,
        maxMembers: 50,
      );
      expect(d, GuestJoinDecision.notPremiumGroup);
      expect(guestJoinDenialMessage(d), contains('Premium'));
    });

    test('blocked when group is full', () {
      final d = evaluateGuestJoin(
        isPremiumGroup: true,
        memberCount: 50,
        maxMembers: 50,
      );
      expect(d, GuestJoinDecision.groupFull);
    });

    test('already-member short-circuits before other checks', () {
      final d = evaluateGuestJoin(
        isPremiumGroup: false,
        memberCount: 99,
        maxMembers: 50,
        alreadyMember: true,
      );
      expect(d, GuestJoinDecision.alreadyMember);
    });
  });

  group('canEnableGuestAccess', () {
    test('owner with active entitlement can enable', () {
      const e = Entitlement(premium: true);
      expect(canEnableGuestAccess(e), isTrue);
    });

    test('owner without entitlement cannot enable', () {
      expect(canEnableGuestAccess(Entitlement.none), isFalse);
    });
  });

  group('GroupData.isPremiumGroup model field', () {
    test('defaults to false', () {
      final g = GroupData(
        id: 1,
        name: 'X',
        emoji: '🏠',
        currency: 'EUR',
        sym: '€',
        members: const ['You'],
      );
      expect(g.isPremiumGroup, isFalse);
    });

    test('can be constructed as premium and toggled', () {
      final g = GroupData(
        id: 1,
        name: 'X',
        emoji: '🏠',
        currency: 'EUR',
        sym: '€',
        members: const ['You'],
        isPremiumGroup: true,
      );
      expect(g.isPremiumGroup, isTrue);
      g.isPremiumGroup = false;
      expect(g.isPremiumGroup, isFalse);
    });
  });

  group('Guest balance attaches by name (regression for name-keyed balances)', () {
    test('a guest member accrues a balance like any other member', () {
      final state = AppState();
      final g = GroupData(
        id: 99,
        name: 'Roadtrip',
        emoji: '🚗',
        currency: 'EUR',
        sym: '€',
        // "Sam" is a guest who joined accountlessly.
        members: const ['You', 'Sam'],
        expenses: [
          ExpenseData(
            id: 1,
            desc: 'Gas',
            amount: 40,
            cat: '🚗',
            paidBy: 'You',
            date: '2026-01-01',
          ),
        ],
      );
      final bal = state.getAllBalances(g);
      // You paid 40, each owes 20 → You +20, Sam -20.
      expect(bal['You'], 20.0);
      expect(bal['Sam'], -20.0);
    });
  });
}
