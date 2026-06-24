import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/analytics_service.dart';
import '../utils/app_utils.dart';

// ── Onboarding page data ───────────────────────────────────────────────────
class _PageData {
  final IconData icon;
  final Color iconColor;
  final List<IconData> miniIcons; // floating accent chips in the illustration
  final String title;
  final String subtitle;
  final String buttonLabel;

  const _PageData({
    required this.icon,
    required this.iconColor,
    required this.miniIcons,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });
}

const List<_PageData> _pages = [
  _PageData(
    icon: Icons.account_balance_wallet_rounded,
    iconColor: Color(0xFF0D7377),
    miniIcons: [Icons.trending_up_rounded, Icons.currency_exchange_rounded],
    title: 'Track every\ncent, anywhere.',
    subtitle: 'Income and expenses across all your\ncurrencies — beautifully organized.',
    buttonLabel: 'Next',
  ),
  _PageData(
    icon: Icons.people_rounded,
    iconColor: Color(0xFF14A085),
    miniIcons: [Icons.receipt_long_rounded, Icons.handshake_rounded],
    title: 'Split bills.\nNo awkwardness.',
    subtitle: 'Share group expenses with friends\nand settle up with one tap.',
    buttonLabel: 'Next',
  ),
  _PageData(
    icon: Icons.track_changes_rounded,
    iconColor: Color(0xFF8B5CF6), // TC.purple (light) token value
    miniIcons: [Icons.donut_small_rounded, Icons.savings_rounded],
    title: 'Budgets & goals\nthat keep up.',
    subtitle: 'Set spending limits, save toward goals\nand watch your progress grow.',
    buttonLabel: 'Next',
  ),
  _PageData(
    icon: Icons.verified_user_rounded,
    iconColor: Color(0xFF0D7377),
    miniIcons: [Icons.lock_rounded, Icons.cloud_done_rounded],
    title: 'Secure. Private.\nAlways yours.',
    subtitle: 'Your data stays safe, synced\nand fully under your control.',
    buttonLabel: 'Get Started',
  ),
];

// ── Main widget ────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _ctrl = PageController();
  int _current = 0;
  late AnimationController _iconAnim;
  late Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _iconAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _iconScale = CurvedAnimation(parent: _iconAnim, curve: Curves.elasticOut);
    _iconAnim.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _iconAnim.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_current == _pages.length - 1) {
      AnalyticsService.logOnboardingCompleted();
      widget.onDone();
      return;
    }
    _ctrl.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() {
    HapticFeedback.mediumImpact();
    AnalyticsService.logOnboardingSkipped();
    AnalyticsService.logOnboardingCompleted();
    widget.onDone();
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() => _current = index);
    _iconAnim.reset();
    _iconAnim.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: TC.bg(context),
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar: brand + Skip ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SPLITZEE',
                        style: TC.geist(context,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: TC.primaryMd(context))),
                    GestureDetector(
                      onTap: _skip,
                      child: Text(
                        'Skip',
                        style: TC.geist(context,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: TC.text3(context)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Swipeable pages ──────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: _pages.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (_, i) => _PageContent(
                    page: _pages[i],
                    iconAnim: _iconScale,
                    isCurrent: i == _current,
                  ),
                ),
              ),

              // ── Dots ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _current ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _current
                            ? TC.primary(context)
                            : TC.border(context),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: i == _current
                            ? [
                                BoxShadow(
                                    color: TC.primaryGlow(context),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2)),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),

              // ── CTA Button (gradient) ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: GestureDetector(
                  onTap: _next,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF14A085), Color(0xFF0D7377)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: TC.primaryGlow(context),
                            blurRadius: 18,
                            offset: const Offset(0, 7)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        key: ValueKey(_pages[_current].buttonLabel),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _pages[_current].buttonLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Icon(
                            _current == _pages.length - 1
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single page content ────────────────────────────────────────────────────
class _PageContent extends StatelessWidget {
  final _PageData page;
  final Animation<double> iconAnim;
  final bool isCurrent;

  const _PageContent({
    required this.page,
    required this.iconAnim,
    required this.isCurrent,
  });

  Widget _miniChip(BuildContext context, IconData icon, int slot) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: TC.surface(context),
        shape: BoxShape.circle,
        border: Border.all(color: TC.border(context)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Icon(icon, size: 20, color: page.iconColor),
    )
        // Gentle perpetual float so the illustration never feels static.
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
            begin: slot.isEven ? -3.5 : 3.5,
            end: slot.isEven ? 3.5 : -3.5,
            duration: (1900 + slot * 400).ms,
            curve: Curves.easeInOut)
        // Staggered pop-in that replays each time this page becomes current.
        .animate(target: isCurrent ? 1 : 0, delay: (140 + slot * 130).ms)
        .fadeIn(duration: 260.ms)
        .scale(
            begin: const Offset(0.4, 0.4),
            end: const Offset(1, 1),
            duration: 420.ms,
            curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Layered illustration: soft blob + ring + main icon + mini chips.
          SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    color: page.iconColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 158,
                  height: 158,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: page.iconColor.withValues(alpha: 0.22),
                        width: 1.5),
                  ),
                ),
                ScaleTransition(
                  scale: iconAnim,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          page.iconColor,
                          Color.lerp(page.iconColor, Colors.black, 0.18)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: page.iconColor.withValues(alpha: 0.35),
                            blurRadius: 26,
                            offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Icon(page.icon, size: 48, color: Colors.white),
                  ),
                ),
                Positioned(
                    top: 18,
                    right: 22,
                    child: _miniChip(context, page.miniIcons.first, 0)),
                Positioned(
                    bottom: 26,
                    left: 16,
                    child: _miniChip(context, page.miniIcons.last, 1)),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TC.gloock(context,
                fontSize: 30, letterSpacing: -0.6, color: TC.text(context)),
          )
              .animate()
              .fadeIn(duration: 340.ms, delay: 60.ms, curve: Curves.easeOut)
              .slideY(
                  begin: 0.18,
                  end: 0,
                  duration: 440.ms,
                  delay: 60.ms,
                  curve: Curves.easeOutCubic),
          const SizedBox(height: 14),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TC.geist(context,
                fontSize: 14.5, color: TC.text2(context), height: 1.55),
          )
              .animate()
              .fadeIn(duration: 340.ms, delay: 170.ms, curve: Curves.easeOut)
              .slideY(
                  begin: 0.18,
                  end: 0,
                  duration: 440.ms,
                  delay: 170.ms,
                  curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}
