import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // For AppColors
import '../utils/theme_utils.dart'; // For TC

class AppTourDialog extends StatefulWidget {
  const AppTourDialog({super.key});

  @override
  State<AppTourDialog> createState() => _AppTourDialogState();
}

class _AppTourDialogState extends State<AppTourDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _tourSteps = [
    {
      'title': 'Welcome to SplitSmart! 🎉',
      'desc': 'Your all-in-one money manager.\nSplit bills, track spending, scan receipts — all offline & free.',
      'icon': '💚',
    },
    {
      'title': 'Personal Finance',
      'desc': 'The 🏠 Home tab is your personal finance dashboard. Track wallets, expenses, and income across 90+ currencies. Tap + to add transactions.',
      'icon': '💰',
    },
    {
      'title': 'Dashboard Overview',
      'desc': 'The 📊 Overview tab shows your global balances across all groups. See who owes you, who you owe, and your spending breakdown at a glance.',
      'icon': '📊',
    },
    {
      'title': 'Group Splitting',
      'desc': 'The 👥 Groups tab is where you create groups, split bills, and settle debts. Tap the ⚙️ inside any group to edit name and members.',
      'icon': '👥',
    },
    {
      'title': 'Smart Entry',
      'desc': 'When adding expenses, tap 📷 to scan receipts with AI, or tap 🎤 to use voice input. SplitSmart auto-fills amounts and descriptions!',
      'icon': '🧠',
    },
    {
      'title': 'Share & Invite',
      'desc': 'Long-press any group to share it via QR code. Friends scan to join instantly — no sign-up needed!',
      'icon': '🔗',
    },
    {
      'title': 'Activity & History',
      'desc': 'The 📋 Activity tab shows your complete financial history — personal transactions, group expenses, and settlements — all in one timeline.',
      'icon': '📋',
    },
    {
      'title': 'Powerful Tools',
      'desc': 'Tap the menu ☰ on the finance screen to manage Subscriptions, Reminders, Saving Goals, and Budgets. Use ⚙️ for App Lock, Dark Mode, and Exports.',
      'icon': '🎛️',
    },
    {
      'title': 'Multi-Language Support',
      'desc': 'SplitSmart supports 8 languages including Arabic, Urdu, and Hindi with full RTL support. Change language from Settings.',
      'icon': '🌍',
    },
    {
      'title': 'You\'re All Set!',
      'desc': 'Start by creating your first group or adding a transaction. Your data is stored locally and synced to the cloud when you sign in.',
      'icon': '🚀',
    },
  ];

  Future<void> _finishTour() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tour_seen', true);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _tourSteps.length - 1;

    return Dialog(
      backgroundColor: TC.card(context),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        height: 460,
        child: Column(
          children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: _finishTour,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                    child: Text(
                      'Skip',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TC.text3(context)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _tourSteps.length,
                  itemBuilder: (context, i) {
                    final step = _tourSteps[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 90, height: 90,
                            decoration: BoxDecoration(
                              color: AppColors.greenDim,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.green.withValues(alpha: 0.3), width: 3),
                            ),
                            alignment: Alignment.center,
                            child: Text(step['icon']!, style: const TextStyle(fontSize: 44)),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            step['title']!,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: TC.text(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            step['desc']!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: TC.text2(context),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Progress + Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    // Progress bar
                    Container(
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: TC.border(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: LayoutBuilder(
                        builder: (_, constraints) {
                          final width = constraints.maxWidth * ((_currentPage + 1) / _tourSteps.length);
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: width,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        // Step counter
                        Text(
                          '${_currentPage + 1} / ${_tourSteps.length}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.text3(context)),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (!isLast) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _finishTour();
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: isLast ? 32 : 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: Text(
                              isLast ? 'Get Started' : 'Next →',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}
