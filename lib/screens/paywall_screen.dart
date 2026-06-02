import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_state.dart';
import '../services/iap_service.dart';
import '../utils/theme_utils.dart';

/// SplitSmart Premium paywall.
///
/// Premium unlocks **guest join** — letting people join your groups without
/// creating an account. The group owner subscribes; guests never pay.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _iap = IapService.instance;
  StreamSubscription<Entitlement>? _entSub;
  StreamSubscription<String>? _errSub;
  bool _busy = false;
  String _selected = IapService.yearlyId;

  @override
  void initState() {
    super.initState();
    _iap.init();
    final appState = context.read<AppState>();
    _entSub = _iap.onEntitlement.listen((ent) async {
      await appState.onPurchaseVerified(ent);
      if (!mounted) return;
      setState(() => _busy = false);
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    });
    _errSub = _iap.onError.listen((msg) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.red),
      );
    });
  }

  @override
  void dispose() {
    _entSub?.cancel();
    _errSub?.cancel();
    super.dispose();
  }

  String _priceFor(String id, String fallback) {
    for (final p in _iap.products) {
      if (p.id == id) return p.price;
    }
    return fallback;
  }

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    final ok = await _iap.buy(_selected);
    if (!ok && mounted) setState(() => _busy = false);
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    await _iap.restore();
  }

  @override
  Widget build(BuildContext context) {
    // If already premium, reflect it.
    final hasPremium = context.select<AppState, bool>((s) => s.hasPremium);

    return Scaffold(
      backgroundColor: TC.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: TC.text(context)),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.greenDim,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('✨', style: TextStyle(fontSize: 34)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'SplitSmart Premium',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: TC.text(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Let anyone join your groups — no account needed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: TC.text2(context)),
              ),
              const SizedBox(height: 24),
              ..._benefits(context),
              const SizedBox(height: 24),
              if (hasPremium)
                _activeBanner(context)
              else ...[
                _planTile(
                  context,
                  id: IapService.yearlyId,
                  title: 'Yearly',
                  price: _priceFor(IapService.yearlyId, '\$29.99 / yr'),
                  badge: 'BEST VALUE',
                ),
                const SizedBox(height: 12),
                _planTile(
                  context,
                  id: IapService.monthlyId,
                  title: 'Monthly',
                  price: _priceFor(IapService.monthlyId, '\$3.99 / mo'),
                ),
                const SizedBox(height: 24),
                _subscribeButton(context),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(
                    'Restore Purchases',
                    style: TextStyle(
                      color: TC.text2(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Subscription auto-renews until cancelled. Manage or cancel '
                'anytime in your store account settings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: TC.text3(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _benefits(BuildContext context) {
    const items = [
      ['🔗', 'Guest join', 'Friends join via link or QR — no sign-up.'],
      ['⚡', 'Instant access', 'They start adding expenses right away.'],
      ['🔒', 'Stays secure', 'Guests only see the groups you share.'],
    ];
    return items
        .map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Text(b[0], style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b[1],
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: TC.text(context))),
                        Text(b[2],
                            style: TextStyle(
                                fontSize: 13, color: TC.text2(context))),
                      ],
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }

  Widget _planTile(BuildContext context,
      {required String id,
      required String title,
      required String price,
      String? badge}) {
    final selected = _selected == id;
    return GestureDetector(
      onTap: () => setState(() => _selected = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: TC.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.green : TC.border(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.green : TC.text3(context),
            ),
            const SizedBox(width: 12),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: TC.text(context))),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.greenDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.green)),
              ),
            ],
            const Spacer(),
            Text(price,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: TC.text(context))),
          ],
        ),
      ),
    );
  }

  Widget _subscribeButton(BuildContext context) {
    return GestureDetector(
      onTap: _busy ? null : _subscribe,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _busy ? AppColors.green.withValues(alpha: 0.5) : AppColors.green,
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
            : const Text('Start Premium',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
      ),
    );
  }

  Widget _activeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.greenDim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text("You're Premium. Guest join is unlocked.",
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: TC.text(context))),
          ),
        ],
      ),
    );
  }
}
