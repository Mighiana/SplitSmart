import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/security_service.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with WidgetsBindingObserver {
  bool _isAuthenticating = false;
  bool _failed = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(const Duration(milliseconds: 400), _authenticate);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SecurityService.stopAuthentication();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_isAuthenticating &&
        _failed) {
      Future.delayed(
        const Duration(milliseconds: 500),
        _authenticate,
      );
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    if (!mounted) return;
    setState(() {
      _isAuthenticating = true;
      _failed = false;
      _errorMessage = '';
    });

    final result = await SecurityService.authenticate();

    if (!mounted) return;

    if (result) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isAuthenticating = false;
        _failed = true;
        _errorMessage = 'Authentication failed.\nTap the button to try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x1400D68F), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.4),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('💚',
                    style: TextStyle(fontSize: 44)),
              ),
              const SizedBox(height: 24),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800),
                  children: [
                    TextSpan(
                      text: 'Split',
                      style: TextStyle(color: AppColors.text),
                    ),
                    TextSpan(
                      text: 'Smart',
                      style: TextStyle(color: AppColors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your data is protected',
                style: TextStyle(
                    fontSize: 13, color: AppColors.text2),
              ),
              const SizedBox(height: 64),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _failed
                    ? const Text('🔴',
                        key: ValueKey('failed'),
                        style: TextStyle(fontSize: 52))
                    : _isAuthenticating
                        ? const Text('🔓',
                            key: ValueKey('authing'),
                            style: TextStyle(fontSize: 52))
                        : const Text('🔒',
                            key: ValueKey('locked'),
                            style: TextStyle(fontSize: 52)),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _failed
                    ? Text(
                        _errorMessage,
                        key: const ValueKey('error'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.red,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      )
                    : Text(
                        _isAuthenticating
                            ? 'Verifying identity...'
                            : 'Authenticating...',
                        key: const ValueKey('progress'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.text2,
                        ),
                      ),
              ),
              const SizedBox(height: 40),
              if (_isAuthenticating && !_failed)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: AppColors.green,
                    strokeWidth: 2.5,
                  ),
                ),
              if (_failed)
                GestureDetector(
                  onTap: _authenticate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 15),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🔓', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 10),
                        Text(
                          'Try Again',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
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
