# SplitSmart — Guest Join + Premium (Owner-Paid) Implementation Plan

> Status: **IMPLEMENTED in code** (Phases 0–3). Server-side store validation and
> store/console configuration remain operational tasks — see §7 Runbook.
> Last updated for the architecture as of branch `main`.

---

## ✅ Implementation status (what was built)

**Pure logic + tests**
- `lib/services/entitlement.dart` — `AccountTier`, `Entitlement`, guest-join
  decision engine (no Firebase/Flutter deps, fully unit-tested).
- `test/premium_guest_test.dart` — 29 tests covering tiers, migration gating,
  entitlement expiry/grace, the guest gate, the model field, and name-keyed
  guest balances. **All 50 project tests green; `flutter analyze` clean.**

**App wiring**
- `auth_service.dart` — `signInAnonymously`, `linkAnonymousToGoogle/Email`,
  `deleteAnonymousUser` (orphan rollback), `refreshIdToken`, `hasPremiumClaim`,
  `isGuest`.
- `app_state.dart` — tier-derived `_useCloud`, **migration gated to full
  accounts only**, entitlement load + live watcher + offline mirror,
  `joinAsGuest` (probe → gate → join, with anon rollback on failure), guest
  balance resolution, `setGroupGuestAccess`, `GroupData.isPremiumGroup`.
- `firestore_service.dart` — writes `memberMeta` (fixes uid↔name bug) +
  `isPremiumGroup`, guest-gated `joinGroupByInviteCode`, `probeInviteCode`,
  `setGroupGuestAccess`, `loadEntitlement`/`watchEntitlement`.
- `iap_service.dart` — Play/StoreKit purchase flow + `verifyPurchase` callable.
- `screens/paywall_screen.dart`, `screens/join_group_screen.dart`,
  owner toggle in `qr_share_screen.dart`, guest routing in `qr_scan_screen.dart`,
  `IapService.init()` in `main.dart`.

**Backend**
- `firebase/firestore.rules` — `isAnon()`/`hasPremium()`/`premiumFlagChanged()`
  helpers (legacy-safe via `.get(field, default)`), anon-create block, guest-join
  gate, premium-flag protection.
- `firebase/functions/index.js` — `verifyPurchase` (Play/App Store validation →
  custom claim + entitlement + group stamping), `playRtdnHandler`,
  `appStoreNotifications`, `cleanupAnonUsers` (orphan reaper).
- `firebase/test/firestore.rules.test.js` — emulator rules tests (run in CI;
  needs Java).

---

> Original design follows.

## Locked decisions

| Decision | Choice |
|---|---|
| Guest mechanism | **Firebase Anonymous Auth** (primary), CF Admin-SDK proxy reserved for future web/zero-install guests |
| IAP receipt validation | **Own Cloud Functions** (Play Developer API + App Store Server API) — no third party |
| What premium gates | **Guest join only.** All existing functionality stays free. |
| Who pays | **Group owner.** Creator subscribes; premium unlocks guest-join for groups they own. Guests never pay. |

---

## 0. Central design summary

Guests are accountless and cannot subscribe, so entitlement is **per-owner**. A paying
owner's groups are flagged `isPremiumGroup = true` by a trusted Cloud Function; security
rules permit anonymous (guest) joins **only** on premium groups. Everything else in the
app remains free.

Two coupled features, one rule of thumb: **the client never decides entitlement** — a
Cloud Function verifies the store receipt, writes the entitlement, sets a custom claim,
and stamps the owner's groups.

---

## 1. Architecture facts this plan depends on

- `_useCloud` is literally `AuthService.instance.isSignedIn` (`lib/providers/app_state.dart`).
  Any Firebase session — including anonymous — flips the app to the cloud path and triggers
  `_migrateLocalGroupsToCloud` / `_migrateLocalTransactionsToCloud`.
- Balances are keyed by **member name strings**, not UIDs (`getAllBalances`,
  `lib/providers/app_state.dart`). `members` (names) and `memberUids` (UIDs) are **parallel
  arrays with no guaranteed correspondence** — there is no uid↔name map today.
- Rules gate on `request.auth != null` + `uid in memberUids`, with a guest-join carve-out
  via `joinAttemptCode` (`firebase/firestore.rules`).
- `cloud_functions` is already a dependency. `in_app_purchase` is **not**.
- Join today is client-side: read `inviteCodes/{code}` → append self to
  `memberUids`/`members` (`lib/services/firestore_service.dart`). When not signed in,
  `qr_scan_screen.dart` silently falls back to a **local-only** import.

---

## 2. Part A — Guest / accountless join

### 2.1 Mechanism: Firebase Anonymous Auth

- `signInAnonymously()` produces a real `request.auth.uid` → existing rules + `memberUids`
  queries work almost unchanged.
- Guest UID → `memberUids`; chosen name → `members`. Balances attach by name (already works).
- Expense/settlement writes pass rules: `addedBy == request.auth.uid`, UID in `memberUids`.
- **Upgrade path:** `linkWithCredential` converts the anonymous user into a Google/email
  account keeping the **same UID** → guest keeps all groups and balances.

### 2.2 BLOCKER to fix first — decouple cloud mode from raw session

Because `_useCloud == isSignedIn`, anonymous sign-in would migrate a guest's local SQLite
history to a throwaway UID. Introduce an explicit tier:

```dart
enum AccountTier { local, guest, full }
```

- `_useCloud` becomes `tier == guest || tier == full`.
- `_migrateLocal*ToCloud` runs **only** for `tier == full`.
- Persist tier in SharedPreferences; derive on startup from `currentUser.isAnonymous`.

### 2.3 Data-model changes (Firestore)

1. `groups/{id}.memberMeta` — `map<uid, {name, isGuest, provider}>`. Fixes the parallel-array
   bug and lets the UI badge guests + resolve uid→name. Keep `members`/`memberUids` for
   backward compat and existing `arrayContains` queries. **Requires a one-time backfill** for
   existing groups.
2. `groups/{id}.isPremiumGroup: bool` + `premiumByUid: uid` — written **only** by the
   entitlement Cloud Function. Gatekeeper for guest joins.
3. Balance storage unchanged — guests stay name strings in `members`.

### 2.4 Security-rule changes (`firebase/firestore.rules`)

- Helper: `function isAnon() { return request.auth.token.firebase.sign_in_provider == 'anonymous'; }`
- Block anonymous group **creation**: add `&& !isAnon()` to `groups` `allow create` (anti-spam).
- Gate the guest-join branch: in the group `update` join clause require
  `resource.data.isPremiumGroup == true`.
- Expenses/settlements: no change (anon UID in `memberUids` already satisfies them).
  Optionally forbid anon users from deleting the group or editing membership beyond adding self.
- `inviteCodes/{code}` read stays open to `request.auth != null` (anon included).

### 2.5 App-code changes

- `lib/services/auth_service.dart`: add `signInAnonymously()`, `linkAnonymousToGoogle()`,
  `linkAnonymousToEmail()`, `bool get isGuest => currentUser?.isAnonymous ?? false`.
- `lib/providers/app_state.dart`: add `AccountTier`, gate migration, add `joinAsGuest(code, name)`;
  extend `getMyBalance` to resolve the stored guest name (not just `'You'`/displayName).
- `lib/services/firestore_service.dart`: `joinGroupByInviteCode` writes `memberMeta` + `isGuest`;
  reject join when `!isPremiumGroup`.
- `lib/screens/qr_scan_screen.dart` + new `lib/screens/join_group_screen.dart`: when not
  signed in, offer "Join as guest" → prompt for name → `signInAnonymously` → join. Replace the
  current local-only fallback.

---

## 3. Part B — Premium (owner-paid, guest-join gate)

### 3.1 Package

- `in_app_purchase: ^3.x` (official; Play Billing + StoreKit via
  `in_app_purchase_android` / `in_app_purchase_storekit`).

### 3.2 Server-side entitlement (own Cloud Functions)

1. Client buys → receives purchase token/receipt.
2. Client calls CF `verifyPurchase` (token-refresh `getIdToken(true)` afterwards).
3. CF validates with **Play Developer API** (Android) / **App Store Server API** (iOS), then:
   - writes `users/{uid}.entitlement = { premium, until, productId, store, originalTxnId }`
   - sets custom claim `premium: true`.
4. CF `onEntitlementChange` + store webhooks (Play RTDN / App Store Server Notifications)
   stamp `isPremiumGroup` / `premiumByUid` on the owner's groups; clear on expiry/refund/chargeback.

### 3.3 AppState entitlement state

- Add `bool isPremium`, `DateTime? premiumUntil`, loaded from `users/{uid}.entitlement` and
  refreshed via a Firestore listener. Expose `bool get hasPremium`.
- Cache to SharedPreferences with a grace window for offline; revoke on next sync.

### 3.4 Screens

- `lib/screens/paywall_screen.dart` — plan(s), localized store price, Subscribe, **Restore
  Purchases**, terms/privacy links (store requirement).
- Settings entry → deep-link to store-managed subscriptions.
- Upsell sheet shown when a free owner attempts to enable guest-join on a group.

### 3.5 Restore

- `InAppPurchase.restorePurchases()` on the paywall and on fresh install/sign-in; re-run
  `verifyPurchase` for restored items. **Required by Apple.**

### 3.6 Gating logic

- **Free:** all current functionality (create groups, add expenses, splits, sync, export, etc.).
- **Premium (owner only):** enabling **guest join** for a group → sets `isPremiumGroup`.
- Enforced in two layers: client UX gating **and** security rules
  (`isPremiumGroup` for the guest write; `request.auth.token.premium` for the owner toggle).

---

## 4. Phased rollout

| Phase | Scope | Ship gate |
|---|---|---|
| **0 — Foundations** | `AccountTier` refactor (decouple `_useCloud`); `memberMeta` + backfill; `isPremiumGroup` field; rules scaffolding behind flag; CF skeletons. | Migration no longer fires for non-`full` accounts. |
| **1 — Guest join (free beta)** | Anonymous auth, `joinAsGuest`, join screen, name capture, balance resolution. `isPremiumGroup` check disabled. | Guests join, add expenses, see balances; guest→real linking works. |
| **2 — IAP plumbing** | `in_app_purchase`, `verifyPurchase` CF, entitlement doc + custom claim, paywall, restore, store webhooks. No gating yet. | Sandbox purchases verify server-side and set entitlement. |
| **3 — Flip the gate** | Enable `isPremiumGroup` rule + client gating; guest-join requires owner entitlement. Grandfather existing users. | Free owners see paywall to enable guests; premium owners' groups accept guests. |
| **4 — Polish** | Guest→account linking UX, expiry/downgrade handling, orphan-anon cleanup CF, analytics, store metadata/review. | Store submission. |

---

## 5. Risks & flags

**Architecture**
- 🔴 `_useCloud == isSignedIn` migration trap — fix in Phase 0 or guest local data leaks to throwaway UIDs.
- 🔴 Parallel-array uid↔name bug — `memberMeta` fixes it but needs a backfill for existing groups.
- 🟡 Balance-by-name collisions — duplicate guest names or renames corrupt balances; enforce in-group name uniqueness or key off `memberMeta`.

**Guest / anonymous**
- 🟡 Device-bound identity — anon UID lives only on that device; reinstall = lost access unless linked. Prompt "create an account to keep your data."
- 🟡 Orphan accumulation — cleanup CF for abandoned anon accounts; never migrate their personal data.
- 🟡 Spam — block anon group creation; rate-limit joins.

**Billing**
- 🔴 Client-trust — entitlement must be server-verified; rules read `request.auth.token.premium`, never a client field.
- 🟡 Custom-claim propagation delay — force `getIdToken(true)` post-purchase.
- 🟡 Lifecycle — handle refunds, chargebacks, billing-retry/grace, expiry. Decide what happens to premium groups + their guests when the owner lapses (lock writes / read-only / retain data).
- 🟡 Offline entitlement — cache with grace window; revoke on next sync.
- 🟢 Review risk is low since only the **new** guest feature is paywalled (no existing free feature removed) — still grandfather any beta users.

**Privacy/legal**
- 🟡 Guests create PII (names, expense data) under GDPR; cover in privacy policy + deletion flow.

---

## 7. Operational runbook (remaining non-code tasks)

These cannot be done from the codebase and must be completed before release:

1. **Play Console / App Store Connect**
   - Create subscription products with IDs matching `IapService`:
     `splitsmart_premium_monthly`, `splitsmart_premium_yearly`.
   - Add localized pricing, terms, and a privacy URL on the paywall.
2. **Server credentials for `verifyPurchase`**
   - Google Play: enable the Android Publisher API; grant the Functions service
     account access in Play Console. Set `ANDROID_PACKAGE` env to the real
     applicationId.
   - App Store: configure App Store Server API key; production should verify the
     JWS x5c chain against Apple's root CA (current code decodes; add full chain
     verification).
3. **Webhooks**
   - Play: Monetization → Real-time developer notifications → publish to a
     Pub/Sub topic named `play-rtdn` (matches `playRtdnHandler`).
   - Apple: set the App Store Server Notifications V2 URL to the deployed
     `appStoreNotifications` function.
4. **Deploy**
   - `cd firebase/functions && npm install` (adds `googleapis`, `jsonwebtoken`).
   - `firebase deploy --only functions,firestore:rules`.
5. **Token refresh** — already handled client-side via `refreshIdToken()` after
   a verified purchase; verify the `premium` claim appears in rules.
6. **Backfill** — existing groups lack `memberMeta`/`isPremiumGroup`; rules are
   legacy-safe (`.get(...,false)`), and the fields populate on next write. Run a
   one-off backfill script if you want them eagerly set.
7. **CI** — wire `firebase/test` (needs Java) into the pipeline to run the rules
   suite.

### Known limitations / follow-ups
- App Store JWS certificate-chain verification is stubbed (decodes only).
- `cleanupAnonUsers` uses `listUsers` pagination — fine to ~100k users; switch to
  the Auth bulk export for larger bases.
- SQLite cache does not persist `isPremiumGroup` (re-synced from cloud; UI hint
  only — the security gate is server-side regardless).

---

## 6. New/changed file checklist

- `pubspec.yaml` — add `in_app_purchase`.
- `firebase/firestore.rules` — `isAnon()` helper, anon create block, `isPremiumGroup` join gate.
- `functions/` — `verifyPurchase`, `onEntitlementChange`, store-webhook handlers, anon cleanup.
- `lib/services/auth_service.dart` — anonymous sign-in + linking.
- `lib/services/firestore_service.dart` — `memberMeta`, premium-gated join.
- `lib/services/iap_service.dart` *(new)* — purchase flow, restore, CF verification call.
- `lib/providers/app_state.dart` — `AccountTier`, entitlement state, gated migration, `joinAsGuest`, balance resolution.
- `lib/screens/join_group_screen.dart` *(new)* — guest join entry.
- `lib/screens/paywall_screen.dart` *(new)* — subscription + restore.
- `lib/screens/qr_scan_screen.dart` — route unsigned users to guest join.
