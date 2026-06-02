# SplitSmart — Project Handoff & Context

> **Purpose of this file:** a complete, self-contained brief so **any AI model or developer** can understand the project and continue work without prior context.
> **RULE: Keep this file updated.** After *every* meaningful change, update the relevant section and add an entry to the **Changelog** at the bottom (newest first). Treat this as the single source of truth.

_Last updated: 2026-06-02_

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
| Local DB (offline source of truth) | **SQLite** via `sqflite` — file `splitsmart_v3.db`, **schema version 13** |
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
