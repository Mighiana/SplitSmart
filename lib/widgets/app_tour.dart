import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // For AppColors

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
      'title': 'Welcome to SplitSmart!',
      'desc': 'Let\'s take a quick tour so you know where everything is.',
      'icon': '👋',
    },
    {
      'title': 'Personal Finances',
      'desc': 'This main screen tracks your wallets, expenses, and income. Tap the FAB to add transactions quickly.',
      'icon': '💰',
    },
    {
      'title': 'Powerful Menu',
      'desc': 'Tap the top left menu grid on the Finance screen to easily access Subscriptions, Reminders, and Saving Goals.',
      'icon': '🎛️',
    },
    {
      'title': 'Settings & Export',
      'desc': 'Tap the top right gear icon to enable Dark Mode, activate Biometric App Lock, or export your data to PDF/CSV.',
      'icon': '⚙️',
    },
    {
      'title': 'Group Overview',
      'desc': 'The second tab (📊) is your Dashboard. See exactly who owes you and who you owe across all your groups.',
      'icon': '📊',
    },
    {
      'title': 'Manage Groups',
      'desc': 'The third tab (👥) is where you add Groups, Split Bills, and settle debts. Swipe lists to Archive old groups!',
      'icon': '👥',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.card2 : Colors.white;
    final text = isDark ? AppColors.text : Colors.black;
    final text2 = isDark ? AppColors.text2 : Colors.black54;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 420,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _tourSteps.length,
                  itemBuilder: (context, i) {
                    final step = _tourSteps[i];
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(step['icon']!, style: const TextStyle(fontSize: 64)),
                          const SizedBox(height: 24),
                          Text(
                            step['title']!,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: text,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            step['desc']!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: text2,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(
                        _tourSteps.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          width: _currentPage == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i ? AppColors.green : AppColors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (_currentPage < _tourSteps.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _finishTour();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _currentPage < _tourSteps.length - 1 ? 'Next' : 'Done',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
