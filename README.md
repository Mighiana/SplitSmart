# SplitSmart 🚀
### Your Money, Your Rules.

**SplitSmart** is a production-grade, privacy-first, offline-first Flutter application designed to simplify bill splitting and personal finance management. Built with a focus on premium aesthetics, robust architecture, and 100% data ownership.

---

## ✨ Key Features

### 👥 Group Expense Splitting
- **Dynamic Groups**: Create groups for trips, roommates, or events.
- **Settle Up Logic**: Intelligent algorithm calculates the minimum number of transactions needed to clear all debts.
- **Real-time Balance**: Instantly see who owes you and who you owe across all groups.
- **Custom Splits**: Split by percentage, exact amounts, or shares.

### 💰 Personal Finance Manager
- **Multi-Currency Wallets**: Manage personal finances in 50+ world currencies.
- **Spending Analytics**: Beautiful, interactive donut charts (via `fl_chart`) showing monthly category breakdowns.
- **Transaction History**: Searchable and filterable history of every penny spent or earned.

### 🔒 Privacy & Security
- **100% Local**: No cloud sync, no signup, no tracking. Your data never leaves your device.
- **Biometric Security**: Protect your financial data with Fingerprint, FaceID, or custom Pattern Lock.
- **Encrypted Backups**: Export and import your entire database as a secure file.

### 🌍 Global Readineess
- **Full Localization**: Support for 8 languages: English, Urdu, Arabic, French, Spanish, German, Turkish, and Hindi.
- **Currency Aware**: Automatic symbol formatting and comma grouping for large numbers.

---

## 🏗️ Architecture & Technical Stack

SplitSmart is built using a **Senior-Developer audited architecture** designed for maintainability and scale:

- **Framework**: Flutter (Dart)
- **State Management**: `Provider` with optimized `context.select` rebuild patterns.
- **Local Persistence**: `SQLite` (sqflite) with a robust Service/Repository wrapper.
- **Modular Design**: UI is decoupled into feature-driven components (e.g., modularized `GroupDetail` tabs).
- **Global Error Boundary**: High-level exception handling that logs framework crashes to an offline `app_errors.log`.
- **Support System**: Built-in "Send Support Logs" feature allows users to export crash logs for debugging without compromising personal data.

---

## 🛠️ Installation & Setup

### Prerequisites
- Flutter SDK (>= 3.0.0)
- Android Studio / VS Code
- A connected physical device or emulator

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

---

## 📈 Dev Insights (Post-Audit Enhancements)
- **Modularization**: Refactored monolithic screens into domain-specific tabs to improve code readability and team collaboration.
- **Reliability**: Implemented button-level loading states to prevent duplicate database writes on slow devices.
- **Observability**: Centralized app logging for production debugging.
- **Clean Code**: Centralized domain utilities into specific Date, Currency, and Theme helper classes.

---

## 🤝 Contributing
SplitSmart is an open-source project. Contributions, issues, and feature requests are welcome!

## 📜 License
Distributed under the MIT License. See `LICENSE` for more information.

---
*Made with ❤️ for better financial transparency.*
