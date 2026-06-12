# SplitSmart — Project Handoff & Context

> **Purpose of this file:** a complete, self-contained brief so **any AI model or developer** can understand the project and continue work without prior context.
> **RULE: Keep this file updated.** After *every* meaningful change, update the relevant section and add an entry to the **Changelog** at the bottom (newest first). Treat this as the single source of truth.

_Last updated: 2026-06-12_

---

## 1. What is SplitSmart?

A cross-platform **Flutter** mobile app (Android + iOS) that is two things in one:
1. **Bill splitter** — create groups, add shared expenses, auto-calculate who owes whom, and settle up.
2. **Personal money manager** — track personal income/expenses across multiple currency "accounts" (wallets), saving goals, subscriptions, reminders, and budgets.

- **Package id:** `com.splitsmart.splitsmart`
- **App version:** `1.0.0+20260424` (see `pubspec.yaml`)
- **Min Android SDK:** 21

---

## 2. Tech Stack

| Concern | Choice |
|---|---|
| Framework | Flutter (Dart SDK `>=3.0.0 <4.0.0`) |
| State management | **Provider** — `AppState extends ChangeNotifier` (`lib/providers/app_state.dart`) |
| Local DB (offline source of truth) | **SQLite** via `sqflite` — file `splitsmart_v3.db`, **schema version 19** |
| Cloud backend | **Firebase**: Auth, Cloud Firestore, Storage, Cloud Functions, Messaging, Analytics, Crashlytics |
| Auth | Firebase Auth + Google Sign-In |
| Fonts | `google_fonts` — **Gloock** (serif display) + **Geist** (sans body). Loaded at runtime, not bundled. |
| Charts | `fl_chart` |
| Animations | `flutter_animate`, `confetti` |
| QR | `qr_flutter` (generate) + `mobile_scanner` (scan) |
| In-app purchases | `in_app_purchase` (Play Billing + StoreKit) — see `iap_service.dart`, `entitlement.dart`, `paywall_screen.dart` |
| Notifications | `flutter_local_notifications` + `firebase_messaging` + `timezone` |
| Other | `shared_preferences`, `image_picker`, `share_plus`, `pdf`/`printing` (export), `local_auth` (app lock), `speech_to_text` (voice entry), `file_picker` (backup) |

---

## 3. Architecture & Data Flow

**Local-first, cloud-synced.**

- `AppState` is the central store (Provider). UI reads via `context.watch<AppState>()` / `context.read<AppState>()`.
- `AppState` has a `_useCloud` flag — **true when the user is signed in** (data flows through Firestore), otherwise local-only SQLite.
- **CRITICAL PATTERN (local-first writes):** mutations write to **SQLite first (awaited)**, update in-memory state, `notifyListeners()`, and return immediately. Firestore writes run in the **background (fire-and-forget)** so the UI never blocks.
  - Why: Firestore write Futures (`.add()/.set()/.update()`) **do not resolve while offline** — awaiting them hangs the UI. This caused the historic "Add Expense save does nothing" bug. See `addTransaction()` / `addExpenseToGroup()` in `app_state.dart`.
- Subscriptions & reminders are **always local SQLite** (not synced).
- `DatabaseService` (`lib/services/database_service.dart`) = SQLite layer. `FirestoreService` = cloud layer. `AppState` orchestrates both.

### Data model (key entities)
- **GroupData** — `id`, `name`, `emoji`, `currency`/`sym`, `members` (List<String> names), `memberUids`, `createdBy`, `inviteCode`, `firestoreId`, `expenses` (List<ExpenseData>), `isArchived`.
- **ExpenseData** — `id`, `desc`, `amount`, `cat` (emoji), `paidBy` (member name), `date`, `splits` (Map<member,amount> or null = equal), `receipt`/`receiptPath`, `createdBy`, `updatedBy`.
- **TransactionData** — personal: `id`, `type` ('expense'|'income'), `desc`, `amount`, `cat`, `currency`/`sym`, `date`, `receiptPath`.
- **Wallets** — `Map<currencyCode, double>` (personal balances, one "account" per currency). `groupWallets` similar.
- **SavingGoal** — `id`, `title`, `currency`, `targetAmount`, `savedAmount`, `targetDate?`.
- Subscriptions, Reminders, Budgets — local lists in `AppState`.

### Balance helpers (in `app_state.dart`)
- `getMyBalance(GroupData g)` — current user's net in a group.
- `getAllBalances(g)` — per-member balances. `buildSettlePlan(g)` — optimized settlement transfers.
- `getGroupWalletBalance(currency)` — sum of my group balances in a currency (used by Home Net Position).

---

## 4. Design System (`lib/utils/theme_utils.dart` → class `TC`)

Theme-aware. All colors are functions of `BuildContext` (light/dark). **Use `TC.*` — never hardcode hex.**

### Palette (light / dark)
| Token | Light | Dark | Use |
|---|---|---|---|
| `TC.primary` | `#0D7377` (Deep Teal) | `#14A085` | brand primary |
| `TC.primaryMd` | `#149080` | `#1AB899` | eyebrow labels, links |
| `TC.primaryGlow` | teal @ alpha | — | card glow shadows |
| `TC.primaryPale` | teal @ ~7% | — | tinted chips/bg |
| `TC.text` | `#111918` | `#E8F4F5` | primary text |
| `TC.text2` | `#4E6560` | `#7FB8C0` | secondary |
| `TC.text3` | `#9BB5B0` | `#4A8090` | muted |
| `TC.border` | `#D4E3E1` | `#1E3A40` | borders/dividers |
| `TC.bg` | `#F7F5F0` (Cream) | `#0A1A1C` | scaffold bg |
| `TC.bg2` | `#EDE9E1` | — | subtle fill |
| `TC.card` | `#FDFCFA` | `#122228` | cards |
| `TC.card2` | `#F9F7F3` | `#162B30` | nested cards |
| `TC.ok` | `#059669` (Emerald) | `#34D399` | positive/income |
| `TC.er` | `#E85A6A` (Coral) | `#F87171` | negative/expense/delete |
| `TC.wn` | `#D97706` (Amber) | `#FBBF24` | warning/overdue |
| `TC.blue` | `#3B82F6` | `#60A5FA` | personal tag |
| `TC.purple` | `#8B5CF6` | `#A78BFA` | settlement/insight tag |

Helpers: `TC.cardGradient(ctx)` (teal hero gradient), `TC.navBg(ctx)`, `TC.surface(ctx)`, `TC.shadow(ctx)`.

### Typography (STRICT — this is the app's signature)
- **Numbers/amounts are ALWAYS Gloock serif** → `TC.gloock(ctx, fontSize:, letterSpacing:, color:)`. They lead the visual hierarchy on every screen.
- **Body/labels are Geist** → `TC.geist(ctx, fontSize:, fontWeight:, color:, letterSpacing:)`. Names/labels use **w500–w700**, body **w400–w500**.
- **Screen header pattern:** small teal **eyebrow** (Geist ~10px, w700, letterSpacing 1.5, `TC.primaryMd`, UPPERCASE) above a **Gloock title** (~28–34px, letterSpacing ~-0.5). Example in `planner_screen.dart`.
- **Cards are shadow-only** (no borders in light mode) per the design spec.

### Reference design
- Source spec: `C:\Users\usman\Downloads\SplitSmart — UI_UX Design Showcase.pdf` (the authoritative visual spec).
- Editable Figma recreation (partial, free-plan rate-limited): `https://www.figma.com/design/YsNwnm1M3YcMcuCBhFfP1n`

---

## 5. Navigation & Screen Map

Root: `main.dart` → `HomeScreen` (`lib/screens/main_navigation_screen.dart`) = `Scaffold` with `IndexedStack` + custom bottom nav.

**Bottom nav (5 slots):** `Home(0) · Overview(1) · [+ FAB center] · Groups(2) · Planner(3)`
- The center **`+` FAB expands into a context-aware menu** (rotates to red ✕): Home/Overview → Add Expense/Add Income/New Group/New Reminder; Groups → Add Expense/New Group; Planner → New Goal/Add Subscription/New Reminder. Implemented in `main_navigation_screen.dart` (`_fabMenuItems`, `_buildFabMenuOverlay`).

| Tab | Class | File | Purpose |
|---|---|---|---|
| Home | `MoneyTab` | `personal_finance_tab.dart` | "Where do I stand" — **Net Position** card (Personal+Groups, collapsible chevron), quick stats, Smart Insight, Coming Up, Recent |
| Overview | `HomeTab` | `overview_tab.dart` | "How am I spending" — date-range tabs, Total Spent (Gloock), donut, categories. **No balance.** |
| Groups | `GroupsTab` | `groups_screen.dart` | Active/Archived groups list |
| Planner | `PlannerScreen` | `planner_screen.dart` | Snapshot (Active Goals/Subs/Overdue — no money total), Goals/Subs/Reminders sections |

**Detail / secondary screens:** `group_detail_screen.dart` (tabs: Expenses / Breakdown / Settle Up — in `lib/screens/group_tabs/`), `saving_goals_screen.dart`, `goal_detail_screen.dart`, `subscriptions_screen.dart`, `reminders_screen.dart`, `activity_screen.dart` (Revolut-style transactions list), `add_transaction_screen.dart`, `add_expense_screen.dart`, `transaction_type_screen.dart`, `new_group_screen.dart`, `join_group_screen.dart`, `qr_share_screen.dart`, `qr_scan_screen.dart`, `settings_screen.dart`, `auth_screen.dart`, `onboarding_screen.dart`, `lock_screen.dart`, `paywall_screen.dart`, `budget_screen.dart`.

---

## 6. Services (`lib/services/`)
`database_service` (SQLite), `firestore_service` (cloud CRUD + invite codes), `auth_service`, `storage_service` (receipts), `notification_service` + `push_notification_service`, `analytics_service`, `backup_service` (JSON export/restore), `export_service` (PDF/CSV), `security_service` (app lock/biometrics), `iap_service` + `entitlement` (subscriptions), `smart_suggestions_service`, `voice_input_service`.

---

## 7. Firestore Security Rules (`firebase/firestore.rules`)
- `users/{uid}/**` — owner-only.
- `groups/{id}` — create: any auth user; get: any auth user (for invite join); list/delete/update: members (`uid in memberUids`) or `createdBy`; join via `inviteCode` match (adds self to `memberUids`).
- `groups/{id}/expenses` — read/create/update/delete restricted to **group members** (`uid in memberUids`); create requires `addedBy == uid`; edit/delete = expense author or group creator.
- **Implication:** a person can only add a group expense if they **joined as a real account** (their `uid` is in `memberUids`). Members added by free-text name only cannot write.

---

## 8. Build / Run / Deploy

- **Analyze:** `flutter analyze lib/<file>` (run before deploying; keep "No issues found").
- **Run on device:** `flutter run -d <deviceId> --no-dds`
- **Primary test device:** Samsung `RZCY903AV7T` (1080×2340, density 450). ⚠️ Flaky USB — connection often drops *after* install; `flutter run` may report exit 0 but the new APK may not have landed if the cable dropped mid-install. Re-verify / redeploy if a change isn't visible.
- **adb path (Windows):** `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`
- **Screenshot:** `adb shell screencap -p /sdcard/s.png` then `adb pull` (don't use PowerShell `>` redirect — it corrupts the PNG).

---

## 9. Conventions for AI Agents
- **Never hardcode colors** — use `TC.*`. If you see off-brand hex (e.g. `#1DBF73`, `#00D68F`), convert to the nearest `TC` token.
- **Numbers = Gloock**, labels = Geist (see §4).
- Run `flutter analyze` on every file you touch; remove unused elements/imports you create.
- Prefer editing existing widgets over rewriting whole screens.
- Multi-currency: **never sum amounts across different currencies** into one total (goals/wallets can be in different currencies). Show per-currency or counts instead.
- Keep cards shadow-only (no borders) in light mode.

---

## 10. Known Issues / Parked Work
- **Guest group-joining without an account + subscription paywall** — requested as a major feature. Scaffolding exists (`iap_service.dart`, `entitlement.dart`, `paywall_screen.dart`, `join_group_screen.dart`) but the "anyone can join without an account, gated behind a paid subscription" flow is **not finished**. Needs: anonymous/guest auth model (current architecture requires `request.auth != null` everywhere), entitlement gating, and store billing wiring. A planning task was spun off for this.
- **Friend can't add group expense** — root cause is multi-user: (a) their app must have the local-first build, and (b) they must be a real member (`uid in memberUids`), i.e. joined via invite/QR, not added by name. See §7.
- **Settings icons** — use iOS-style multi-colored icon backgrounds (off-brand hex constants at top of `settings_screen.dart`). Left intentionally; flatten to teal only if the owner asks.
- Pre-existing harmless Hero-tag warning in device logs.

---

## 11. Changelog (newest first — ADD AN ENTRY EVERY SESSION)

### 2026-06-12 — Release obfuscation + client-hardening guidance
- **Obfuscated release build script** (`scripts/build_release.ps1`): `flutter build appbundle --release --flavor prod --obfuscate --split-debug-info=debug-symbols/<version>/`. Mangles Dart symbol names (defense-in-depth vs reverse-engineering of app LOGIC; does NOT and cannot hide Firebase API keys — those are public client identifiers, security is rules+Auth+AppCheck). **USE THIS SCRIPT for every Play Store release** instead of the bare build command. R8/Java obfuscation already on (`isMinifyEnabled=true`).
- **Symbol retention**: `debug-symbols/` is now COMMITTED to the repo (~15 MB/release) so crash-decode symbols can never be lost and always match a release — no manual backup needed. (Earlier wording called this keystore-critical; corrected — losing symbols only means one build's obfuscated crashes can't be decoded, not loss of update ability.)
- **App Check verified correct in code** (`main.dart`): Play Integrity (Android release) / DeviceCheck (iOS release), debug providers only in `kDebugMode`. Client attestation is done.
- **Console TODOs the owner must click (free, Spark-compatible, NOT doable via CLI)** — see `docs/CONSOLE_HARDENING.md`: (1) App Check → enforce on Cloud Firestore [HIGHEST VALUE — blocks scripted quota-exhaustion DoS]; (2) restrict the Android API key to the app's package + SHA-256 in Google Cloud console; (3) Auth → enable email enumeration protection + leaked-password protection. These are the real-world max for a client app on the free plan.

### 2026-06-12 — Red-team pass: expense/settlement field hardening
- **Pentest of attacker-as-group-member.** No cross-tenant or escalation holes found (other groups unreachable, `addedBy`/`createdBy` unforgeable, premium claim server-only, names/memberMeta now append/remove-only). Enforceable gaps fixed below; one design property documented.
- **FIXED + DEPLOYED — type-confusion & doc-bloat in expenses/settlements**: `validExpense`/`validSettlement` previously bounded only `amount`/`desc`/`paidBy`/`from`/`to`, leaving `paidById`, `splitIds`, `splits`, `cat`, `subcat`, `fromId`, `toId` unbounded — a member could write a multi-hundred-KB doc (sync/cost abuse on every member) or wrong-typed fields to break other clients' parsers. Now all are type+size bounded via null-tolerant `optStr`/`optMap` helpers (client writes explicit nulls, so `== null` is allowed before the `is string`/`is map` check).
- **Documented design property (NOT fixable in rules, same as Splitwise)**: within a group, a member can record an expense attributing payment to another member, or a settlement between two parties, that isn't "honest". This is inherent to cooperative split apps and is mitigated by: full real-time visibility of every doc, locked `addedBy` (you can't frame someone else as the recorder), amount caps, and author/creator delete+edit. Closing it fully needs a server authority (Cloud Function) → Blaze.

### 2026-06-12 — Backend re-review: member-vandalism rules fix + entitlement hardening
- **Full backend review** (rules, functions, storage, deployed state). Verdict: design solid; findings below.
- **FIXED + DEPLOYED — member vandalism (was the only pre-beta blocker)**: the group-update join path (b) and self-leave path (c) validated `memberUids` but left `members` (display names) and `memberMeta` unconstrained — any member could rewrite everyone's names or wipe `memberMeta` in a join/leave write. Now: joins may only APPEND (names superset +1, `memberMeta.diff().affectedKeys().hasOnly([uid])`), leaves may only REMOVE (names subset — no lower size bound because client `arrayRemove` drops duplicate name entries — same memberMeta diff guard). Owner path (a) intentionally unrestricted. Rules deployed ✓.
- **Verified safe — receipts without Storage**: `storage_service.uploadReceipt` catches all errors → null; the single caller (`app_state.dart` ~1254) keeps the local receipt path when url == null. With no Storage bucket (Spark), receipts stay device-local; nothing breaks.
- **Hardened `applyEntitlement`** (functions, code-only — undeployable until Blaze): custom-claim set failure now ABORTS before the mirror doc/group stamping, so UX can never show premium that rules deny.
- **Concurrent-join race fixed client-side**: the append-only join rule rejects writes built from a stale member snapshot; `joinGroupByInviteCode` now retries (3 attempts, 200ms·n backoff) with freshly resolved state on `permission-denied` instead of reporting a false "invalid code".
- **Accepted risks for beta (documented, fix = Blaze + resolveInvite CF)**: (1) any signed-in user with a leaked groupId can read the group doc INCLUDING `inviteCode` → join capability, since Spark rules allow open single-doc `get`; group IDs are unguessable. (2) Purchase-webhook fallback trusts client-written `purchaseQueue` token→uid mapping (moot — functions undeployed). (3) `inviteCodes`/`purchaseTokens` orphans accumulate (no TTL). (4) `cleanupAnonUsers` not running. (5) App Check console enforcement unverified — check Firebase console → App Check when next there.

### 2026-06-12 — Spark-plan reality check: invite flow made dual-mode
- **Discovery**: project `splitsmart-3898` is on the FREE Spark plan → **Cloud Functions have NEVER deployed** (Blaze required). `firebase functions:list` = empty. This means: no push notifications via CF triggers, no `verifyPurchase`, and the `resolveInvite` CF from earlier today was never live (the rules that depended on it would have broken joining).
- **Fix — dual-mode invite resolution** (`firestore_service.dart` `_resolveInvite`): client tries direct Firestore reads first (Spark rules allow signed-in single-doc `get` on `inviteCodes` + `groups`); on `permission-denied` it falls back to the `resolveInvite` CF. Works on both backend configurations with no client update.
- **Rules reverted to Spark-compatible** and DEPLOYED (✓ live): `groups/{id}` `get` + `inviteCodes/{code}` `get` back to `request.auth != null`, each with a comment stating the exact tightening to apply once on Blaze. All other tightenings (member-only list, creator-only edits, join-update validation, profile-image storage rule) remain in the file; storage rules still undeployed (needs Storage setup → Blaze).
- **⚠️ Blaze upgrade checklist (when owner is ready)**: upgrade plan → `firebase deploy --only functions,firestore:rules,storage:rules` → tighten the two `get` rules per their comments → set billing alerts + App Check enforcement. Until then: no CF-based push notifications, premium/IAP can't verify, guest-join premium gate can't be sold.

### 2026-06-12 — Local data encrypted at rest (SQLCipher) + encrypted backups
- **DB is now SQLCipher-encrypted** (`sqflite` → `sqflite_sqlcipher` in pubspec + the only two importers, `database_service.dart` / `backup_service.dart`). Key = random 64-hex string, generated once and kept in platform secure storage (new `lib/services/db_key_service.dart`, `flutter_secure_storage`: Android Keystore-backed EncryptedSharedPreferences / iOS Keychain `first_unlock`). Android `minSdk` raised to ≥ 23 (`maxOf(flutter.minSdkVersion, 23)`).
- **Legacy-install migration**: `DatabaseService._init` detects a plaintext `splitsmart_v3.db` (header check `isPlaintextDb`) and converts it once in place via `ATTACH … KEY` + `sqlcipher_export` (`encryptPlaintextDb`), preserving `PRAGMA user_version` (critical — export doesn't copy it; without it `openDatabase(version:19)` would rerun `onCreate`). WAL/SHM sidecars cleared after the swap.
- **Backups — 3 DB flavors** (`RestoreResult` enum in `backup_service.dart`):
  - *Local/auto backup* (no passphrase): zips the raw device-keyed DB — encrypted at rest, restorable only on the same device.
  - *Shared backup*: settings Share flow now requires a **user passphrase** (min 6 chars, dialog in `settings_screen.dart`); DB exported via `exportEncryptedCopy` (SQLCipher KDFs the passphrase) → portable across devices.
  - *Restore* stages the DB to a temp file and probes flavor BEFORE touching live data: plaintext-legacy → restored then encrypted in place; device-key → placed as-is; passphrase → UI prompts (`needsPassphrase`) and the snapshot is **rekeyed to the device key** (`rekeyCopy`). Wrong passphrase leaves current data intact.
- Known limitation: receipt images inside backup ZIPs remain unencrypted (the DB is the sensitive payload); zip-level AES not used to avoid weak-ZipCrypto false confidence.
- **App size**: deleted `assets/images/` (3 onboarding PNGs, ~2.9 MB) — dead since the 2026-06-10 icon-based onboarding redesign; removed dir from pubspec assets. Note: the 72.7 MB `.aab` is NOT the user download (~100 MB of it is Play-side proguard map + debug symbols); per-device Play download is ~25-30 MB.
- `flutter analyze` clean; 67/67 tests pass.

### 2026-06-12 — Security-review fixes: store readiness + access tightening
- **iOS Info.plist**: added all 5 usage descriptions (camera, mic, speech, photo library, Face ID) — was an App Store/TestFlight blocker.
- **Backup restore hardening** (`backup_service.dart`): rejects ZIPs > 100 MB, > 1000 entries, > 100 MB per entry, or > 250 MB expanded (`_archiveLooksSafe`) before decode/restore — closes local memory-DoS risk.
- **Group metadata no longer publicly readable**: new `resolveInvite` callable CF (App Check enforced, `firebase/functions/index.js`) resolves invite code → group preview + member arrays. Client `joinGroupByInviteCode`/`probeInviteCode` (`firestore_service.dart`) now call it instead of reading `inviteCodes`/`groups` directly. Rules: `groups/{id}` `get` is member/creator-only; `inviteCodes` `get` is now `false`. ⚠️ **CF must be deployed BEFORE shipping this client build** (`firebase deploy --only functions,firestore:rules`).
- **Storage rules**: `users/{uid}/profile/*` read is owner-only (path unused by app; was any-authenticated).
- **Functions dep audit → 0 vulnerabilities**: firebase-admin ^13, firebase-functions ^7, googleapis ^173, + `overrides: uuid ^11.1.1` (was 11 moderate). `node --check` passes; emulator smoke-test still pending (Java not on PATH).
- **Release signing created**: `android/app/splitsmart-release.jks` (RSA-2048, alias `splitsmart`, random 31-char password) + `android/app/key.properties`. Both git-ignored. ⚠️ Owner MUST back up the keystore + password (e.g. password manager) — losing it means losing the Play Store identity.
- `flutter analyze` clean.

### 2026-06-10 — Premium Overview hero + onboarding tour redesign
- **Overview hero** (`overview_tab.dart`): flat "Total spent" card → **teal gradient hero** (`TC.cardGradient` + primary glow + corner radial sheen, matching the Money tab's Net Position card). Count-up total (`CountUpText`), trend-arrow **delta chip vs previous period** (light coral/mint tints `0xFFFCA5A5`/`0xFF86EFAC` for on-gradient legibility), frosted insight pill, and icon stat chips for Previous / Top Category — **Top Category now renders `iconForEmoji(...)` instead of a raw emoji**. Header filter pills get fills (currency = `primaryPale` + teal border, month/filter = `TC.bg`) and teal icons.
- **Onboarding** (`onboarding_screen.dart`): rebuilt as a **4-page premium tour** on the design system (TC tokens, Gloock headline + Geist body on `TC.bg`; old off-brand green/white discarded). Pages: track money / split bills / budgets & goals / privacy. Layered icon illustrations (color blob + ring + gradient core + 2 floating mini chips — Material icons only), **flutter_animate entrances**: staggered chip pop-in that replays per page (`target:` on `isCurrent`), perpetual chip float, fade/slide-in title + body; elastic hero re-pop per page kept on the manual controller. Brand wordmark + Skip top bar, glowing page dots, gradient CTA with arrow→rocket icon. **Theme-aware status bar** (was hardcoded dark icons on the now theme-aware bg). `onDone` contract + completed/skipped analytics preserved — the `onboarding_done` SharedPreferences flag lives in `_AppGate` (`main.dart`) and is untouched.
- `flutter analyze` clean; 67/67 tests pass.

### 2026-06-03 — Competitive gaps: smart insights, faster entry, CSV import
- **Smart Insight** rewritten to be genuinely useful (priority: overdue bills → month-over-month spend trend → top-category share → onboarding nudge) instead of echoing the donut. (`personal_finance_tab.dart`)
- **Faster Add-Expense**: remembers last-used category per type (expense/income) and pre-selects it. (`add_transaction_screen.dart`)
- **Free CSV import** (Phase 0 of bank plan): new `import_csv_screen.dart` — pick CSV → auto-guess + map Date/Description/Amount columns + currency → preview → bulk import as transactions (sign → income/expense). Entry point in **Settings → Import from CSV**. No DB change; dedupe not yet implemented (future).

### 2026-06-02 — Empty states + two Home bugfixes
- **Bug:** Home recent-transaction rows overflowed (87px) because the date was a raw ISO timestamp — now formatted short ("Jun 1") + flex-safe. Currency badge → brand teal. (`personal_finance_tab.dart`)
- **Bug:** Home donut legend showed the category emoji twice for legacy/unknown categories (e.g. old 🚗 after the Transport icon change) — deduped.
- **Rich empty states** (new `RichEmptyState` + `EmptyPill` in `common_widgets.dart`): art + Gloock title + desc + suggestion pills + teal CTA + ghost button. Applied to **Saving Goals** (Trip/MacBook/House…), **Subscriptions** (Spotify/Netflix…), **Reminders** (Rent/Electricity…), and **Groups** (Create + "Join with Invite Code" → `JoinGroupScreen`). Removed old `_EmptySubsState` + `_AvatarCircleIllustration`.

### 2026-06-02 — Wallet delete fix, Home/Planner tweaks
- **Bug fix:** deleting the active currency wallet left `homeCurrency` pointing at it (deleted account kept showing). `deleteWallet` now deletes local-first (cloud in background) and **switches `homeCurrency`** off the deleted one; Home also self-heals if the saved currency has no wallet. (`app_state.dart`, `personal_finance_tab.dart`)
- Home: removed "Coming Up" section; **Goals stat capped at 100%**; added "See all → Planner" above the 3 stat tiles; Spent tile icon 📊→🧾; donut card got a "See all → transactions".
- Transport category icon 🚗→🚌 (distinct from Vehicle).
- Planner snapshot: "Monthly Subs" money → **active-subscriptions count** (no multi-currency total).
- Plan doc `docs/CATEGORY_HIERARCHY_PLAN.md` (groups→subcategories; owner chose to plan-as-phase; start Phase 1 = budget-form picker only).

### 2026-06-03 — Email verification, App Check, dev/prod flavors
- **Email verification (soft gate):** `signUpWithEmail` now sends a verification email; `AuthService` gained `isEmailPasswordUser`, `isEmailVerified`, `sendEmailVerification()`, `reloadEmailVerified()`. Home shows a dismissible "Verify your email" banner (`_buildEmailVerifyBanner` in `personal_finance_tab.dart`) with Resend / "I've verified" — **not a hard lock** (existing testers keep working).
- **App Check (activated, NOT enforced):** added `firebase_app_check`; `main.dart` calls `FirebaseAppCheck.instance.activate` (debug provider in debug builds, Play Integrity / DeviceCheck in release). Nothing is rejected until enforcement is flipped in the Firebase console + (optionally) `enforceAppCheck: true` on callables — safe for current users. Debug builds print a debug token to register in the console.
- **Dev/prod Firebase split (Android):** `android/app/build.gradle.kts` now defines `prod`/`dev` product flavors (dim `env`); `dev` uses applicationId suffix `.dev` + its own Firebase project. **Builds now REQUIRE a flavor** — use `flutter run --flavor prod -d <device>` (and `--flavor prod` for builds). Prod uses the existing root `google-services.json` (plugin fallback); dev needs `android/app/src/dev/google-services.json` (see that folder's README). `firebase/.firebaserc` gained `prod`/`dev` aliases (dev id is a placeholder).
- **Manual/console follow-ups:** create the `dev` Firebase project + drop in its `google-services.json`; set the dev project id in `.firebaserc`; iOS flavor schemes not set up (Android only); a device build is needed to confirm the gradle flavor config (no Java/emulator here). App Check enforcement is a later console step.

### 2026-06-04 — Backend security audit #2 + rules re-deploy (dev + PROD)
- **Second hardening pass on `firestore.rules` / `storage.rules` / `functions/index.js` / AndroidManifest** (invite-code mapping is owner-only + code-matched; group `update` split into creator-edit / invite-join / self-leave branches so a crafted client can't rewrite unrelated fields or inject another uid; expense/settlement `addedBy` immutable; `users/{uid}` subcollections restricted to an explicit allowlist; `purchaseQueue` shape validated; Storage uploads limited to typed image MIME+ext+size; `usesCleartextTraffic="false"`).
- **Independently verified** the rules against `firestore_service.dart` writes — every field the rules require, the client already sends (`createdBy`, `joinAttemptCode`, `addedBy`, `{groupId}`-only mapping, exact `purchaseQueue` keys); all 6 synced user subcollections are allowlisted. **No core-flow lockout.** Rules **compiled + deployed to dev AND PROD** (`splitsmart-3898`).
- **Storage rules:** could not deploy — Storage not initialized on dev or prod (needs Blaze "Get Started"). No bucket = nothing exposed; rules staged.
- **Dependency audit (Functions):** generated `firebase/functions/package-lock.json`; `npm audit` = **11 moderate, 0 high/critical**, all the same transitive `uuid` advisory (GHSA-w5hq-g745-h8pq) via firebase-admin/functions/googleapis — not exploitable in our usage. Non-breaking `npm audit fix` = no change; `--force` would bump firebase-admin 12→13 / firebase-functions 5→7 / googleapis 144→173 (breaking) — **deferred** to whenever Functions are actually deployed (needs Blaze) so the majors can be tested.
- **Emulator rules-unit tests: RUN + GREEN (22/22).** Used Android Studio's bundled JDK (`…\Android Studio\jbr`, OpenJDK 21) as `JAVA_HOME` to start the Firestore emulator; `cd firebase/test && npm install && npm test`. Fixed a latent harness bug first — `seedGroup`/child-doc `beforeEach` called `ctx.firestore()` twice per context (rules-unit-testing re-applies emulator settings each call → "Firestore already started"); store the instance once and reuse. Attack cases (anon create, invite-code poisoning, guest non-premium join, member injecting another uid, profile-rewrite-on-join, self-leave+rename, owner adding arbitrary uids, premium flag without claim, addedBy rewrite, arbitrary user subcollection) all correctly DENIED; legit ops allowed.
- **Still console-only:** App Check enforcement (toggle after on-device verification).

### 2026-06-04 — Pentest remediation + PROD rules deploy
- **Pentest pass (grey-box).** Verdict: trust model is genuinely server-side (auth + `premium` custom claim + validated rules + server-verified IAP). Fixes: **IAP replay protection** — `verifyPurchase` binds each receipt to one uid via hashed `purchaseTokens/{sha256}` in a transaction (`firebase/functions/index.js`); **settlement tamper fix** — settlement update/delete restricted to `addedBy`/creator (firestore.rules); **PII out of logs** — removed uid/email from auth `debugPrint`s. CSV formula-injection = **N/A** (no CSV export path; export is PDF/zip only).
- **Firestore rules DEPLOYED TO PRODUCTION** (`splitsmart-3898`) — all hardening is live for real users.
- **Known prod gaps (cost-gated, by owner choice):** (1) **Storage not enabled** on prod → receipt uploads fall back to local-only (no bucket = nothing exposed; `storage.rules` ready for when Storage is enabled, needs Blaze). (2) **Cloud Functions staged, not deployed** (need Blaze) → server-side IAP verification + replay protection live only once deployed. (3) **App Check** activated client-side, enforcement = console toggle (do after verifying live app). (4) data-at-rest encryption (SQLCipher) deferred.

### 2026-06-05 — Subcats for group expenses, budget icon/color, premium hidden, planner bento (DB v19)
- **Premium hidden from users.** `AppState.isOwner` (uid allowlist `_ownerUids`) gates the guest-access card on the QR screen; drawer tagline "Premium Edition" → "Track · Split · Settle". Premium ships later (needs Blaze); owner still sees the toggle for testing.
- **Sub-categories on GROUP expenses** (parity with personal): `ExpenseData.subcat` — **DB v18 → v19** (`expenses.subcat`) + Firestore round-trip (insert/update/2 parses) + optional chips in `add_expense_screen` + carried into `allTransactionsWithGroupShares` so group shares roll into sub-budgets.
- **Beauty/personal-care subs** under Shopping: Salon & Hair, Cosmetics, Skincare, Nails, Spa & Massage, Jewelry.
- **Budget icon + color** (wallet-style): `Budget.icon/color` (v19 cols `budgets.icon/color`), Icon+Color pickers in the form (Auto = derive from categories), budget card shows tinted leading icon. Goals + subscriptions already had pickers.
- **New Budget form fix:** global `inputDecorationTheme` (filled + enabledBorder) painted a second box inside the form's field containers → `filled:false` + border overrides on Name/Amount (the "imbalanced" look).
- **Planner redesigned (bento):** removed the dark hero + flat budgets link + stacked reminders list; now 2 bento tiles (Budgets w/ top-budget progress; Reminders w/ next-due + overdue chip), horizontal **goal carousel** with progress rings, and **Upcoming renewals** (subs sorted by next billing, "≈ X/mo" chip, urgency tinting). All navigation preserved; icons-only (`_emptyTile`/add-sheet emojis → icons).

### 2026-06-04 — Budget sub-categories, Phase 1 (DB v18)
- **Sub-categories** (Wallet-style) keyed by parent category emoji: `AppState.subcategories` map + helpers `subsFor`/`subByKey`/`parentOfSub`/`labelForKey`. Sub keys are stable `sub:<group>:<name>` strings (no emoji-collision, storable on tx/budgets).
- **`TransactionData.subcat`** (nullable) — **DB v17 → v18** additive `transactions.subcat` + Firestore round-trip. Add/Edit transaction shows optional sub-category chips for expense categories that have subs.
- **Budget category picker is now expandable** (`new_budget_screen.dart`): parent checkbox = whole category; expand → per-sub checkboxes. `budgetSpent` + budget detail chart match a tx by **parent emoji OR sub key**. Budget card/picker render icons (not emoji), incl. `sub:` keys via `iconForEmoji`/`colorForEmoji`.
- **UX fix:** Budgets empty state no longer shows two "New Budget" buttons — the FAB is hidden while the list is empty (the centered CTA covers it).
- Tests: `test/widget_test.dart` group `budgetSpent subcategories` (5 cases). **DB version is now 18** (update §2 if it changes). See `docs/CATEGORY_HIERARCHY_PLAN.md` (Phases 2–3 pending).

### 2026-06-04 — Icons-only UI + account-only/creator-only groups (DB v17)
- **Emoji → Material icons everywhere.** New `lib/utils/icon_map.dart` (`iconForEmoji()` + `colorForEmoji()`) maps every stored emoji (categories, group/goal/subscription icons, decorative glyphs, `←`) to a Material icon. **Emoji stays the storage key** — no data migration; old records render as icons automatically. Shared widgets (`EmojiBox`, `EmptyState`, `RichEmptyState` art + `EmptyPill`) + all category/transaction render sites + pickers + decorative emojis converted across ~25 screens. Currency **flags kept** (distinct identifiers). Category icons tint via each category's palette color.
- **Account-only group members.** Group creation no longer accepts typed names — you create solo and others join via invite code (real accounts). `new_group_screen` builds a creator-only roster.
- **Creator-only group management.** New `GroupData.createdBy` (**DB v16 → v17**, additive `groups.created_by`; parsed from Firestore). `isCreatedBy()` helper (legacy fallback = first member). Group Settings: creator can rename/change icon/remove members/delete; non-creators get a **read-only** view + **Leave group**. New `AppState.leaveGroup` + `removeMember` (local-first) + `FirestoreService.removeMemberFromGroup`.
- **Rules:** group edits + delete are now **creator-only**; added a precise **self-leave** path (a member may remove only their own uid); invite-join unchanged. Deployed to **dev** (compiled OK); push to prod with `--project prod` when ready.
- **Crash fix:** reverted the premature `.then((_) => ctrl.dispose())` on 5 dialogs/sheets (it disposed `TextEditingController`s mid-close-animation → "used after disposed"). Controllers are intentionally not disposed there (tiny bounded leak); proper fix = StatefulWidget-owned controllers later.
- **DB version is now 17** (update §2 if it changes).

### 2026-06-03 — Stable member-id keyed balances (DB v16) + security hardening
- **Duplicate-name balance corruption fixed.** New `GroupMember {id,name,uid?,isGuest}` + `GroupData.roster`; `ExpenseData.paidById/splitIds`; `SettlementData.fromId/toId`. New **`getBalancesById()`** keys balances by stable id (Firebase uid for app users, generated `local:` id for typed members); `getAllBalances()` is now a name-projection of it (back-compat). `getMyBalance`/`buildSettlePlan` work in id-space. Legacy name-only rows resolve via the roster when unambiguous, else fall back to `name:<name>` — **no data rewrite**.
- **DB schema 15 → 16** (additive/nullable): `group_members.member_id/uid/is_guest`, `expenses.paid_by_id/split_ids_json`, `settlements.from_id/to_id`. Round-tripped in `database_service.dart` + `firestore_service.dart` (unified `memberMeta: {memberId:{name,uid?,isGuest}}`; roster only trusted when it covers all member names). UI: `new_group_screen` builds the roster; `add_expense_screen` derives ids at save; `settle_up_screen` passes `fromId/toId`. 5 new unit tests (duplicate-name regression, legacy fallback, mixed merge, settlement-by-id, custom id splits). **DB version is now 16** (update §2 if it changes).
- **Security (audit fixes):** Apple App Store JWS now cryptographically verified (x5c chain → pinned Apple Root CA G3 + ES256) instead of `jwt.decode()`; Firestore rules tightened (immutable `createdBy`/`inviteCode`, group-create validation, expense/settlement amount+field validation, fcmTokens cap, support-ticket schema); `ANDROID_PACKAGE` default fixed; Functions Node 18 → 20; release build now fails without a keystore (no silent debug-signing); corrected "encrypted storage/backups" copy.
- **Known follow-ups:** add-expense *picker* is still name-keyed (can't assign an expense to a *specific* same-named member yet — engine/storage already support it); breakdown-tab per-member cards still group by display name. Deploy `firebase deploy --only firestore:rules` (rules not emulator-compiled here — no Java). DB-migration + multi-user cloud paths need device testing.

### 2026-06-02 — Budgets Phase B (detail + forecast trend chart)
- New `budget_detail_screen.dart`: period summary (limit, % used, progress, Spent/Remains) + **forecast trend chart** via `fl_chart` (green actual cumulative spend, blue dashed forecast, red overspend segment past the limit-crossing day, gray dashed limit line) + "You risk overspending" warning + legend.
- Budget card tap now opens the **detail** (edit moved to the pencil in the detail header). `budget_screen.dart`.

### 2026-06-02 — Wallet-style Budgets, Phase A (DB v15)
- **DB schema bumped 14 → 15**: new `budgets` table (CREATE + v15 migration in `database_service.dart`) + CRUD. **DB version is now 15** (update §2 if it changes).
- New **`Budget` model** (`app_state.dart`): id, name, period (weekly/monthly/yearly), amount, currency, categories (emoji list; empty = all), notifyOverspent. **Local SQLite only** (not cloud-synced yet — Phase C). AppState: `budgets`, load, `addBudget`/`updateBudget`/`deleteBudget`, `budgetSpent(b)`.
- **Budgets list** rewritten (`budget_screen.dart`): named budgets with spent/limit, % badge, progress bar, remaining/over text, swipe-to-delete, tap-to-edit, FAB → new budget, empty state. Reached via Planner → Budgets.
- **New/Edit Budget form** (`new_budget_screen.dart`): name, period chips, amount + currency picker, **category multi-select sheet** (All or specific from `expenseCategories`), notify-overspent toggle.
- Plan doc: `docs/BUDGET_REDESIGN_PLAN.md` (Phase B = detail + forecast trend chart; Phase C = one-time/labels/notifications/cloud sync — NOT built yet).

### 2026-06-02 — Home monthly-spending donut
- Added a **donut chart of this month's expenses by category** on Home, right after the 3 stat tiles (`personal_finance_tab.dart`: `_buildMonthlyDonut`, `_HomeDonutPainter`). Scoped to the active/home currency; hidden when there's no spend. Center shows total (Gloock); legend shows top categories + %/amount. Uses `AppState.getCategoryColor`.

### 2026-06-02 — Goal icon + colour picker (DB v14)
- **DB schema bumped 13 → 14**: added `icon` + `color` (TEXT) columns to `saving_goals` (CREATE + v14 ALTER migration in `database_service.dart`). Firestore is schemaless so `toMap()` carries them automatically.
- `SavingGoal` model gains `icon`/`color` (nullable); `fromMap`/`toMap`/`copyWith` + `addSavingGoal`/`updateSavingGoal` updated (`app_state.dart`).
- Add/Edit goal sheet now has an **Icon picker** (emoji choices) + **Colour picker** (swatches); goal cards render the chosen icon/colour, falling back to auto when null (`saving_goals_screen.dart`).
- NOTE: DB version is now **14** — update §2 if it changes again.
- TODO (next): Home monthly-expenses donut.

### 2026-06-02 — Splash, Subscriptions, Budget access
- Splash logo: removed the 💚 heart → wallet icon (`main.dart`).
- Subscriptions: removed the monthly-cost hero entirely (multi-currency) — screen now starts with the category breakdown + list (`subscriptions_screen.dart`).
- **Budget screen is now reachable** — added a "Budgets" tile on the Planner that opens `BudgetScreen` (it existed but was never linked) (`planner_screen.dart`).
- TODO (next, careful): goal add/edit **icon + colour picker** (needs DB migration to add `icon`/`color` to `SavingGoal`); Home **monthly-expenses donut** below the 3 stat tiles.

### 2026-06-02 — Onboarding currency + multi-currency cleanups
- **First-run base currency step:** new `base_currency_screen.dart` — after sign-in, if the user has no wallet, they pick their main/home currency (creates the first wallet + sets `homeCurrency`). Wired into `main.dart` `_AppGate` (gated on `wallets.isEmpty`). Mentions banks can be connected later.
- **Subscriptions:** removed the false combined "Total Monthly / Per Year / Per Day" (subs can be multi-currency) — hero now shows monthly cost **per currency** + an Active count pill. `subscriptions_screen.dart`.
- **Saving Goals:** slimmed the goal progress bar (was a chunky 28px filled pill → now an 8px `LinearProgressIndicator` with the % beside it in the goal's color). `saving_goals_screen.dart`.
- Budget screen reviewed — already on TC design system, no change needed.

### 2026-06-02 — Planning docs
- Added `docs/BANK_SYNC_PLAN.md` — cost-first phased plan for "Connect bank account" (Phase 0 free: CSV import + Android SMS parsing; Phase 1: GoCardless/Nordigen free-tier behind the paywall; Phase 2: paid scale / Plaid). No spend until the app is proven.
- (Existing) `docs/PREMIUM_GUEST_PLAN.md` — subscription/paywall + guest-join plan.

### 2026-06-02 — UI/UX overhaul + critical fixes
- **Fixed "Add Expense/Income save does nothing"** (both personal & group): switched `addTransaction()` / `addExpenseToGroup()` to **local-first** — await SQLite, update state, pop immediately; Firestore sync runs in background (was hanging on offline-await). `app_state.dart`.
- **Expanding context-aware FAB** in `main_navigation_screen.dart` (rotates to red ✕, per-tab actions).
- **Home Net Position card** — made **collapsible** (chevron); de-duplicated subtitle. `personal_finance_tab.dart`.
- **Saving Goals** — removed combined multi-currency "Total Saved" hero; card redesigned to wallet-style (centered colored icon, target date, progress bar with **% inside the fill** + per-goal color, Saved/Goal row); tap → detail; removed "Open-ended" insight box. `saving_goals_screen.dart`.
- **Planner** — snapshot shows only Active Goals/Monthly Subs/Overdue (removed multi-currency money total). `planner_screen.dart`.
- **Activity screen** — Revolut-style: persistent search bar + teal filter button; scope (All/Personal/Groups/Settled) + category moved into a **filter sheet**; removed Spent/Income/Net summary banner; scope tabs removed from screen. `activity_screen.dart`.
- **Group Detail** — "Scan" pill relabeled to **Search**; removed **Balances** tab (+ `GroupMembersTab` usage) and the Balances/Receipt quick tiles; expense rows show just the payer (removed raw `Edited by <uid>` and "· Custom"); delete-group shows locked reason when not creator / not settled. `group_detail_screen.dart`, `group_expenses_tab.dart`.
- **Settle Up tab** rebuilt onto TC tokens (was hardcoded `#1DBF73` green); Gloock amounts; dark-mode aware. **Breakdown tab** — swapped 23 off-brand color literals to teal/coral. `group_tabs/`.
- **QR share screen** redesigned — removed group hero card, fake "Verified" badge, "How to join" steps; eyebrow+Gloock header; shadow-only QR panel; tap-to-copy code; teal (was bright green). `qr_share_screen.dart`.
- **Delete a currency wallet/account** added to Home "Your Accounts" sheet (with confirmation; auto-switches active). `personal_finance_tab.dart` + `deleteWallet()`.
- **Icons** — Food 🍔→🍽️, Road Trip 🚗→🚐 (`new_group_screen.dart`); subscription empty-state 🔄→💳; removed Overview "analysis only" banner; removed archived 📦.
- Staggered fade-up entrance animations on Home sections.

### (Earlier work — pre-2026-06-02)
- Built core design system (`TC`), restyled Saving Goals/Subscriptions/Reminders/Planner to match the PDF, Money/Overview/Groups/Settings headers, typography pass (Gloock numbers / Geist labels).
