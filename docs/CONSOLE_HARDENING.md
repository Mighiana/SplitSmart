# Console Hardening Checklist (Spark plan, all free)

These three steps are **clicks in the Firebase / Google Cloud consoles** — they
cannot be done from the CLI or code. They are the real-world maximum defense for
a client app on the free plan. Do them before / right after going public.

Project: **splitsmart-3898**

---

## 1. App Check enforcement on Firestore  ⭐ HIGHEST VALUE

**Why:** Your app already attests as a genuine instance via App Check (Play
Integrity / DeviceCheck). Until you *enforce* it, that attestation is ignored
and a script with a stolen API key can hammer Firestore and exhaust your free
daily quota (DoS — the app goes down for everyone until the quota resets).
Enforcing means non-app requests are rejected before they cost you anything.

**Steps:**
1. https://console.firebase.google.com/project/splitsmart-3898/appcheck
2. First confirm real traffic is showing as "verified" under **APIs → Cloud Firestore**
   (run the published app once so a token is registered). Do NOT enforce while
   the metric shows mostly "unverified" — you'd lock out real users.
3. Once verified requests dominate, click **Cloud Firestore → Enforce**.
4. (Optional) Also enforce on **Authentication** and **Cloud Storage** if/when used.

**Note:** During development, register a debug token (printed in logcat on first
run of a debug build) under App Check → Apps → Manage debug tokens, or debug
builds will be rejected after enforcement.

---

## 2. Restrict the Android API key

**Why:** Limits a leaked key to *your* app signature, so it can't be reused by
a script from elsewhere. Defense-in-depth (rules + App Check are the real gate).

**Steps:**
1. https://console.cloud.google.com/apis/credentials?project=splitsmart-3898
2. Open the **Android key** (the one in `android/app/google-services.json`).
3. **Application restrictions → Android apps** → add:
   - Package name: `com.splitsmart.splitsmart`
   - SHA-1: get it from the Play Console after upload
     (**Release → Setup → App signing → App signing key certificate**), and/or
     your upload key: `keytool -list -v -keystore android/app/splitsmart-release.jks -alias splitsmart`
4. **API restrictions → Restrict key** → allow only the APIs the app uses
   (Identity Toolkit / Firebase Auth, Cloud Firestore, Firebase Installations,
   Firebase App Check, FCM). Save.

> Add BOTH the Play app-signing SHA-1 and your upload-key SHA-1, or Google
> Sign-In can break after Play re-signs the app.

---

## 3. Auth protections

**Why:** Reduces account-enumeration and credential-stuffing risk. Free.

**Steps:**
1. https://console.firebase.google.com/project/splitsmart-3898/authentication/settings
2. Enable **Email enumeration protection** (hides whether an email is registered).
3. Enable **Password policy** + leaked-password protection if offered.
4. Confirm **Email/Password** and **Google** are the only enabled providers.

---

## Quick reference — what's already done in code/rules
- App Check client attestation wired (Play Integrity / DeviceCheck) — `main.dart`
- Firestore rules: default-deny, member-gated, type+size bounded, append/remove-only joins — deployed
- Release builds obfuscated (Dart) + minified (R8) — `scripts/build_release.ps1`
- Local DB encrypted at rest (SQLCipher); shared backups passphrase-encrypted
- No secrets committed; keystore git-ignored
