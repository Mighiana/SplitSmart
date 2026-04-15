import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';
import '../l10n/app_localizations.dart';
import 'overview_tab.dart';
import 'groups_screen.dart';
import 'personal_finance_tab.dart';
import 'activity_screen.dart';
import 'currencies_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _screenNames = [
    'money_tab',
    'overview_tab',
    'groups_tab',
    'activity_screen',
    'currencies_tab',
  ];

  // Final field on State, not Widget \u2014 created once when the State is
  // initialized and reused across rebuilds. IndexedStack keeps all tabs alive.
  final _screens = const [
    MoneyTab(),
    HomeTab(),
    GroupsTab(),
    ActivityScreen(),
    CurrenciesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final navItems = [
      _NavItem('💰', l.money),
      _NavItem('📊', 'Overview'),
      _NavItem('👥', l.groups),
      _NavItem('📋', l.activity),
      _NavItem('🌍', l.currencies),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: _buildNav(navItems),
    );
  }

  Widget _buildNav(List<_NavItem> navItems) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: TC.bg(context),
      ),
      child: SafeArea(
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: TC.card(context).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TC.border(context).withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (i) {
              final item = navItems[i];
              final active = i == _index;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (_index != i) {
                      AnalyticsService.logScreen(_screenNames[i]);
                    }
                    setState(() => _index = i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AppColors.green.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          item.icon,
                          style: TextStyle(
                            fontSize: active ? 24 : 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: active ? AppColors.green : TC.text3(context),
                        ),
                        child: Text(item.label.toUpperCase()),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String icon, label;
  const _NavItem(this.icon, this.label);
}
