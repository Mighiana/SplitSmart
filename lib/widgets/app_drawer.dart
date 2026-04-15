import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../utils/app_utils.dart';
import '../providers/app_state.dart';
import '../screens/personal_charts_screen.dart';
import '../screens/subscriptions_screen.dart';
import '../screens/saving_goals_screen.dart';
import '../screens/reminders_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _DrawerItem(Icons.account_balance_wallet_outlined, 'Accounts', AppColors.green),
      _DrawerItem(Icons.bar_chart_rounded, 'Charts', AppColors.blue),
      _DrawerItem(Icons.repeat_rounded, 'Subscriptions', AppColors.purple),
      _DrawerItem(Icons.notifications_outlined, 'Reminders', AppColors.amber),
      _DrawerItem(Icons.track_changes_outlined, 'Saving Goals', AppColors.red),
    ];

    return Container(
      decoration: BoxDecoration(
        color: TC.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.greenGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  alignment: Alignment.center,
                  child: const Text('💎', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SplitSmart', style: TextStyle(color: TC.text(context), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    Text('Premium Edition', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ...items.map((item) => Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: item.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                title: Text(item.label, style: TextStyle(color: TC.text(context), fontSize: 16, fontWeight: FontWeight.w700)),
                trailing: Icon(Icons.chevron_right_rounded, color: TC.text3(context), size: 18),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  _handleNav(context, item.label);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(color: TC.border(context).withValues(alpha: 0.5), height: 1),
              ),
            ],
          )),
        ],
      ),
    );
  }

  void _handleNav(BuildContext context, String label) {
    Widget? screen;
    if (label == 'Charts') {
      screen = const MoneyChartsScreen();
    } else if (label == 'Subscriptions') {
      screen = const SubscriptionsScreen();
    } else if (label == 'Saving Goals') {
      screen = const SavingGoalsScreen();
    } else if (label == 'Reminders') {
      screen = const RemindersScreen();
    } else if (label == 'Accounts') {
      // Show account management sheet
      _showAccountsSheet(context);
      return;
    }

    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }

  void _showAccountsSheet(BuildContext context) {
    final state = context.read<AppState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final currentWallets = state.wallets;
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, ctrl) => Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: TC.border(ctx),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.green, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: TC.text(ctx))),
                            Text('${currentWallets.length} active accounts', style: TextStyle(fontSize: 12, color: TC.text2(ctx), fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(ctx);
                            _showAddAccountSheet(context, state);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppColors.greenGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, color: Colors.black, size: 18),
                                SizedBox(width: 4),
                                Text('ADD', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: currentWallets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('💳', style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text('No accounts yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: TC.text(ctx))),
                                const SizedBox(height: 4),
                                Text('Tap + to create your first account', style: TextStyle(fontSize: 13, color: TC.text2(ctx))),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: ctrl,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: currentWallets.length,
                            itemBuilder: (_, i) {
                              final code = currentWallets.keys.elementAt(i);
                              final balance = currentWallets[code] ?? 0;
                              final curData = AppState.currencies.firstWhere(
                                (c) => c.code == code,
                                orElse: () => CurrencyData(code, code, '\$', code),
                              );
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: TC.card(ctx),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: TC.border(ctx)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: Theme.of(ctx).brightness == Brightness.dark ? 0.2 : 0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48, height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(curData.flag, style: const TextStyle(fontSize: 24)),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(code, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: TC.text(ctx))),
                                          Text(curData.name, style: TextStyle(fontSize: 12, color: TC.text2(ctx))),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${curData.sym}${AppCurrencyUtils.formatAmount(balance.abs(), 2)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: balance >= 0 ? AppColors.green : AppColors.red,
                                          ),
                                        ),
                                        Text(
                                          balance >= 0 ? 'Balance' : 'Deficit',
                                          style: TextStyle(fontSize: 10, color: TC.text3(ctx), fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddAccountSheet(BuildContext context, AppState state) {
    final existingCodes = state.wallets.keys.toSet();
    final available = AppState.currencies
        .where((c) => !existingCodes.contains(c.code))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: TC.border(ctx), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: TC.text(ctx))),
                  const SizedBox(height: 4),
                  Text('Select a currency to create a new personal account', style: TextStyle(fontSize: 13, color: TC.text2(ctx))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: available.length,
                itemBuilder: (_, i) {
                  final c = available[i];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      state.createWallet(c.code, 0);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${c.flag} ${c.code} account created!')),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: TC.card(ctx),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TC.border(ctx)),
                      ),
                      child: Row(
                        children: [
                          Text(c.flag, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.code, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: TC.text(ctx))),
                                Text(c.name, style: TextStyle(fontSize: 12, color: TC.text2(ctx))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AppColors.greenGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('CREATE', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String label;
  final Color color;
  const _DrawerItem(this.icon, this.label, this.color);
}
