import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show ImageFilter;
import '../utils/app_utils.dart';
import '../utils/theme_utils.dart';
import '../services/analytics_service.dart';
import 'overview_tab.dart';
import 'groups_screen.dart';
import 'personal_finance_tab.dart';
import 'planner_screen.dart';
import 'add_transaction_screen.dart';
import 'new_group_screen.dart';
import 'saving_goals_screen.dart';
import 'add_subscription_screen.dart';
import 'reminders_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _fabOpen = false;

  static const _screenNames = [
    'money_tab',
    'overview_tab',
    'groups_tab',
    'planner_screen',
  ];

  final _screens = const [
    MoneyTab(),
    HomeTab(),
    GroupsTab(),
    PlannerScreen(),
  ];

  static const String _prefKeySkipped   = 'rate_app_skipped_forever';
  static const String _prefKeySubmitted = 'rate_app_submitted';

  /// Returns true if the app should exit without showing the dialog
  /// (user already rated or chose "Never ask again").
  Future<bool> _handleBackPress() async {
    final prefs = await SharedPreferences.getInstance();
    final skipped   = prefs.getBool(_prefKeySkipped)   ?? false;
    final submitted = prefs.getBool(_prefKeySubmitted) ?? false;

    // Never ask again
    if (skipped || submitted) return true;

    // Show the rating dialog
    if (!mounted) return true;
    int rating = 5;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: EdgeInsets.zero,
              content: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E7D4F), Color(0xFF2DCE98)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF1E7D4F).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text('💚', style: TextStyle(fontSize: 34)),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Enjoying SplitSmart?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (ctx) => Text(
                        'Your review helps us grow and keep improving!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: TC.text2(ctx), height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Stars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setDialogState(() => rating = i + 1);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: const Color(0xFFFFB800),
                              size: 40,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rating == 5 ? '⭐ Amazing!' : rating >= 4 ? 'Really good!' : rating >= 3 ? 'Pretty good' : rating >= 2 ? 'Could be better' : 'Needs work',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: rating >= 4 ? const Color(0xFF1E7D4F) : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E7D4F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(ctx).pop('submit');
                        },
                        child: const Text('Submit & Exit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Later + Skip row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop('later'),
                          child: const Text('Later', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        ),
                        const Text('·', style: TextStyle(color: Colors.grey)),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop('never'),
                          child: const Text('Never ask again', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    switch (result) {
      case 'submit':
        await prefs.setBool(_prefKeySubmitted, true);
        return true;
      case 'never':
        await prefs.setBool(_prefKeySkipped, true);
        return true;
      case 'later':
      default:
        // Just exit this time, ask again next time
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _handleBackPress();
        if (shouldExit && mounted) {
          // Actually exit the app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            IndexedStack(
              index: _index,
              children: _screens,
            ),
            if (_fabOpen) _buildFabMenuOverlay(),
          ],
        ),
        bottomNavigationBar: _buildNav(),
      ),
    );
  }

  Widget _buildNav() {
    final bgColor = TC.navBg(context);
    final unselected = TC.text3(context);
    final selected = TC.primary(context);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(top: BorderSide(color: TC.border(context))),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home', selected, unselected),
                _buildNavItem(1, Icons.pie_chart_outline_rounded, 'Overview', selected, unselected),
                
                // FAB — expands into a context-aware action menu
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _fabOpen = !_fabOpen);
                  },
                  child: AnimatedRotation(
                    turns: _fabOpen ? 0.125 : 0, // 45° → X
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        gradient: _fabOpen
                            ? null
                            : LinearGradient(
                                colors: [
                                  TC.primary(context),
                                  TC.primaryMd(context),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _fabOpen ? TC.er(context) : null,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_fabOpen ? TC.er(context) : TC.primary(context))
                                .withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                  ),
                ),

                _buildNavItem(2, Icons.group_outlined, 'Groups', selected, unselected),
                _buildNavItem(3, Icons.calendar_today_outlined, 'Planner', selected, unselected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Color selected, Color unselected) {
    final active = _index == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (_index != index) {
          AnalyticsService.logScreen(_screenNames[index]);
          setState(() {
            _index = index;
            _fabOpen = false;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? selected : unselected, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TC.geist(
                context,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? selected : unselected,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 16 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: selected,
                borderRadius: BorderRadius.circular(2),
                boxShadow: active ? [
                  BoxShadow(
                    color: selected.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ] : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Context-aware FAB action menu ─────────────────────────────────────────
  void _closeFab() => setState(() => _fabOpen = false);

  void _go(Widget screen) {
    _closeFab();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  List<_FabItem> _fabMenuItems() {
    final state = context.read<AppState>();
    final cur = state.homeCurrency ?? state.wallets.keys.firstOrNull ?? 'USD';
    switch (_index) {
      case 2: // Groups
        return [
          _FabItem('💸', 'Add Expense',
              () => _go(AddTransactionScreen(fixedCurrency: cur, initialType: 'expense'))),
          _FabItem('👥', 'New Group', () => _go(const NewGroupScreen())),
        ];
      case 3: // Planner
        return [
          _FabItem('🎯', 'New Goal', () => _go(const SavingGoalsScreen())),
          _FabItem('🔄', 'Add Subscription', () => _go(const AddSubscriptionScreen())),
          _FabItem('🔔', 'New Reminder', () => _go(const RemindersScreen())),
        ];
      default: // Home / Overview
        return [
          _FabItem('💸', 'Add Expense',
              () => _go(AddTransactionScreen(fixedCurrency: cur, initialType: 'expense'))),
          _FabItem('💰', 'Add Income',
              () => _go(AddTransactionScreen(fixedCurrency: cur, initialType: 'income'))),
          _FabItem('👥', 'New Group', () => _go(const NewGroupScreen())),
          _FabItem('🔔', 'New Reminder', () => _go(const RemindersScreen())),
        ];
    }
  }

  Widget _buildFabMenuOverlay() {
    final items = _fabMenuItems();
    return Positioned.fill(
      child: Stack(
        children: [
          // Scrim — tap anywhere to close
          GestureDetector(
            onTap: _closeFab,
            child: Container(color: Colors.black.withValues(alpha: 0.35))
                .animate()
                .fadeIn(duration: 180.ms),
          ),
          // Menu pills, stacked just above the bottom nav / FAB
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _fabMenuPill(items[i])
                        .animate()
                        .fadeIn(delay: (i * 45).ms, duration: 170.ms)
                        .slideY(
                          begin: 0.35,
                          end: 0,
                          delay: (i * 45).ms,
                          duration: 240.ms,
                          curve: Curves.easeOutBack,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fabMenuPill(_FabItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: TC.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TC.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: TC.geist(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: TC.text(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FabItem {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  _FabItem(this.emoji, this.label, this.onTap);
}
