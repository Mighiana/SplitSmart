import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';

class CurrenciesTab extends StatefulWidget {
  final bool isGroupMode;
  final bool showBack;
  const CurrenciesTab({super.key, this.isGroupMode = true, this.showBack = false});

  @override
  State<CurrenciesTab> createState() => _CurrenciesTabState();
}

class _CurrenciesTabState extends State<CurrenciesTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final wallets = context.select<AppState, Map<String, double>>(
        (s) => widget.isGroupMode ? s.groupWallets : s.wallets);
    final state = context.read<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _search.isEmpty
        ? AppState.currencies
        : AppState.currencies
            .where((c) =>
                c.code.toLowerCase().contains(_search.toLowerCase()) ||
                c.name.toLowerCase().contains(_search.toLowerCase()) ||
                c.sym.contains(_search))
            .toList();

    return Material(
      color: TC.bg(context),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Premium Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showBack) ...[
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: TC.card(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TC.border(context)),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: TC.text(context), size: 14),
                      ),
                    ),
                  ],
                  Text(
                    widget.isGroupMode ? 'GLOBAL CURRENCIES' : 'PERSONAL ACCOUNTS',
                    style: TC.geist(
                      context,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: TC.primary(context),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isGroupMode ? 'Currencies' : 'Accounts',
                    style: TC.gloock(
                      context,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: TC.text(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  TextField(
                    style: TC.geist(context, fontSize: 15, color: TC.text(context)),
                    decoration: InputDecoration(
                      hintText: '🔍  Search currency...',
                      hintStyle: TC.geist(context, color: TC.text3(context)),
                      filled: true,
                      fillColor: TC.card(context),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: TC.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: TC.border(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: TC.primary(context), width: 2),
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Currency list ─────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                physics: const BouncingScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  final hasWallet = wallets.containsKey(c.code);
                  final balance = widget.isGroupMode
                      ? (state.groupWallets[c.code] ?? 0)
                      : (state.wallets[c.code] ?? 0);

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (hasWallet) {
                        _showManageSheet(
                            context, state, c, balance, widget.isGroupMode);
                      } else {
                        if (widget.isGroupMode) {
                          state.createGroupWallet(c.code, 0);
                        } else {
                          state.createWallet(c.code, 0);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: TC.primary(context),
                            content: Text(
                              '${c.flag} ${c.code} added to ${widget.isGroupMode ? "groups" : "personal"}!',
                              style: TC.geist(context, color: Colors.white, fontWeight: FontWeight.w600),
                            )));
                        AnalyticsService.logCurrencyWalletCreated(c.code);
                      }
                    },
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      _showManageSheet(
                          context, state, c, balance, widget.isGroupMode);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: hasWallet
                            ? TC.primary(context).withValues(alpha: isDark ? 0.08 : 0.05)
                            : TC.card(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasWallet
                              ? TC.primary(context).withValues(alpha: 0.3)
                              : TC.border(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Flag
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child:
                                Text(c.flag, style: const TextStyle(fontSize: 24)),
                          ),
                          const SizedBox(width: 14),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.code,
                                    style: TC.geist(context,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: TC.text(context))),
                                Text(c.name,
                                    style: TC.geist(context,
                                        fontSize: 12,
                                        color: TC.text2(context))),
                              ],
                            ),
                          ),
                          // Balance chip
                          if (hasWallet)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: balance >= 0
                                    ? TC.okPale(context)
                                    : TC.erPale(context),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${c.sym}${AppCurrencyUtils.formatAmount(balance.abs(), 0)}',
                                style: TC.gloock(
                                  context,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: balance >= 0
                                      ? TC.ok(context)
                                      : TC.er(context),
                                ),
                              ),
                            ),
                          // Symbol
                          Text(c.sym,
                              style: TC.gloock(context,
                                  fontWeight: FontWeight.w900,
                                  color: hasWallet
                                      ? TC.primary(context)
                                      : TC.text3(context),
                                  fontSize: 18)),
                        ],
                      ),
                    ),
                  ).animate().fade(duration: 250.ms, delay: Duration(milliseconds: 30 * (i < 15 ? i : 15))).slideX(begin: 0.05, end: 0, curve: Curves.easeOut);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Manage wallet sheet ──────────────────────────────────────────────────
  void _showManageSheet(BuildContext context, AppState state, CurrencyData c,
      double balance, bool isGroupMode) {
    final hasWallet = isGroupMode
        ? state.groupWallets.containsKey(c.code)
        : state.wallets.containsKey(c.code);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: TC.border(ctx),
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),

              // Currency identity row
              Row(
                children: [
                  Text(c.flag, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.code,
                            style: TC.geist(ctx,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: TC.text(ctx))),
                        Text(c.name,
                            style: TC.geist(ctx,
                                fontSize: 13, color: TC.text2(ctx))),
                      ],
                    ),
                  ),
                  // Symbol badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasWallet ? TC.primaryPale(ctx) : TC.card(ctx),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: hasWallet
                              ? TC.primary(ctx).withValues(alpha: 0.4)
                              : TC.border(ctx)),
                    ),
                    child: Text(c.sym,
                        style: TC.gloock(ctx,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: hasWallet
                                ? TC.primary(ctx)
                                : TC.text(ctx))),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Status info card
              if (hasWallet) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: balance >= 0 ? TC.okPale(ctx) : TC.erPale(ctx),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: (balance >= 0 ? TC.ok(ctx) : TC.er(ctx)).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Text('🌍', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Currency Active',
                                style: TC.geist(ctx,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: balance >= 0 ? TC.ok(ctx) : TC.er(ctx))),
                            Text(
                              'Net Balance: ${balance >= 0 ? '+' : '-'}${c.sym}${AppCurrencyUtils.formatAmount(balance.abs(), 2)}',
                              style: TC.gloock(ctx,
                                  fontSize: 12, color: balance >= 0 ? TC.ok(ctx) : TC.er(ctx)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: TC.card(ctx),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TC.border(ctx)),
                  ),
                  child: Row(
                    children: [
                      const Text('🌍', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add ${c.code} to your active currencies.',
                          style: TC.geist(ctx, fontSize: 12, color: TC.text2(ctx)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Primary action
              if (!hasWallet)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (isGroupMode) {
                      state.createGroupWallet(c.code, 0);
                    } else {
                      state.createWallet(c.code, 0);
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: TC.primary(context),
                        content: Text(
                            '${c.flag} ${c.code} added to ${isGroupMode ? "groups" : "personal accounts"}!',
                            style: TC.geist(context, color: Colors.white, fontWeight: FontWeight.w600))));
                    AnalyticsService.logCurrencyWalletCreated(c.code);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                        color: TC.primary(ctx),
                        borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text('＋  Add Currency',
                        style: TC.geist(ctx,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),
                ),

              // Remove wallet
              if (hasWallet) ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(ctx);
                    _confirmDelete(context, state, c, isGroupMode);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                        color: TC.erPale(ctx),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: TC.er(ctx).withValues(alpha: 0.3))),
                    alignment: Alignment.center,
                    child: Text('🗑  Remove Wallet',
                        style: TC.geist(ctx,
                            color: TC.er(ctx),
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppState state, CurrencyData c, bool isGroupMode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TC.card(ctx),
        title: Text('Remove ${c.code}?',
            style: TC.geist(ctx,
                fontWeight: FontWeight.w700, color: TC.text(ctx))),
        content: Text(
            'This removes the currency from your ${isGroupMode ? 'groups' : 'personal accounts'} list. Existing records are kept.',
            style: TC.geist(ctx, color: TC.text2(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TC.geist(ctx, color: TC.text2(ctx))),
          ),
          TextButton(
            onPressed: () {
              if (isGroupMode) {
                state.deleteGroupWallet(c.code);
              } else {
                state.deleteWallet(c.code);
              }
              Navigator.pop(ctx);
            },
            child: Text('Remove',
                style: TC.geist(ctx, color: TC.er(ctx), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
