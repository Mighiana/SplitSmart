# Play Console — Data Safety form answers

Copy these into **Play Console → App content → Data safety**. Based on the
actual app behavior (Firebase Auth + Firestore + Analytics + Crashlytics;
local SQLCipher DB; no ads; no data sale).

> Golden rule Google checks: your answers here must MATCH your privacy policy
> (https://mighiana.github.io/splitsmart-privacy/privacy_policy.html). They do.

---

## Section 1: Data collection & security (overview)

- **Does your app collect or share any of the required user data types?** → **YES**
- **Is all of the user data collected by your app encrypted in transit?** → **YES**
  (Firebase uses HTTPS/TLS; Android cleartext disabled.)
- **Do you provide a way for users to request that their data is deleted?** → **YES**
  (In-app "Reset All Data" + email request to usmanmighiana3898@gmail.com. Provide
  that email as the deletion-request URL/contact.)

---

## Section 2: Data types collected

For EACH type below, the answers to the three sub-questions are usually:
- Collected? **Yes**
- Shared with third parties? **No** (Firebase is your processor, not a
  third-party recipient — Google's own forms treat this as "not shared")
- Processing: **Collected** (not just ephemeral) unless noted
- Required or optional: as noted
- Purposes: as noted

### Personal info
| Data type | Collected | Purpose | Optional? |
|---|---|---|---|
| **Name** | Yes | App functionality (identify you in groups) | Required |
| **Email address** | Yes | App functionality, Account management | Required (not for guest/anon) |
| **User IDs** | Yes | App functionality (Firebase UID keys your data) | Required |

### Photos (only if a user attaches receipts)
| Data type | Collected | Purpose | Optional? |
|---|---|---|---|
| **Photos** | Yes | App functionality (receipt images) | Optional |

> Note: receipt OCR is on-device (ML Kit); images upload to Firebase Storage
> only if/when that feature is enabled. Currently Storage is not provisioned
> (Spark plan) — if you ship with receipt upload OFF, you may omit Photos. If
> the UI lets users attach receipts at all, declare it to be safe.

### Financial info
| Data type | Collected | Purpose | Optional? |
|---|---|---|---|
| **Purchase history** | Only if IAP is live | App functionality | Optional |
| **Other financial info** (the amounts/expenses users type) | Yes | App functionality | Required |

> "Other financial info" = the expense/budget/transaction amounts users enter.
> Stored encrypted locally and in Firestore; used only to run the app. Not sold.

### App activity / analytics
| Data type | Collected | Purpose | Optional? |
|---|---|---|---|
| **App interactions** (feature-usage events) | Yes | Analytics | Required |

> Feature usage only (group_created, expense_added, etc.). NO amounts, names,
> or descriptions in analytics.

### App info & performance
| Data type | Collected | Purpose | Optional? |
|---|---|---|---|
| **Crash logs** | Yes | Analytics / app stability (Crashlytics) | Required |
| **Diagnostics** | Yes | Analytics / app stability | Required |

### Device or other IDs
| Data type | Collected | Purpose | Optional? |
|---|---|---|---|
| **Device or other IDs** (FCM token, App Check) | Yes | App functionality (push notifications), Analytics | Required |

---

## Section 3: For each type — encryption & deletion (applies to all above)
- Encrypted in transit: **Yes**
- Can users request deletion: **Yes**

---

## Things to answer NO / exclude
- **Location** (precise or approximate): No
- **Contacts**: No
- **Calendar**: No
- **Messages (SMS/email content)**: No
- **Web browsing history**: No
- **Health/fitness**: No
- **Data sold to third parties**: No
- **Data shared for advertising/marketing**: No
- **Ads in app**: No

---

## Content rating questionnaire (separate, quick)
- Category: **Finance / Utility** (not a game)
- Violence / sexual / profanity / drugs / gambling: **No** to all
- User-generated content shared publicly: **No** (group data is private to members)
- Expected result: **Everyone / PEGI 3**

## Target audience
- Age groups: **18+** (or 13+) — NOT "children". This avoids Families policy.

## Ads
- **No, my app does not contain ads.**
