import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../utils/theme_utils.dart';
import '../services/analytics_service.dart';

/// 3-page swipeable onboarding — shown only on first launch.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_page < 2) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      AnalyticsService.logOnboardingCompleted();
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Pages ──────────────────────────────────────────────────────
            PageView(
              controller: _ctrl,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _page = i);
              },
              children: const [_Page1(), _Page2(), _Page3()],
            ),

            // ── Skip (pages 0 & 1 only) ────────────────────────────────────
            if (_page < 2)
              Positioned(
                top: 12,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    AnalyticsService.logOnboardingSkipped();
                    widget.onDone();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: TC.card(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: TC.border(context)),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: TC.text2(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Bottom controls ────────────────────────────────────────────
            Positioned(
              bottom: 48,
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == i ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? AppColors.green
                              : TC.border(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // CTA button
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _page == 2 ? '🚀  Get Started' : 'Next  →',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
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
    );
  }
}

// ─── Shared page layout ───────────────────────────────────────────────────────
class _PageShell extends StatelessWidget {
  final Widget illustration;
  final String badge;
  final Color badgeColor;
  final Color badgeBg;
  final String headline;
  final String subtext;

  const _PageShell({
    required this.illustration,
    required this.badge,
    required this.badgeColor,
    required this.badgeBg,
    required this.headline,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: illustration,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            headline,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: TC.text(context),
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 16,
              color: TC.text2(context),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 1: Split bills, no drama ───────────────────────────────────────────
class _Page1 extends StatelessWidget {
  const _Page1();

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      badge: '💰  Expense Tracking',
      badgeColor: AppColors.green,
      badgeBg: AppColors.greenDim,
      headline: 'Smart Expense\nTracking.',
      subtext: 'Manage your personal finances and track group splits effortlessly.',
      illustration: _SplitIllustration(),
    );
  }
}

// ─── Page 2: Track your money ─────────────────────────────────────────────────
class _Page2 extends StatelessWidget {
  const _Page2();

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      badge: '📊  Money Manager',
      badgeColor: AppColors.blue,
      badgeBg: AppColors.blueDim,
      headline: 'Track your\nmoney.',
      subtext: 'Personal income and expense\nmanager built right in.',
      illustration: _BudgetIllustration(),
    );
  }
}

// ─── Page 3: Offline ─────────────────────────────────────────────────────
class _Page3 extends StatelessWidget {
  const _Page3();

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      badge: '☁️  Cloud Sync',
      badgeColor: AppColors.green,
      badgeBg: AppColors.greenDim,
      headline: 'Sync Across\nAll Devices.',
      subtext:
          'Sign in to sync your data securely via Firebase. Your financial data is encrypted and private.',
      illustration: _PrivacyIllustration(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Illustrations (widget-based, no images needed)
// ═══════════════════════════════════════════════════════════════════════════════

/// Illustration 1 — 3 avatars around a floating bill card
class _SplitIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Glow background
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.green.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),

            // Central bill card
          Container(
            width: 140,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: TC.border(context)),
              boxShadow: [
                BoxShadow(
                  color: TC.shadow(context),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🍽️', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  'Dinner',
                  style: TextStyle(
                    color: TC.text(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '€42.00',
                  style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: TC.border(context)),
                const SizedBox(height: 8),
                Text(
                  '÷ 3 people',
                  style: TextStyle(color: TC.text2(context), fontSize: 11),
                ),
                const SizedBox(height: 4),
                const Text(
                  '€14 each',
                  style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Illustration 2 — Budget bars with income/expense breakdown
class _BudgetIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bars = [
      ('🍽️', 'Food', 0.75, AppColors.red),
      ('🚗', 'Transport', 0.45, AppColors.blue),
      ('🛒', 'Shopping', 0.9, AppColors.yellow),
      ('💡', 'Bills', 0.3, AppColors.green),
      ('🎉', 'Fun', 0.55, AppColors.purple),
    ];

    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TC.border(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('MMM yyyy').format(DateTime.now()),
                style: TextStyle(
                  color: TC.text(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.greenDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'On track ✓',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...bars.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(b.$1, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        b.$2,
                        style: TextStyle(
                          color: TC.text2(context),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(b.$3 * 100).toInt()}%',
                        style: TextStyle(
                          color: b.$4,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: b.$3,
                      backgroundColor: TC.border(context),
                      valueColor: AlwaysStoppedAnimation(b.$4),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Illustration 3 — Privacy
class _PrivacyIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.greenDim,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.5), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_rounded, size: 100, color: AppColors.green.withValues(alpha: 0.2)),
          const Icon(Icons.lock_rounded, size: 50, color: AppColors.green),
        ],
      ),
    );
  }
}
