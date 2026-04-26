# SplitSmart 🚀
### Your Money, Your Rules.

**SplitSmart** is a production-grade Flutter application designed to simplify bill splitting and personal finance management. Built with Firebase cloud sync, premium aesthetics, robust architecture, and zero-cost AI-powered smart entry.

---

## ✨ Key Features

### 👥 Group Expense Splitting
- **Dynamic Groups**: Create groups for trips, roommates, or events.
- **Settle Up Logic**: Intelligent algorithm calculates the minimum transactions needed to clear all debts.
- **Real-time Balance**: Instantly see who owes you and who you owe across all groups.
- **Custom Splits**: Split by percentage, exact amounts, or shares.
- **QR Invite System**: Share groups instantly via QR codes — scan to join.

### 💰 Personal Finance Manager
- **Multi-Currency Wallets**: Manage personal finances in 90+ world currencies.
- **Spending Analytics**: Beautiful, interactive donut charts showing monthly category breakdowns.
- **Budget Limits**: Set weekly/monthly budgets per category and track spending.
- **Subscription Tracker**: Monitor recurring payments with billing cycle awareness.
- **Saving Goals**: Set and track financial goals with progress visualization.
- **Reminders**: Schedule payment reminders with local notifications.

### 🧠 Smart Expense Entry (Zero-Cost AI)
- **📷 Receipt Scanner**: Google ML Kit (on-device OCR) auto-reads totals from receipt photos.
- **🎤 Voice Input**: Speak expenses naturally — "42 euros dinner paid by Ali" — parsed automatically.
- **💡 Smart Suggestions**: Autocomplete from your expense history, no internet required.

### 🔥 Firebase Cloud Backend
- **Google Sign-In + Email/Password**: Secure authentication via Firebase Auth.
- **Real-time Sync**: Groups, expenses, settlements, and personal data sync across devices via Firestore.
- **Push Notifications**: Automatic notification when a group member adds an expense.
- **Receipt Cloud Storage**: Receipt images uploaded to Firebase Storage, accessible on any device.
- **Offline Fallback**: Seamless local SQLite fallback if Firestore is unreachable.

### 🔒 Privacy & Security
- **Biometric Security**: Protect your financial data with Fingerprint, FaceID, or device lock.
- **Encrypted Backups**: Export and import your entire database as a compressed backup file.
- **Privacy-Safe Analytics**: Only feature usage is tracked — no financial amounts, no names, no PII.

### 🌍 Global Readiness
- **Full Localization**: 8 languages — English, Urdu, Arabic, French, Spanish, German, Turkish, Hindi.
- **Currency Aware**: Automatic symbol formatting and comma grouping for large numbers.

---

## 🏗️ Architecture & Technical Stack

- **Framework**: Flutter (Dart 3.0+)
- **State Management**: `Provider` with optimized `context.select` rebuild patterns.
- **Cloud Backend**: Firebase (Auth, Firestore, Storage, Analytics, Crashlytics, Cloud Messaging)
- **Local Persistence**: `SQLite` (sqflite) — subscriptions & reminders always local, synced data uses Firestore when signed in.
- **Smart Entry**: Google ML Kit (OCR), `speech_to_text` (voice), local pattern matching (suggestions) — all offline, zero-cost.
- **Global Error Boundary**: Dual-layer (Flutter framework + platform dispatcher) crash handling with Firebase Crashlytics + local log file.
- **Modular Design**: Feature-driven screens with domain-specific tab components.

---

## 🛠️ Installation & Setup

### Prerequisites
- Flutter SDK (>= 3.0.0)
- Android Studio / VS Code
- A connected physical device or emulator
- Firebase project configured (google-services.json / GoogleService-Info.plist)

### Run Locally
```bash
# Clone the repository
git clone https://github.com/yourusername/splitsmart.git

# Navigate to project directory
cd splitsmart

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Firebase Setup
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** (Google + Email/Password)
3. Enable **Cloud Firestore** and publish security rules
4. Enable **Firebase Storage** and publish storage rules
5. Deploy the push notification Cloud Function (see deployment guide)
6. Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the project

---

## 📈 Dev Insights
- **Cloud-First Architecture**: Seamless Firestore ↔ SQLite routing based on auth state — no user intervention needed.
- **Modularization**: Refactored monolithic screens into domain-specific tabs for code readability.
- **Reliability**: Button-level loading states prevent duplicate writes on slow devices.
- **Observability**: Firebase Analytics + Crashlytics + local error log for full production visibility.
- **Clean Code**: Centralized domain utilities — Date, Currency, Theme helpers with theme-aware color system.

---

## 🤝 Contributing
SplitSmart is an open-source project. Contributions, issues, and feature requests are welcome!

## 📜 License
Distributed under the MIT License. See `LICENSE` for more information.

---
*Made with ❤️ for better financial transparency.*
