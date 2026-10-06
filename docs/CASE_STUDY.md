# Case study — SplitSmart

**PROJECT NAME**
SplitSmart (published app name: Splitzee)

**TYPE**
Mobile / Personal Finance / Shared Expenses — Flutter app, Android beta

**PROBLEM**
People track shared costs (trips, flatshares, dinners) in one app and their own spending in another. Most
bill-splitting apps need every participant to sign up and a network connection to record anything.

**WHAT I BUILT**
A cross-platform Flutter app (tested on Android) that combines group expense splitting with personal budgeting.
It works offline without an account, using an encrypted local database; signing in adds Firebase sync so groups
can be shared. Friends can join a group from a QR code or invite code as an anonymous guest.

**KEY FEATURES**
- Groups with Equal / % / Shares / Custom splits, per-member balances and a minimal settle-up plan
- Guest join via QR / invite code using Firebase anonymous auth, with upgrade to a full account
- Wallets in multiple currencies (never summed across currencies), transactions, CSV import, PDF reports
- Monthly category budgets, saving goals, subscriptions and reminders with local notifications
- Voice expense entry (English) and local pattern-based category suggestions
- SQLCipher-encrypted database, biometric app lock, encrypted backup / restore; 8 UI languages

**ARCHITECTURE**
Local-first. Flutter UI → a single Provider `ChangeNotifier` (`AppState`) → encrypted SQLite (SQLCipher, key in
Android Keystore / iOS Keychain) as the source of truth. For signed-in users, every write is mirrored to Cloud
Firestore in the background. An `AccountTier` (local / guest / full) decides whether cloud sync is on and whether
local history is migrated. Firestore security rules enforce ownership and group membership. Cloud Functions source
exists but is not deployed. Diagram: `docs/architecture.svg`.

**TECH STACK**
Flutter, Dart, Provider, sqflite_sqlcipher, flutter_secure_storage, Firebase (Auth, Firestore, Messaging, Analytics,
Crashlytics, App Check), Firestore security rules, Node.js Cloud Functions (undeployed), fl_chart, speech_to_text,
local_auth, flutter_local_notifications, flutter_test.

**TECHNICAL CHALLENGES**
- Firestore writes awaited while offline could stall screens → switched to SQLite-first writes with background sync.
- Balances keyed by display name merged two members with the same name → balance engine re-keyed by member ID, with tests.
- A rules review found members could rewrite other members' names via the join/leave path → rules restricted to append-only joins and remove-only leaves.
- Migrating existing plaintext databases to SQLCipher, and restoring three backup formats without risking live data.
- Staying on Firebase's free plan meant push triggers, purchase verification and receipt cloud storage had to degrade gracefully.

**TECHNICAL DECISIONS**
- Local-first persistence so the app is fully usable offline and without an account.
- Device-generated encryption key held in platform secure storage, never in code or preferences.
- Anonymous-auth guest tier to lower the barrier to joining a group, without uploading guests' personal data.
- Security enforced in Firestore rules rather than trusting the client; Firebase client config treated as public.
- Separate dev / prod Android flavors and Firebase projects.

**RESULT / CURRENT STATUS**
Android beta on Google Play internal testing (invite-only); not publicly released. Core group, balance, budgeting and
planning features are implemented; Firestore rules are deployed. Push notifications, server-side purchase verification
and receipt cloud storage are coded but not live (they need Firebase's paid plan). iOS is not configured. 73 automated
Flutter tests pass and a debug APK builds (`flutter build apk --debug --flavor prod`).

**GITHUB URL**
https://github.com/Mighiana/SplitSmart

**DEMO / RELEASE URL**
No public release or demo URL. (Play internal testing is invite-only.)
Privacy policy: https://mighiana.github.io/splitsmart-privacy/privacy_policy.html

---

## Showcase assets

| # | Screen | File | Why |
|---|---|---|---|
| 1 | Home / monthly spending | `screenshots/final/ss1_home.png` | Combined personal + shared overview |
| 2 | Group detail | `screenshots/final/ss3_group_detail.png` | Group total, you paid / you owe, Expenses / Breakdown / Settle Up tabs |
| 3 | Add expense | `screenshots/final/ss4_add_expense.png` | Keypad entry, voice entry, quick suggestions |
| 4 | Overview | `screenshots/final/ss5_overview.png` | Spending analysis per currency |
| 5 | Planner | `screenshots/final/ss6_planner.png` | Budgets, reminders, goals, subscriptions in one place |
| 6 | Saving goals | `screenshots/final/ss7_goals.png` | Goal progress tracking |

Composite of all six: `docs/showcase.png`. Light-mode versions: `screenshots/final/*_light.png`.

### Screenshots to capture

These would strengthen the case study but are not in the repo yet. Capture on a phone (1080 × 2340) with the
prod beta build, using demo data — not real names:

- **Settle Up tab** — group detail → *Settle Up*, with 3–4 members and a plan of 2–3 transfers.
- **QR invite** — group → share → QR code screen (`qr_share_screen.dart`).
- **Budgets** — Planner → Budgets, with one category over its limit.

Save them to `screenshots/final/` as `ss9_settle_up.png`, `ss10_qr_invite.png`, `ss11_budgets.png`.
