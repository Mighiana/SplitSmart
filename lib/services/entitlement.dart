/// Pure business logic for account tiers, premium entitlement, and the
/// guest-join gate. This file intentionally has **no** Firebase / Flutter
/// imports so it can be unit-tested deterministically.
///
/// Product rules (locked):
///   • Guest join is the ONLY paid feature. Everything else stays free.
///   • The GROUP OWNER pays. Premium unlocks guest-join for groups they own.
///   • Guests are accountless (Firebase Anonymous Auth) and never pay.
library;

/// How the current device session is participating.
///
///  • [local] — no Firebase session. SQLite-only, offline.
///  • [guest] — anonymous Firebase session. Cloud group access, but NO personal
///    data migration (we never upload a guest's local history to a throwaway uid).
///  • [full]  — Google / email account. Full cloud sync + migration.
enum AccountTier { local, guest, full }

/// Derive the account tier from the raw auth session.
///
/// This is the single source of truth that replaces the old
/// `_useCloud == isSignedIn` shortcut, which would have migrated a guest's
/// local data onto an anonymous uid.
AccountTier accountTierFrom({
  required bool signedIn,
  required bool isAnonymous,
}) {
  if (!signedIn) return AccountTier.local;
  return isAnonymous ? AccountTier.guest : AccountTier.full;
}

/// True when the app should route data through Firestore.
bool useCloudForTier(AccountTier tier) =>
    tier == AccountTier.guest || tier == AccountTier.full;

/// True when local SQLite data should be migrated up to the cloud on load.
/// Only full accounts migrate — guests must not pollute the cloud with a
/// throwaway identity's personal history.
bool shouldMigrateLocalData(AccountTier tier) => tier == AccountTier.full;

/// Server-verified premium entitlement for a user (the group owner).
///
/// The client NEVER decides this on its own — it mirrors what the
/// `verifyPurchase` Cloud Function wrote to `users/{uid}.entitlement` and the
/// `premium` custom claim. We keep a local copy only for UX/offline.
class Entitlement {
  final bool premium;

  /// Expiry of the current paid period. `null` means "no known expiry"
  /// (treated as active while [premium] is true — e.g. lifetime).
  final DateTime? until;

  final String? productId;
  final String? store; // 'play' | 'appstore'

  const Entitlement({
    this.premium = false,
    this.until,
    this.productId,
    this.store,
  });

  static const Entitlement none = Entitlement();

  /// Active at a given instant. Injecting [now] keeps this testable.
  ///
  /// [grace] extends validity past [until] to tolerate clock skew, billing
  /// retry, and offline caching. Default 3 days mirrors Play/StoreKit grace.
  bool isActiveAt(
    DateTime now, {
    Duration grace = const Duration(days: 3),
  }) {
    if (!premium) return false;
    final exp = until;
    if (exp == null) return true;
    return now.isBefore(exp.add(grace));
  }

  bool get isActive => isActiveAt(DateTime.now());

  factory Entitlement.fromMap(Map<String, dynamic>? m) {
    if (m == null) return none;
    final rawUntil = m['until'];
    DateTime? until;
    if (rawUntil is int) {
      until = DateTime.fromMillisecondsSinceEpoch(rawUntil);
    } else if (rawUntil is String) {
      until = DateTime.tryParse(rawUntil);
    } else if (rawUntil is DateTime) {
      until = rawUntil;
    }
    return Entitlement(
      premium: m['premium'] == true,
      until: until,
      productId: m['productId'] as String?,
      store: m['store'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'premium': premium,
        'until': until?.millisecondsSinceEpoch,
        'productId': productId,
        'store': store,
      };

  @override
  String toString() =>
      'Entitlement(premium: $premium, until: $until, store: $store)';
}

/// Outcome of evaluating whether a session can join a group as a guest.
enum GuestJoinDecision {
  /// Allowed — proceed to anonymous sign-in + join.
  allowed,

  /// The group's owner is not premium, so guest joining is disabled.
  notPremiumGroup,

  /// The group is at its member cap.
  groupFull,

  /// Already a full/known member — no guest join needed.
  alreadyMember,
}

/// Centralised, pure decision for the guest-join gate. Mirrors the Firestore
/// security rule so the client and server agree.
GuestJoinDecision evaluateGuestJoin({
  required bool isPremiumGroup,
  required int memberCount,
  required int maxMembers,
  bool alreadyMember = false,
}) {
  if (alreadyMember) return GuestJoinDecision.alreadyMember;
  if (!isPremiumGroup) return GuestJoinDecision.notPremiumGroup;
  if (memberCount >= maxMembers) return GuestJoinDecision.groupFull;
  return GuestJoinDecision.allowed;
}

/// Whether an owner may toggle guest access ON for a group they own.
/// Requires an active entitlement.
bool canEnableGuestAccess(Entitlement ownerEntitlement) =>
    ownerEntitlement.isActive;

/// Human-readable reason for a denied guest join (for UI/snackbars).
String guestJoinDenialMessage(GuestJoinDecision d) {
  switch (d) {
    case GuestJoinDecision.notPremiumGroup:
      return 'The group owner needs SplitSmart Premium to let guests join.';
    case GuestJoinDecision.groupFull:
      return 'This group is full.';
    case GuestJoinDecision.alreadyMember:
      return 'You are already a member of this group.';
    case GuestJoinDecision.allowed:
      return '';
  }
}
