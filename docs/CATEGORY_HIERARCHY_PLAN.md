# SplitSmart — Category Hierarchy (Subcategories) Plan

> **Status:** PHASE 1 BUILT (2026-06-04). Fixed default sub-category tree + expandable picker in the budget form + optional sub-category tag on personal transactions, wired through spend roll-up. Phases 2–3 (adopt the tree in Activity/donuts, migrate existing tx, user-editable groups) still pending.
> _Created: 2026-06-02_

## Phase 1 — what shipped
- `AppState.subcategories`: fixed map keyed by parent category emoji → `List<CategoryItem>` whose `icon` is a stable `sub:<group>:<name>` key (never collides with top-level emojis). Helpers: `subsFor`, `subByKey`, `parentOfSub`, `labelForKey`.
- `TransactionData.subcat` (nullable) — DB **v18** additive column (`transactions.subcat`) + Firestore round-trip (`subcat` field). Old rows/docs read back as null.
- **Add/Edit transaction:** optional sub-category chips appear under the category row for expense categories that have subs; reset when the parent category changes.
- **Budget category picker:** expandable — tap a parent to expand its subs; the parent checkbox targets the whole category, sub checkboxes target specific subs. `budgetSpent` (and the budget detail chart) match a tx if the budget contains its **parent emoji** OR its **sub key**.
- Icons-only: `iconForEmoji`/`colorForEmoji` resolve `sub:` keys; budget card + picker chip render icons, not emoji glyphs.
- Regression tests in `test/widget_test.dart` → group `budgetSpent subcategories` (parent roll-up, sub-only match, currency/income exclusion, no double counting, helper resolution).

## Why it's a big change
Categories today are a **flat list** (`AppState.expenseCategories` = emoji + label + color). They're used by: add expense/transaction, Activity filters, Overview donut, Home donut, budgets, smart insights. Introducing a 2-level tree touches all of these. Do it as a dedicated phase, not a quick patch.

## Target model
```
CategoryGroup { id, label, emoji, color, List<CategorySub> subs }
CategorySub   { id, label, emoji, color, groupId }
```
- Transactions store a **sub-category id** (or keep the emoji but make it unique per sub). Migration: map existing flat emojis → a matching sub (or a "General – <group>").
- Keep a stable id so renaming a label doesn't lose history.

## Reference set (from Wallet app)
Food & Drinks · Shopping · Housing · Transportation · Vehicle (General / Fuel / Leasing / Parking / Rentals / Insurance / Maintenance) · Life & Entertainment · Communication & PC · Financial expenses · Investments · Income. Each group has an icon + colour; subs inherit the group colour.

## Work breakdown
1. **Data:** new category tables (`category_groups`, `category_subs`) + DB migration (vNext), or a versioned bundled JSON of defaults. Decide: fixed defaults vs user-editable. (Phase 1 = fixed defaults; Phase 2 = user-editable.)
2. **Model + AppState:** load tree, helpers `groupOf(subId)`, `colorOf`, `labelOf`, flat-list compatibility shim so existing screens keep working during migration.
3. **Tx migration:** map old `cat` emoji → sub id; keep a fallback.
4. **Pickers:** new expandable category picker (group header → expand → subs with checkboxes), used by add-expense, budget form, Activity filter.
5. **Aggregation:** Overview/Home donuts + budgets can roll up by **group** or **sub** (toggle). Budgets can target a group (= all its subs) or specific subs.
6. **Backfill UI** everywhere that shows a category icon/label to use the tree.

## Phasing
- **Phase 1:** fixed default tree (bundled) + expandable picker in the **budget form** only (smallest blast radius) + budget spent rollup by selected subs/groups.
- **Phase 2:** adopt the tree in add-expense + Activity + donuts; migrate existing tx.
- **Phase 3:** user-editable groups/subs.

## Risks
- Migrating existing transactions' categories (don't lose data — keep old emoji as fallback).
- Many screens read the flat list — provide a compatibility shim so nothing breaks mid-migration.
- DB migration must be additive + reversible-safe.

## Note
The owner chose "Plan it as a phase." Implement when ready; start with **Phase 1** (budget-form-only) to limit risk.
