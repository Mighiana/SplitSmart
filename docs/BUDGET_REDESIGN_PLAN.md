# SplitSmart — Budget Redesign Plan (Wallet-style)

> **Status:** PLAN — not built yet. Goal: match the "Wallet by BudgetBakers" budget UX the owner referenced.
> _Created: 2026-06-02_

## Reference (what the owner wants)
1. **Budgets list** — tabs **Periodic** / **One time**; each budget shows `spent / limit` + progress bar; `+` FAB to add.
2. **New Budget form** — Name · Period (None/Weekly/Monthly/…) · Amount + Currency · Categories (All or pick) · Account (All or pick) · Labels · Notifications (overspent toggle).
3. **Category multi-select** — category tree with "All" + groups (Food & Drinks, Shopping, Housing, Transportation, Vehicle → sub-categories, etc.) with checkboxes.
4. **Budget detail (Overview)** — period (e.g. JUNE 2026), limit (editable), % used, progress bar, **Spent / Remains**, and a **Trend chart**: actual spend (green) + forecast (blue) + forecast-overspend (red) vs a dashed Limit line, with a "You risk overspending" warning. Month navigator.

## Current state in SplitSmart
- Budgets = `budgetLimits`: a simple `category-emoji → limit` map per currency ("all" = whole-currency limit). `getBudgetLimit('all', code)` / `setBudgetLimit`.
- `budget_screen.dart` renders per-currency cards with a progress bar (weekly/monthly toggle). Now reachable via Planner → Budgets.
- No named budgets, no per-budget category/account scoping, no detail screen, no trend/forecast.

## Target data model (new)
`Budget { id, name, period ('none'|'weekly'|'monthly'|'yearly'), amount, currency, categories (List<String emoji> | empty=all), accounts (List<String currency> | empty=all), notifyOverspent (bool), createdAt }`
- New SQLite table `budgets` (+ DB **v15** migration) and Firestore `users/{uid}/budgets`.
- Spent calc = sum of `allTransactionsWithGroupShares` matching currency + category filter + period window.

## Screens to build
1. `budget_screen.dart` → **Budgets list** (Periodic/One-time tabs, progress rows, + FAB). Reuse TC design (teal, Gloock numbers, shadow-only cards) — NOT the reference's generic Material green.
2. `new_budget_screen.dart` → **create/edit form** (name, period, amount+currency, categories, notify toggle). Account scoping optional (SplitSmart uses currency wallets, so "Account" ≈ currency — may fold into Currency).
3. `budget_detail_screen.dart` → **overview** (limit, %, spent/remains, **trend chart via `fl_chart`** with spent + linear forecast + overspend segment + limit line + warning), month navigator.
4. `select_categories_screen.dart` (or a bottom sheet) → **category multi-select** from `AppState.expenseCategories` (SplitSmart has a flat category list, not the deep tree — use the flat list with "All").

## Phasing (recommended)
- **Phase A (core, ~1–1.5 days):** Budget model + DB v15 + Budgets list + New Budget form (name, period, amount, currency, category multi-select) + spent/limit progress. Wire into Planner. *Delivers 80% of the value.*
- **Phase B (~0.5–1 day):** Budget detail with the **forecast trend chart** (`fl_chart` LineChart: spent-to-date, linear forecast to period end, red overspend segment, dashed limit, warning banner) + month navigator.
- **Phase C (polish):** one-time budgets, labels, notification wiring (overspent push via existing `notification_service`).

## Design rules (keep it SplitSmart, not generic)
- Teal/cream palette (`TC`), **Gloock** for all amounts, **Geist** labels, shadow-only cards, eyebrow+Gloock headers.
- Multi-currency: a budget is **single-currency** (its own currency) — never sum across currencies.

## Notes / risks
- DB migration v14 → **v15** (additive ALTER/CREATE — safe).
- `fl_chart` is already a dependency.
- Keep the existing simple `budgetLimits` working or migrate them into the new model (a one-off: each `all` limit → a "Monthly budget" in that currency).
