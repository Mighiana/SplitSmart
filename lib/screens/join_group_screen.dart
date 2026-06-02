import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_state.dart';
import '../utils/theme_utils.dart';
import 'group_detail_screen.dart';

/// Lets an accountless person JOIN a group as a guest (Firebase Anonymous Auth).
/// Available only for groups whose owner has SplitSmart Premium.
class JoinGroupScreen extends StatefulWidget {
  /// Optionally pre-filled from a scanned QR / deep link.
  final String? initialCode;
  const JoinGroupScreen({super.key, this.initialCode});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  late final TextEditingController _codeCtrl =
      TextEditingController(text: widget.initialCode ?? '');
  final TextEditingController _nameCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty) {
      _snack('Enter an invite code.');
      return;
    }
    if (name.isEmpty) {
      _snack('Enter your name so the group knows who you are.');
      return;
    }

    setState(() => _busy = true);
    final state = context.read<AppState>();
    final group = await state.joinAsGuest(code, name);
    if (!mounted) return;
    setState(() => _busy = false);

    if (group == null) {
      _snack(state.lastGuestJoinError ?? 'Could not join the group.');
      return;
    }
    state.currentGroup = group;
    HapticFeedback.mediumImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GroupDetailScreen()),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TC.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Join a Group',
            style: TextStyle(
                color: TC.text(context), fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: TC.text(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(child: Text('🔗', style: TextStyle(fontSize: 44))),
              const SizedBox(height: 16),
              Text(
                'Join as a guest',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: TC.text(context)),
              ),
              const SizedBox(height: 8),
              Text(
                "No account needed. You'll be able to add expenses and see "
                'balances right away.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: TC.text2(context)),
              ),
              const SizedBox(height: 28),
              _label(context, 'INVITE CODE'),
              const SizedBox(height: 8),
              _field(
                context,
                controller: _codeCtrl,
                hint: 'e.g. 4F9K2QXP',
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 20),
              _label(context, 'YOUR NAME'),
              const SizedBox(height: 8),
              _field(context, controller: _nameCtrl, hint: 'e.g. Sam'),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: _busy ? null : _join,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _busy
                        ? AppColors.green.withValues(alpha: 0.5)
                        : AppColors.green,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black),
                        )
                      : const Text('Join Group',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blueDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Create a free account later to keep your groups if '
                        'you change phones.',
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: TC.text(context)),
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

  Widget _label(BuildContext context, String t) => Text(
        t,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: TC.text3(context)),
      );

  Widget _field(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: TC.text3(context)),
        filled: true,
        fillColor: TC.card(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: TC.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: TC.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.green, width: 2),
        ),
      ),
    );
  }
}
