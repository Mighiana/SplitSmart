# SplitSmart — Bank Sync ("Connect Bank Account") Plan

> **Status:** PLAN ONLY — not implemented. No spending required to start.
> **Guiding principle:** spend **€0** until the app has real, paying users. Build value first, add cost-bearing features only when revenue justifies them.
> _Created: 2026-06-02_

---

## 1. Goal

Let users **connect their bank account** so transactions import & categorize automatically (like Revolut / Emma / Mint), instead of manual entry — **without paying aggregator fees until the app is proven**.

---

## 2. The cost reality (why we phase it)

You **cannot** connect to banks yourself — you must use a licensed **aggregator** (Open Banking provider). They charge per connected account / per call. This is a **recurring per-user cost**, so it must be gated and only switched on when it pays for itself.

| Provider | Region | Free tier? | Paid pricing (approx) |
|---|---|---|---|
| **GoCardless Bank Account Data** (ex-Nordigen) | **Europe (incl. Hungary/EUR/HUF)** | ✅ **Genuinely free** for limited volume | then per-connection |
| Plaid | US/CA/UK/EU | Sandbox free; tiny free prod allowance | ~$0.30–0.60 / item / mo |
| TrueLayer / Tink | Europe | Sandbox free | enterprise pricing |
| Salt Edge | Global (5000+ banks) | Sandbox/trial | per-connection |

**Recommendation for you:** **GoCardless Bank Account Data (Nordigen)** — you're in **Europe** (EUR/HUF), it's **Open Banking/PSD2**, and it has a **real free tier**. This lets you ship bank-sync to early users at **zero cost**, and only move to paid once you outgrow the free limits (i.e., once you have traction).

---

## 3. Phased roadmap (cost increases only as success grows)

### Phase 0 — €0, do this NOW (no bank connection at all)
Squeeze maximum "auto" feeling out of free features before paying anyone:
- **Smart manual entry** — you already have `smart_suggestions_service.dart` + `voice_input_service.dart`. Lean into these: voice ("spent 12 euro on coffee"), recent-merchant suggestions, auto-category from description keywords.
- **SMS / notification parsing (Android only, free):** many banks send transaction SMS/push. With user permission, parse them into draft transactions. (Android allows SMS read with consent; iOS does not — Android-only feature.)
- **Receipt scan** (already have image attach) → optional OCR later.
- **CSV import** — let users export their bank statement (CSV/Excel) and import it. **Zero cost, no API, works with any bank worldwide.** This is the single best "free bank sync" — build this first.

> **Phase 0 gives ~70% of the value of bank-sync for €0.** Ship CSV import + SMS parsing first.

### Phase 1 — Free-tier real bank sync (still ~€0, only when you have engaged users)
- Integrate **GoCardless Bank Account Data (Nordigen)** on its **free tier**.
- Limit to a small number of beta users (the free tier caps volume).
- Gate it behind the **existing paywall** (`paywall_screen.dart` / `entitlement.dart` / `iap_service.dart`) as a **"Premium" feature** — even if free to you now, charging users from day one (a) filters for serious users and (b) covers future per-connection cost.
- Measure: how many users actually connect, retention lift, conversion to paid.

### Phase 2 — Paid scale (only after revenue proves it)
- When you exceed the free tier OR want wider coverage (US via Plaid), move to paid pricing.
- By now subscription revenue should cover per-connection fees. Rule of thumb: **subscription price must be ≥ 3× the per-user aggregator cost** to be sustainable.

---

## 4. Architecture (when you build Phase 1)

**Never** call the aggregator from the Flutter app directly (tokens would be exposed). Use your **existing Firebase Cloud Functions** (`firebase/functions/`) as the secure middle layer.

```
Flutter app ──HTTPS──> Cloud Function ──> GoCardless API ──> User's Bank
   (UI only)            (holds secrets,      (Open Banking)
                         tokens, sync)
```

**Connect flow:**
1. App calls Cloud Function `createBankLink(bankId)` → returns a **redirect URL** (the bank's consent page).
2. App opens it via `url_launcher` / in-app browser. User logs in **on the bank's site** and consents.
3. Bank redirects back (deep link) → app calls `finalizeBankLink(reference)`.
4. Cloud Function exchanges the reference for an **access token**, stores it **encrypted in Firestore** (`users/{uid}/bankConnections/{id}`), never sent to the client.
5. Cloud Function fetches accounts + transactions, writes them to Firestore.
6. **Scheduled Cloud Function** (cron, e.g. every 12h) refreshes transactions; client just reads.

**Token & consent handling:**
- Store only tokens, never bank credentials.
- Open Banking consent expires (~90 days) → schedule a re-consent reminder.
- Read-only scope (cannot move money — that needs a separate PISP license; out of scope).

---

## 5. Data model changes
- New: `BankConnection { id, bankName, status, consentExpiresAt, accountIds }` (Firestore subcollection, server-managed).
- Reuse existing `TransactionData` for imported transactions — add fields: `source` ('manual' | 'csv' | 'bank'), `externalId` (for dedupe), `merchantRaw`.
- **Dedupe** on `externalId` so re-syncs don't duplicate.
- **Auto-categorize:** map merchant name → category (start with a keyword table; reuse `smart_suggestions_service`).
- Multi-currency: imported transactions carry the account's currency → fits your existing per-currency wallet model.

---

## 6. Security / compliance checklist (Phase 1+)
- All aggregator calls server-side (Cloud Functions); secrets in Functions config, never in the app or repo.
- Encrypt stored tokens; restrict Firestore rules so only the owning `uid` (and Functions) can read `bankConnections`.
- Privacy policy + clear consent screen ("we read transactions read-only via [provider]").
- You ride on the aggregator's AISP license (don't need your own) — confirm their terms.
- GDPR: let users disconnect & delete imported data.

---

## 7. Effort estimate (rough)
| Phase | Work | Cost |
|---|---|---|
| Phase 0: CSV import | 2–3 days | €0 |
| Phase 0: SMS parsing (Android) | 3–5 days | €0 |
| Phase 1: GoCardless integration (Functions + connect UI + sync + dedupe + categorize) | 1.5–3 weeks | €0 on free tier |
| Phase 2: scale / Plaid (US) | +1–2 weeks | per-connection fees |

---

## 8. Recommendation (TL;DR)
1. **Now (free):** build **CSV import** + (Android) **SMS parsing** + lean on voice/suggestions. Ship the "auto" feeling at €0.
2. **When you have engaged users (still free):** add **GoCardless (Nordigen) free-tier** bank sync, gated behind the **existing paywall**.
3. **When revenue proves it:** scale to paid tiers / add Plaid for the US.

This way you never pay for bank infrastructure before the app shows it can succeed — and the feature is wired to **earn** (premium) from the moment it ships.

---

### Related docs
- `docs/PREMIUM_GUEST_PLAN.md` — subscription/paywall + guest joining (the paywall this feature gates behind).
- `PROJECT.md` — overall project context.
