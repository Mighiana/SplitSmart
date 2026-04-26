import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../utils/theme_utils.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';

/// Premium authentication screen — Google Sign-In + Email/Password.
/// Matches the SplitSmart Emerald/Dark luxury aesthetic.
class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _showEmailForm = false;
  bool _isSignUp = true;
  bool _obscurePassword = true;
  String? _errorMessage;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _shimmerCtrl;
  late AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _shimmerCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  // ─── Google Sign-In ─────────────────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      await AuthService.instance.signInWithGoogle();
      AnalyticsService.logScreen('auth_google_success');
      if (mounted) widget.onAuthenticated();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AuthService.friendlyError(e);
          _isLoading = false;
        });
      }
    }
  }

  // ─── Email Sign-In / Sign-Up ────────────────────────────────────────────

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      if (_isSignUp) {
        await AuthService.instance.signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          displayName: _nameCtrl.text.trim(),
        );
        AnalyticsService.logScreen('auth_email_signup_success');
      } else {
        await AuthService.instance.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        AnalyticsService.logScreen('auth_email_signin_success');
      }
      if (mounted) widget.onAuthenticated();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AuthService.friendlyError(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePasswordReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email first.');
      return;
    }
    // Basic email format check
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) {
        setState(() => _errorMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Password reset email sent!\nCheck your inbox & spam/junk folder.',
                style: TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = AuthService.friendlyError(e));
      }
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TC.bg(context),
      body: Stack(
        children: [
          // ── Animated background orbs ───────────────────────────
          _buildBackgroundOrbs(),

          // ── Main content ───────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),

                    // ── Logo + branding ──────────────────────────
                    _buildBranding(),

                    const SizedBox(height: 40),

                    // ── Auth card ────────────────────────────────
                    _buildAuthCard(),

                    // ── Error message ────────────────────────────
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorMessage(),
                    ],

                    const SizedBox(height: 32),

                    // ── Terms text ───────────────────────────────
                    _buildTerms(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI Components
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBackgroundOrbs() {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -60 + (_bgCtrl.value * 30),
              right: -40 + (_bgCtrl.value * 20),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.green.withValues(alpha: 0.15),
                      AppColors.green.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 100 - (_bgCtrl.value * 40),
              left: -80 + (_bgCtrl.value * 25),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.blue.withValues(alpha: 0.1),
                      AppColors.blue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        // App icon with glow
        Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.green,
                AppColors.green.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Text('💚', style: TextStyle(fontSize: 42)),
        )
            .animate()
            .scale(
                duration: 700.ms,
                begin: const Offset(0.2, 0.2),
                curve: Curves.elasticOut)
            .fadeIn(duration: 400.ms),

        const SizedBox(height: 28),

        // Title
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Split',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: TC.text(context),
                letterSpacing: -1,
              ),
            ),
            const Text(
              'Smart',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.green,
                letterSpacing: -1,
              ),
            ),
          ],
        )
            .animate(delay: 200.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.3, curve: Curves.easeOut),

        const SizedBox(height: 10),

        Text(
          'Smart expense splitting, simplified.',
          style: TextStyle(
            fontSize: 15,
            color: TC.text2(context),
            height: 1.4,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        )
            .animate(delay: 400.ms)
            .fadeIn(duration: 500.ms),
      ],
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: TC.border(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: TC.shadow(context),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_showEmailForm) ...[
            _buildGoogleButton(),
            const SizedBox(height: 20),
            _buildDivider(),
            const SizedBox(height: 20),
            _buildEmailToggle(),
          ],

          if (_showEmailForm) ...[
            _buildEmailForm(),
            const SizedBox(height: 16),
            _buildBackToSocialButton(),
          ],
        ],
      ),
    )
        .animate(delay: 500.ms)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.15, curve: Curves.easeOut);
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleGoogleSignIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: TC.bg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TC.border(context), width: 1.5),
        ),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.green,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" logo
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: TC.text(context),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: TC.border(context))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: TC.bg(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'or',
              style: TextStyle(
                color: TC.text3(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(child: Divider(color: TC.border(context))),
      ],
    );
  }

  Widget _buildEmailToggle() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _showEmailForm = true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TC.border(context), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline_rounded,
                size: 20, color: TC.text2(context)),
            const SizedBox(width: 10),
            Text(
              'Continue with Email',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: TC.text2(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toggle: Sign Up / Sign In
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: TC.bg(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _buildTabButton('Create Account', _isSignUp, () {
                  setState(() => _isSignUp = true);
                }),
                const SizedBox(width: 4),
                _buildTabButton('Sign In', !_isSignUp, () {
                  setState(() => _isSignUp = false);
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Name field (sign-up only)
          if (_isSignUp) ...[
            _buildTextField(
              controller: _nameCtrl,
              icon: Icons.person_outline_rounded,
              hint: 'Full name (optional)',
              validator: null, // Optional
              action: TextInputAction.next,
            ),
            const SizedBox(height: 14),
          ],

          // Email
          _buildTextField(
            controller: _emailCtrl,
            icon: Icons.mail_outline_rounded,
            hint: 'Email address',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
            action: TextInputAction.next,
          ),
          const SizedBox(height: 14),

          // Password with visibility toggle
          _buildTextField(
            controller: _passCtrl,
            icon: Icons.lock_outline_rounded,
            hint: 'Password',
            obscure: _obscurePassword,
            suffixIcon: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _obscurePassword = !_obscurePassword);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  key: ValueKey(_obscurePassword),
                  size: 20,
                  color: TC.text3(context),
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a password';
              if (v.length < 6) return 'Must be at least 6 characters';
              return null;
            },
            action: TextInputAction.done,
            onSubmitted: (_) => _handleEmailAuth(),
          ),

          // Forgot password
          if (!_isSignUp) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _handlePasswordReset,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Submit button
          _buildSubmitButton(),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildTabButton(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? AppColors.green.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(
                    color: AppColors.green.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.green : TC.text3(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputAction? action,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: TextStyle(
        color: TC.text(context),
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: TC.text3(context), size: 20),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffixIcon,
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
        hintText: hint,
        hintStyle: TextStyle(
          color: TC.text3(context),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: TC.bg(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: TC.border(context), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: TC.border(context), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppColors.red.withValues(alpha: 0.5), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
      ),
      validator: validator,
      textInputAction: action,
      onFieldSubmitted: onSubmitted,
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleEmailAuth,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.green,
              AppColors.green.withValues(alpha: 0.85),
            ],
          ),
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
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp ? 'Create Account' : 'Sign In',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.black,
                    size: 18,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBackToSocialButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _showEmailForm = false;
          _errorMessage = null;
          _obscurePassword = true;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_back_ios_rounded,
                size: 14, color: TC.text3(context)),
            const SizedBox(width: 4),
            Text(
              'Back to all sign-in options',
              style: TextStyle(
                color: TC.text3(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.redDim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: AppColors.red, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    ).animate().shake(duration: 400.ms, hz: 3).fadeIn(duration: 200.ms);
  }

  Widget _buildTerms() {
    return Text(
      'By continuing, you agree to the Terms of Service\nand Privacy Policy',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: TC.text3(context),
        height: 1.5,
      ),
    );
  }
}
