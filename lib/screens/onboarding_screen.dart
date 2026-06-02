import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/analytics_service.dart';

// ── Onboarding page data ───────────────────────────────────────────────────
class _PageData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;

  const _PageData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });
}

const _green = Color(0xFF2DB85A);
const _darkNavy = Color(0xFF1A2340);
const _subtitleGrey = Color(0xFF8A8FA8);

const List<_PageData> _pages = [
  _PageData(
    icon: Icons.account_balance_wallet_rounded,
    iconColor: Color(0xFF2DB85A),
    title: 'Track Every\nRupee & Euro.',
    subtitle: 'Monitor income and expenses\nacross all your currencies.',
    buttonLabel: 'Next',
  ),
  _PageData(
    icon: Icons.people_rounded,
    iconColor: Color(0xFF2DB85A),
    title: 'Split Bills.\nNo Awkwardness.',
    subtitle: 'Share expenses with friends\nand settle up with one tap.',
    buttonLabel: 'Next',
  ),
  _PageData(
    icon: Icons.verified_user_rounded,
    iconColor: Color(0xFF2DB85A),
    title: 'Secure. Private.\nAlways in control.',
    subtitle: 'Your data is safe and you\'re\nalways in control.',
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar: pill + Skip ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Progress pill
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDE1EA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    // Skip
                    GestureDetector(
                      onTap: _skip,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8A8FA8),
                        ),
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
                        color: i == _current ? _green : const Color(0xFFCED2DC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),

              // ── CTA Button ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _pages[_current].buttonLabel,
                        key: ValueKey(_pages[_current].buttonLabel),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // ── Icon illustration ────────────────────────────────────────
          ScaleTransition(
            scale: iconAnim,
            child: _IllustrationCircle(icon: page.icon),
          ),

          const Spacer(flex: 2),

          // ── Title ────────────────────────────────────────────────────
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _darkNavy,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 14),

          // ── Subtitle ─────────────────────────────────────────────────
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w400,
              color: _subtitleGrey,
              height: 1.55,
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// ── Illustration circle widget ─────────────────────────────────────────────
class _IllustrationCircle extends StatelessWidget {
  final IconData icon;

  const _IllustrationCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outermost very faint glow
          Container(
            width: 260,
            height: 260,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF0FBF4),
            ),
          ),
          // Middle glow ring
          Container(
            width: 210,
            height: 210,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFDDF4E7),
            ),
          ),
          // Inner glow
          Container(
            width: 165,
            height: 165,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFB8ECCC), Color(0xFFDDF4E7)],
              ),
            ),
          ),

          // Cloud decoration top-left
          const Positioned(
            top: 28,
            left: 24,
            child: _CloudShape(size: 36, opacity: 0.55),
          ),
          // Cloud decoration bottom-right
          const Positioned(
            bottom: 34,
            right: 20,
            child: _CloudShape(size: 30, opacity: 0.45),
          ),

          // Sparkle top-right
          Positioned(
            top: 52,
            right: 40,
            child: _Sparkle(size: 10, color: _green.withValues(alpha: 0.7)),
          ),
          // Sparkle bottom-left
          Positioned(
            bottom: 58,
            left: 38,
            child: _Sparkle(size: 7, color: _green.withValues(alpha: 0.5)),
          ),

          // Main icon container (shield-like card)
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3DD68C), Color(0xFF1AAD5A)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _green.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 54,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cloud shape ────────────────────────────────────────────────────────────
class _CloudShape extends StatelessWidget {
  final double size;
  final double opacity;
  const _CloudShape({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Icon(Icons.cloud_rounded, size: size, color: const Color(0xFFB8C4D0)),
    );
  }
}

// ── Sparkle / star ─────────────────────────────────────────────────────────
class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;
  const _Sparkle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.auto_awesome_rounded, size: size, color: color);
  }
}
