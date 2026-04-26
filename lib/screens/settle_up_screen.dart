import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';
import '../widgets/common_widgets.dart';

class SettleUpScreen extends StatefulWidget {
  const SettleUpScreen({super.key});

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen>
    with TickerProviderStateMixin {
  final Map<int, String> _methods = {};
  bool _isSettling = false;

  // ── Entry animations ────────────────────────────────────────────────────────
  late AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  /// Fade + slide-up animation for each card with a stagger offset.
  Animation<double> _fadeFor(int i) => CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(
          (i * 0.12).clamp(0.0, 0.6),
          ((i * 0.12) + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      );

  Animation<Offset> _slideFor(int i) => Tween<Offset>(
        begin: const Offset(0, 0.18),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(
          (i * 0.12).clamp(0.0, 0.6),
          ((i * 0.12) + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final g = context.select<AppState, GroupData?>((s) => s.currentGroup);
    if (g == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final state =
        context.read<AppState>(); // for buildSettlePlan + recordSettlement
    final plan = state.buildSettlePlan(g);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeFor(0),
              child: SlideTransition(
                position: _slideFor(0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: TC.card(context),
                          shape: BoxShape.circle,
                          border: Border.all(color: TC.border(context)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '←',
                          style: TextStyle(
                            fontSize: 18,
                            color: TC.text(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Settle Up',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: TC.text(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Info card ────────────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeFor(1),
              child: SlideTransition(
                position: _slideFor(1),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.blueDim, Colors.transparent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📊 Minimum transactions needed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'These are the exact payments to settle all debts. Every number comes from the Breakdown tab.',
                        style: TextStyle(
                          fontSize: 13,
                          color: TC.text2(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Plan cards ───────────────────────────────────────────────────
            if (plan.isEmpty)
              FadeTransition(
                opacity: _fadeFor(2),
                child: const _SettledAllBadge(),
              )
            else
              ...plan.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                final method = _methods[i] ?? '';
                // Only the payer or receiver can record the payment
                final canRecord = p.from == 'You' || p.to == 'You';

                return FadeTransition(
                  opacity: _fadeFor(i + 2),
                  child: SlideTransition(
                    position: _slideFor(i + 2),
                    child: _PaymentCard(
                      index: i,
                      pair: p,
                      method: method,
                      group: g,
                      isSettling: _isSettling,
                      canRecord: canRecord,
                      onMethodChanged: (m) => setState(() => _methods[i] = m),
                      onConfirm: canRecord
                          ? () => _confirm(context, i, p.from, p.to, p.amount, g)
                          : null,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    int idx,
    String from,
    String to,
    double amount,
    GroupData g,
  ) async {
    if (_isSettling) return; // Guard against double-taps
    setState(() => _isSettling = true);
    HapticFeedback.heavyImpact();
    final method = _methods[idx] ?? 'Cash';
    final today = AppDateUtils.todayStr();

    try {
      await context.read<AppState>().recordSettlement(
            g,
            SettlementData(
              from: from,
              to: to,
              amount: amount,
              method: method,
              date: today,
            ),
          );

      if (!mounted) return;
      await AnalyticsService.logSettledUp();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✓ Payment recorded!',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      if (!mounted) return;
      final state = context.read<AppState>();
      final remaining = state.buildSettlePlan(g);
      if (remaining.isEmpty) {
        // Defer pop to avoid '!_debugLocked' assertion during SnackBar transition
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settlement failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSettling = false);
    }
  }
}

// ─── Settled-all badge ────────────────────────────────────────────────────────

class _SettledAllBadge extends StatefulWidget {
  const _SettledAllBadge();

  @override
  State<_SettledAllBadge> createState() => _SettledAllBadgeState();
}

class _SettledAllBadgeState extends State<_SettledAllBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.greenDim.withValues(alpha: 0.08 + _pulse.value * 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.green.withValues(alpha: 0.2 + _pulse.value * 0.15),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_rounded,
                size: 48 + _pulse.value * 8, color: AppColors.green),
            const SizedBox(height: 12),
            Text(
              'All settled up!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: TC.text(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No payments needed right now',
              style: TextStyle(fontSize: 13, color: TC.text2(context)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single payment card ──────────────────────────────────────────────────────

class _PaymentCard extends StatefulWidget {
  final int index;
  final SettlePair pair;
  final String method;
  final GroupData group;
  final bool isSettling;
  final bool canRecord;
  final void Function(String) onMethodChanged;
  final VoidCallback? onConfirm;

  const _PaymentCard({
    required this.index,
    required this.pair,
    required this.method,
    required this.group,
    required this.isSettling,
    required this.canRecord,
    required this.onMethodChanged,
    required this.onConfirm,
  });

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard>
    with SingleTickerProviderStateMixin {
  double _btnScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final p = widget.pair;
    final canRecord = widget.canRecord;
    final g = widget.group;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TC.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:
              Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── From → To row ────────────────────────────────────────────────
            Row(
              children: [
                _PersonChip(name: p.from, context: context),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'pays',
                        style: TextStyle(
                          fontSize: 11,
                          color: TC.text3(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '→',
                        style: TextStyle(
                          fontSize: 22,
                          color: TC.text3(context),
                        ),
                      ),
                    ],
                  ),
                ),
                _PersonChip(name: p.to, context: context, right: true),
              ],
            ),

            // ── Amount badge ─────────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.greenDim,
                  borderRadius: BorderRadius.circular(30),
                  border:
                      Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${g.sym}${p.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
              ),
            ),

            // ── Method label ─────────────────────────────────────────────────
            if (canRecord) ...[
              Text(
                'PAYMENT METHOD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TC.text3(context),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),

              // ── Method chips ─────────────────────────────────────────────────
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: AppState.settleMethods.map((m) {
                  final active = widget.method == m;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onMethodChanged(m);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: active ? AppColors.blueDim : TC.card2(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? AppColors.blue : TC.border(context),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        m,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? AppColors.blue : TC.text2(context),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // ── Confirm button with bounce ────────────────────────────────────
              GestureDetector(
                onTapDown: widget.isSettling ? null : (_) => setState(() => _btnScale = 0.96),
                onTapUp: widget.isSettling ? null : (_) {
                  setState(() => _btnScale = 1.0);
                  HapticFeedback.mediumImpact();
                  widget.onConfirm?.call();
                },
                onTapCancel: widget.isSettling ? null : () => setState(() => _btnScale = 1.0),
                child: AnimatedScale(
                  scale: _btnScale,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: widget.isSettling ? 0.6 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: widget.isSettling
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: Colors.black, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Confirm: ${p.from} paid ${p.to} ${g.sym}${p.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // ── Not your payment — show disabled info ─────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: TC.card2(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TC.border(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 18, color: TC.text3(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Only ${p.from} or ${p.to} can record this payment',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: TC.text3(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Person chip (avatar + name) ──────────────────────────────────────────────

class _PersonChip extends StatelessWidget {
  final String name;
  final BuildContext context;
  final bool right;

  const _PersonChip({
    required this.name,
    required this.context,
    this.right = false,
  });

  @override
  Widget build(BuildContext ctx) {
    return Column(
      children: right
          ? [
              AvatarCircle(label: name, size: 40),
              const SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: TC.text(context),
                ),
              ),
              Text(
                'receives',
                style: TextStyle(
                  fontSize: 10,
                  color: TC.text3(context),
                ),
              ),
            ]
          : [
              AvatarCircle(label: name, size: 40),
              const SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: TC.text(context),
                ),
              ),
              Text(
                'pays',
                style: TextStyle(
                  fontSize: 10,
                  color: TC.text3(context),
                ),
              ),
            ],
    );
  }
}
