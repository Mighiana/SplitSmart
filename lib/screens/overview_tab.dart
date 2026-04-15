import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_state.dart';
import '../main.dart';
import '../utils/app_utils.dart';
import '../services/export_service.dart';
import 'group_detail_screen.dart';
import 'new_group_screen.dart';
import 'transaction_type_screen.dart';
import 'settings_screen.dart';
import 'personal_charts_screen.dart';
import 'personal_transactions_screen.dart';
import 'budget_screen.dart';
import 'currencies_tab.dart';
import 'groups_screen.dart';
import '../widgets/app_drawer.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  String? _selectedCurrency;
  String _spendPeriod = 'month'; // 'day', 'week', 'month', 'year'

  bool _showTip = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 17) return 'Good afternoon 🌤️';
    return 'Good evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDark;
    final activeGroups = state.activeGroups;

    // 1. Wallets logic
    final netBalanceByCur = <String, double>{};
    final groupCountByCur = <String, int>{};
    for (final g in activeGroups) {
      final bal = state.getMyBalance(g);
      netBalanceByCur[g.currency] = (netBalanceByCur[g.currency] ?? 0) + bal;
      groupCountByCur[g.currency] = (groupCountByCur[g.currency] ?? 0) + 1;
    }
    final List<MapEntry<String, double>> walletEntries = netBalanceByCur.entries.toList()
      ..sort((a,b) => b.value.abs().compareTo(a.value.abs()));

    // 2. Who owes you logic
    final List<_BalItem> owedItems = [];
    final List<_BalItem> oweItems = [];
    for (final g in activeGroups) {
      final plan = state.buildSettlePlan(g);
      for (final p in plan) {
        if (p.to == 'You') owedItems.add(_BalItem(g.name, g.emoji, p.from, p.amount, g.sym, g.currency));
        else if (p.from == 'You') oweItems.add(_BalItem(g.name, g.emoji, p.to, p.amount, g.sym, g.currency));
      }
    }
    owedItems.sort((a, b) => b.amount.compareTo(a.amount));
    oweItems.sort((a, b) => b.amount.compareTo(a.amount));

    // Group totals by currency to avoid mixing different currencies
    String _buildCurrencyTotal(List<_BalItem> items) {
      final byCur = <String, double>{};
      for (final i in items) {
        byCur[i.currency] = (byCur[i.currency] ?? 0) + i.amount;
      }
      if (byCur.isEmpty) return '';
      if (byCur.length == 1) {
        final e = byCur.entries.first;
        final sym = items.firstWhere((i) => i.currency == e.key).sym;
        return '$sym${AppCurrencyUtils.formatAmount(e.value, 0)} total';
      }
      // Multiple currencies — show each
      return byCur.entries.map((e) {
        final sym = items.firstWhere((i) => i.currency == e.key).sym;
        return '$sym${AppCurrencyUtils.formatAmount(e.value, 0)}';
      }).join(' + ');
    }
    final owedTotal = _buildCurrencyTotal(owedItems);
    final oweTotal = _buildCurrencyTotal(oweItems);

    // Initial Currency selection - Prioritize group-related currencies
    if (_selectedCurrency == null) {
      if (activeGroups.isNotEmpty) {
        _selectedCurrency = activeGroups.first.currency;
      } else if (state.groupWallets.isNotEmpty) {
        _selectedCurrency = state.groupWallets.keys.first;
      } else if (state.transactions.isNotEmpty) {
        // Only pick from transactions if it's a group share
        final groupTx = state.transactions.where((t) => t.isGroupShare).toList();
        if (groupTx.isNotEmpty) {
          _selectedCurrency = groupTx.first.currency;
        } else {
          _selectedCurrency = 'EUR';
        }
      } else {
        _selectedCurrency = 'EUR';
      }
    }

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            const SizedBox(height: 16),
            // Greeting header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AppDrawer(),
                      );
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: TC.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TC.border(context)),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.menu_rounded, color: TC.text(context), size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting().toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green, letterSpacing: 2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Home 🏠',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: TC.text(context), letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: TC.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TC.border(context)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      alignment: Alignment.center,
                      child: const Text('⚙️', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Your balances
            _buildSectionHeader('GLOBAL BALANCES', 'View all', () => _showAllWalletsSheet(context, walletEntries, groupCountByCur, isDark), isDark),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                   colors: [AppColors.green.withValues(alpha: 0.15), Colors.transparent],
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.2), width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    right: -20, top: -20,
                    child: Container(
                       width: 120, height: 120,
                       decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                             colors: [AppColors.green.withValues(alpha: 0.08), Colors.transparent],
                          ),
                       ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Text('AVAILABLE CAPITAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: TC.text3(context), letterSpacing: 1.2)),
                             Icon(Icons.account_balance_wallet_rounded, color: AppColors.green, size: 16),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (walletEntries.isEmpty) 
                           Text('No active balances.\nCreate a group to see your net worth.', style: TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w600, color: TC.text2(context)))
                        else ...[
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: walletEntries.length > 2 ? 2 : walletEntries.length,
                            itemBuilder: (ctx, i) => _buildWalletRow(walletEntries[i].key, walletEntries[i].value, groupCountByCur[walletEntries[i].key]!, isDark),
                          ),
                          if (walletEntries.length > 2)
                             Padding(
                               padding: const EdgeInsets.only(top: 12),
                               child: Text('+ ${walletEntries.length - 2} other currencies', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
                             ),
                        ],
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () {
                             HapticFeedback.lightImpact();
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: CurrenciesTab())));
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                               color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                               borderRadius: BorderRadius.circular(16),
                               border: Border.all(color: TC.border(context).withValues(alpha: 0.5)),
                            ),
                            alignment: Alignment.center,
                            child: Text('＋ Manage Wallets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: TC.text(context))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 600.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            // Who owes you
            _buildSectionHeader('DEBT MONITOR', 'Analytics ›', () => _showAllOwesSheet(context, owedItems, oweItems, isDark), isDark),
            Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.greenDim.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('COLLECTABLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.green, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        if (owedItems.isEmpty)
                          Text('Clean slate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TC.text3(context)))
                        else ...[
                          Text(owedTotal, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: TC.text(context))),
                          const SizedBox(height: 12),
                          for (int i=0; i < (owedItems.length > 2 ? 2 : owedItems.length); i++)
                            _buildOweRow(owedItems[i], isDark, true),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.redDim.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PAYABLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.red, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        if (oweItems.isEmpty)
                          Text('All settled', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TC.text3(context)))
                        else ...[
                          Text(oweTotal, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: TC.text(context))),
                          const SizedBox(height: 12),
                          for (int i=0; i < (oweItems.length > 2 ? 2 : oweItems.length); i++)
                            _buildOweRow(oweItems[i], isDark, false),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ).animate().fade(delay: 200.ms).slideX(begin: -0.1, end: 0, curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            // This month's spending
            _buildSpendSection(state, isDark).animate().fade().slideY(begin: 0.1, end: 0, delay: 300.ms, duration: 400.ms),

            const SizedBox(height: 24),

            // Your groups
            _buildSectionHeader('Your groups', 'See all ›', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsTab())), isDark),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: TC.card(context), border: Border.all(color: TC.border(context)),
                borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: TC.shadow(context), blurRadius: 12, offset: const Offset(0,2))],
              ),
              child: Column(
                children: [
                   if (activeGroups.isEmpty)
                     const Padding(padding: EdgeInsets.all(20), child: Text('No groups yet.')),
                   for (int i=0; i < (activeGroups.length > 3 ? 3 : activeGroups.length); i++) ...[
                     _buildGroupRow(activeGroups[i], state, isDark),
                     if (i < math.min(activeGroups.length - 1, 2))
                       Container(height: 1, color: TC.border(context), margin: const EdgeInsets.symmetric(horizontal: 12)),
                   ]
                ],
              ),
            ).animate().fade().slideY(begin: 0.1, end: 0, delay: 400.ms, duration: 400.ms),

            const SizedBox(height: 24),

            // Quick actions
            Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16),
               child: Text('Quick actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(context))),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                   Expanded(child: _buildQaItem('➕', 'Add expense', AppColors.greenDim, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionTypeScreen())))),
                   const SizedBox(width: 8),
                   Expanded(child: _buildQaItem('👥', 'New group', AppColors.blueDim, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewGroupScreen())))),
                   const SizedBox(width: 8),
                   Expanded(child: _buildQaItem('🎯', 'Budget', const Color(0xFFb388ff).withValues(alpha: 0.1), isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen())))),
                   const SizedBox(width: 8),
                   Expanded(child: _buildQaItem('📤', 'Export', const Color(0xFFff9f43).withValues(alpha: 0.1), isDark, () {
                      HapticFeedback.lightImpact();
                      ExportService.exportAndSharePdf(state, context);
                   })),
                ],
              ),
            ).animate().fade().slideY(begin: 0.1, end: 0, delay: 500.ms, duration: 400.ms),

            const SizedBox(height: 24),

            if (_showTip)
              Container(
                 margin: const EdgeInsets.symmetric(horizontal: 16),
                 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                 decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: TC.border(context)), boxShadow: [BoxShadow(color: TC.shadow(context), blurRadius: 12, offset: const Offset(0,2))]),
                 child: Row(
                   children: [
                     const Text('💡', style: TextStyle(fontSize: 18)),
                     const SizedBox(width: 10),
                     Expanded(child: Text('Long press any item to edit or archive', style: TextStyle(fontSize: 12, color: TC.text2(context)))),
                     GestureDetector(
                       onTap: () => setState(() => _showTip = false),
                       child: Padding(padding: const EdgeInsets.all(4), child: Text('✕', style: TextStyle(fontSize: 16, color: TC.text3(context)))),
                     ),
                   ],
                 ),
              ).animate().fade().slideY(begin: 0.1, end: 0, delay: 600.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(context))),
          GestureDetector(onTap: onTap, child: Text(action, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green))),
        ],
      ),
    );
  }

  Widget _buildWalletRow(String code, double bal, int groupCount, bool isDark) {
    final cData = AppState.currencies.firstWhere((c) => c.code == code, orElse: () => CurrencyData(code, '', '🌐', '\$'));
    final isPos = bal >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(cData.flag, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(code, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TC.text(context))),
                 Text('$groupCount group${groupCount > 1 ? 's' : ''}', style: TextStyle(fontSize: 10, color: TC.text3(context))),
               ],
            ),
          ),
          Column(
             crossAxisAlignment: CrossAxisAlignment.end,
             children: [
                Text('${isPos ? '+' : '−'}${cData.sym}${AppCurrencyUtils.formatAmount(bal.abs())}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isPos ? AppColors.green : AppColors.red)),
                Text(isPos ? 'owed to you' : 'you owe', style: TextStyle(fontSize: 10, color: isPos ? AppColors.green : AppColors.red)),
             ],
          ),
          const SizedBox(width: 4),
          Text('›', style: TextStyle(fontSize: 14, color: TC.text3(context))),
        ],
      ),
    );
  }

  Widget _buildOweRow(_BalItem item, bool isDark, bool isPos) {
    final name = item.person;
    final ini = name.substring(0, math.min(2, name.length)).toUpperCase();
    final cColor = isPos ? AppColors.green : AppColors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28, height: 28, decoration: BoxDecoration(color: isPos ? AppColors.greenDim : AppColors.redDim, shape: BoxShape.circle),
            alignment: Alignment.center, child: Text(ini, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: cColor)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TC.text(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('${isPos ? '+' : '−'}${item.sym}${AppCurrencyUtils.formatAmount(item.amount, 0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cColor)),
          const SizedBox(width: 4),
          Text('›', style: TextStyle(fontSize: 11, color: TC.text3(context))),
        ],
      ),
    );
  }

  Widget _buildSpendSection(AppState state, bool isDark) {
    // Only show group-related transactions on the home dashboard
    final curTxs = state.allTransactionsWithGroupShares
        .where((t) => t.type.toLowerCase() == 'expense' && t.currency != null && t.isGroupShare == true)
        .toList();
        
    final _cursSet = <String>{};
    for (var g in state.activeGroups) _cursSet.add(g.currency);
    for (var t in curTxs) _cursSet.add(t.currency!);
    _cursSet.addAll(state.groupWallets.keys);
    
    final spendCurs = _cursSet.toList();
    if (spendCurs.isEmpty && _selectedCurrency == null) {
      spendCurs.add('EUR');
    }
    if (_selectedCurrency != null && !spendCurs.contains(_selectedCurrency)) {
      spendCurs.insert(0, _selectedCurrency!);
    }

    final now = DateTime.now();
    DateTime start;
    if (_spendPeriod == 'day') start = DateTime(now.year, now.month, now.day);
    else if (_spendPeriod == 'week') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(monday.year, monday.month, monday.day);
    }
    else if (_spendPeriod == 'year') start = DateTime(now.year, 1, 1);
    else start = DateTime(now.year, now.month, 1); // month

    final txs = curTxs.where((t) {
      if (t.currency != _selectedCurrency) return false;
      if (t.rawDate == null || t.rawDate!.isBefore(start)) return false;
      return true;
    }).toList();

    double totalAmt = 0;
    final Map<String, double> catSpent = {};
    for (final t in txs) {
      totalAmt += t.amount;
      catSpent[t.cat] = (catSpent[t.cat] ?? 0) + t.amount;
    }
    final sortedCats = catSpent.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    final curSym = AppState.currencies.firstWhere((c) => c.code == _selectedCurrency, orElse: () => const CurrencyData('', '', '', '\$')).sym;

    String pText = '';
    if (_spendPeriod == 'day') pText = 'Today\'s spending';
    else if (_spendPeriod == 'week') pText = 'This week\'s spending';
    else if (_spendPeriod == 'year') pText = 'This year\'s spending';
    else pText = 'This month\'s spending';

    return Container(
       margin: const EdgeInsets.symmetric(horizontal: 16),
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: TC.border(context)), boxShadow: [BoxShadow(color: TC.shadow(context), blurRadius: 12, offset: const Offset(0,2))]),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Text(pText.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: TC.text3(context), letterSpacing: 1.5, textBaseline: TextBaseline.alphabetic)),
            const SizedBox(height: 2),
            Text('GROUP CURRENCIES — SELECT TO VIEW SPENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: TC.text3(context), letterSpacing: 1.5)),
            const SizedBox(height: 12),
            // Chips
             SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: spendCurs.map((c) {
                   final isActive = c == _selectedCurrency;
                   final cData = AppState.currencies.firstWhere((x) => x.code == c, orElse: () => CurrencyData(c, '', '🌐', '\$'));
                   return GestureDetector(
                     onTap: () {
                       HapticFeedback.selectionClick();
                       setState(() => _selectedCurrency = c);
                     },
                     child: AnimatedContainer(
                       duration: const Duration(milliseconds: 300),
                       margin: const EdgeInsets.only(right: 12, bottom: 4),
                       padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                       decoration: BoxDecoration(
                         color: isActive ? AppColors.green : TC.card2(context),
                         borderRadius: BorderRadius.circular(16),
                         boxShadow: isActive ? [BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
                       ),
                       child: Row(
                         children: [
                           Text(cData.flag, style: const TextStyle(fontSize: 18)),
                           const SizedBox(width: 8),
                           Text(c, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isActive ? Colors.black : TC.text(context))),
                         ],
                       ),
                     ),
                   );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            // Detail Card
            Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(color: TC.card2(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: TC.border(context))),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text('Spending in $_selectedCurrency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: TC.text(context))),
                             const SizedBox(height: 3),
                             Row(
                               children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: AppColors.blueDim, borderRadius: BorderRadius.circular(4)), child: Text('ℹ', style: TextStyle(fontSize: 10, color: AppColors.blue))),
                                  const SizedBox(width: 4),
                                  Text('% breakdown in $_selectedCurrency only', style: TextStyle(fontSize: 11, color: TC.text2(context))),
                               ],
                             ),
                           ],
                         ),
                         Text('${AppDateUtils.monthLabel(now)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TC.text2(context))),
                       ],
                    ),
                    const SizedBox(height: 12),
                    // Tabs
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: TC.border(context))),
                      child: Row(
                        children: ['day', 'week', 'month', 'year'].map((p) {
                           final isActive = p == _spendPeriod;
                           final label = p[0].toUpperCase() + p.substring(1);
                           return Expanded(
                             child: GestureDetector(
                               onTap: () => setState(() => _spendPeriod = p),
                               child: Container(
                                 padding: const EdgeInsets.symmetric(vertical: 8),
                                 decoration: BoxDecoration(
                                    color: isActive ? (isDark ? TC.card2(context) : TC.card(context)) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: isActive && !isDark ? [const BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,1))] : null,
                                 ),
                                 alignment: Alignment.center,
                                 child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w800 : FontWeight.w700, color: isActive ? AppColors.green : TC.text2(context))),
                               ),
                             ),
                           );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Donut + Cats
                    Row(
                       children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                               SizedBox(
                                  width: 130, height: 130,
                                  child: CustomPaint(
                                     painter: _DonutPainter(
                                        slices: sortedCats.isEmpty ? [] : sortedCats.map((e) => _DonutSlice(value: totalAmt > 0 ? e.value / totalAmt : 0, color: _getCatColor(e.key))).toList(),
                                        ringColor: TC.card(context),
                                        bgColor: TC.card2(context),
                                     ),
                                  ),
                               ),
                               Column(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                    Text(curSym, style: TextStyle(fontSize: 12, color: TC.text2(context))),
                                    Text(AppCurrencyUtils.formatAmount(totalAmt, 0), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: TC.text(context), height: 1)),
                                    Text('expenses', style: TextStyle(fontSize: 10, color: TC.text3(context))),
                                 ],
                               ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: sortedCats.isEmpty ? [Text('No expenses in $_spendPeriod', style: TextStyle(fontSize: 12, color: TC.text2(context)))] : [
                                 ...sortedCats.take(4).map((c) {
                                   double pct = totalAmt > 0 ? (c.value / totalAmt * 100) : 0;
                                   Color cc = _getCatColor(c.key);
                                   String catName = AppState.expenseCategories.firstWhere((x) => x.icon == c.key, orElse: () => const CategoryItem('', 'Other', '')).label;
                                   return Padding(
                                     padding: const EdgeInsets.only(bottom: 10),
                                     child: Column(
                                       children: [
                                         Row(
                                           children: [
                                             Container(width: 24, height: 24, decoration: BoxDecoration(color: cc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), alignment: Alignment.center, child: Text(c.key, style: const TextStyle(fontSize: 12))),
                                             const SizedBox(width: 6),
                                             Expanded(child: Text(catName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.text(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                             Column(
                                               crossAxisAlignment: CrossAxisAlignment.end,
                                               children: [
                                                  Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: TC.text2(context))),
                                                  Text('$curSym${AppCurrencyUtils.formatAmount(c.value, 0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: TC.text(context))),
                                               ],
                                             ),
                                           ],
                                         ),
                                         const SizedBox(height: 4),
                                         Padding(
                                            padding: const EdgeInsets.only(left: 30),
                                            child: Container(
                                               height: 3, width: double.infinity,
                                               decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(2)),
                                               alignment: Alignment.centerLeft,
                                               child: LayoutBuilder(builder: (ctx, constraints) {
                                                  double w = (pct / 100) * constraints.maxWidth;
                                                  return Container(height: 3, width: w, decoration: BoxDecoration(color: cc, borderRadius: BorderRadius.circular(2)));
                                               }),
                                            ),
                                         ),
                                       ],
                                     ),
                                   );
                                 }),
                                 if (sortedCats.length > 4)
                                   GestureDetector(
                                     onTap: () => _showAllCategoriesSheet(context, sortedCats, totalAmt, curSym, isDark),
                                     child: Container(
                                       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                       decoration: BoxDecoration(
                                         color: AppColors.greenDim,
                                         borderRadius: BorderRadius.circular(10),
                                         border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                                       ),
                                       child: Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           Text('+${sortedCats.length - 4} more', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TC.greenDark(context))),
                                           const SizedBox(width: 4),
                                           Icon(Icons.expand_more, size: 14, color: TC.greenDark(context)),
                                         ],
                                       ),
                                     ),
                                   ),
                               ],
                            ),
                          ),
                       ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                       children: [
                         Expanded(
                           child: GestureDetector(
                             onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MoneyChartsScreen(initialCurrency: _selectedCurrency))),
                             child: Container(
                               padding: const EdgeInsets.all(10),
                               decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: TC.border(context))),
                               alignment: Alignment.center,
                               child: Text('📊 Charts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.greenDark(context))),
                             ),
                           ),
                         ),
                         const SizedBox(width: 8),
                         Expanded(
                           child: GestureDetector(
                             onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MoneyTransactionsScreen(filterCurrency: _selectedCurrency))),
                             child: Container(
                               padding: const EdgeInsets.all(10),
                               decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: TC.border(context))),
                               alignment: Alignment.center,
                               child: Text('📋 All transactions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TC.greenDark(context))),
                             ),
                           ),
                         ),
                       ],
                    ),
                 ],
               ),
            ),
         ],
       ),
    );
  }

  Widget _buildGroupRow(GroupData g, AppState state, bool isDark) {
     final bal = state.getMyBalance(g);
     final isPos = bal > 0;
     final isNeg = bal < 0;
     final cColor = bal == 0 ? TC.text3(context) : (isPos ? TC.greenDark(context) : AppColors.red);
     final bgCol = bal == 0 ? TC.card2(context) : (isPos ? AppColors.greenDim : AppColors.redDim);
     
     return GestureDetector(
        onTap: () {
            HapticFeedback.lightImpact();
            state.currentGroup = g;
            Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(heroTag: 'hg_${g.id}')));
        },
        child: Container(
           padding: const EdgeInsets.all(12),
           color: Colors.transparent,
           child: Row(
             children: [
               Container(
                 width: 44, height: 44,
                 decoration: BoxDecoration(color: TC.card2(context), borderRadius: BorderRadius.circular(12)),
                 alignment: Alignment.center,
                 child: Text(g.emoji, style: const TextStyle(fontSize: 22)),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(g.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TC.text(context))),
                     Text('${g.members.length} members · ${g.expenses.length} expenses', 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: TC.text2(context))),
                   ],
                 ),
               ),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                 decoration: BoxDecoration(color: bgCol, borderRadius: BorderRadius.circular(20)),
                 child: Text('${isPos ? '+' : ''}${isNeg ? '−' : ''}${g.sym}${AppCurrencyUtils.formatAmount(bal.abs(),0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cColor)),
               ),
               const SizedBox(width: 4),
               Text('›', style: TextStyle(fontSize: 14, color: TC.text3(context))),
             ],
           ),
        ),
     );
  }

  Widget _buildQaItem(String emoji, String lbl, Color bg, bool isDark, VoidCallback onTap) {
      return GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: TC.border(context)), boxShadow: [BoxShadow(color: TC.shadow(context), blurRadius: 12, offset: const Offset(0,2))]),
          child: Column(
             children: [
               Container(width: 40, height: 40, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(emoji, style: const TextStyle(fontSize: 20))),
               const SizedBox(height: 6),
               Text(lbl, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: TC.text2(context)), textAlign: TextAlign.center),
             ],
          ),
        ),
      );
  }

  Color _getCatColor(String cat) {
    return AppState.getCategoryColor(cat);
  }

  void _showAllCategoriesSheet(BuildContext context, List<MapEntry<String, double>> sortedCats, double totalAmt, String curSym, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.card(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('All Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context))),
                    const Spacer(),
                    Text('$curSym${AppCurrencyUtils.formatAmount(totalAmt, 0)} total', style: TextStyle(fontSize: 12, color: TC.text2(context))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedCats.length,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemBuilder: (_, i) {
                    final c = sortedCats[i];
                    final pct = totalAmt > 0 ? (c.value / totalAmt * 100) : 0.0;
                    final cc = _getCatColor(c.key);
                    final catName = AppState.expenseCategories.firstWhere(
                      (x) => x.icon == c.key,
                      orElse: () => const CategoryItem('', 'Other', ''),
                    ).label;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TC.card2(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TC.border(context)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: cc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.center,
                            child: Text(c.key, style: const TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(catName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TC.text(context))),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: (pct / 100).clamp(0.0, 1.0),
                                    backgroundColor: TC.card(context),
                                    valueColor: AlwaysStoppedAnimation(cc),
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cc)),
                              Text('$curSym${AppCurrencyUtils.formatAmount(c.value, 0)}', style: TextStyle(fontSize: 12, color: TC.text2(context))),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showAllWalletsSheet(BuildContext context, List<MapEntry<String, double>> entries, Map<String, int> groupCounts, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.bg(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('YOUR NET BALANCE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: TC.text(context))),
            const SizedBox(height: 16),
            Expanded(
              child: entries.isEmpty
                ? Center(child: Text('No balances', style: TextStyle(color: TC.text2(context))))
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _buildWalletRow(entries[i].key, entries[i].value, groupCounts[entries[i].key] ?? 0, isDark),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllOwesSheet(BuildContext context, List<_BalItem> owed, List<_BalItem> owe, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.bg(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Center(child: Text('Who owes you ❓', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: TC.text(context)))),
            const SizedBox(height: 24),
            Text('You are owed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.green)),
            const SizedBox(height: 8),
            if (owed.isEmpty) Text('Nothing owed', style: TextStyle(color: TC.text2(context))),
            for (var item in owed) _buildOweRow(item, isDark, true),
            const SizedBox(height: 24),
            Text('You owe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.red)),
            const SizedBox(height: 8),
            if (owe.isEmpty) Text('All settled', style: TextStyle(color: TC.text2(context))),
            for (var item in owe) _buildOweRow(item, isDark, false),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _BalItem {
  final String group;
  final String emoji;
  final String person;
  final double amount;
  final String sym;
  final String currency;
  _BalItem(this.group, this.emoji, this.person, this.amount, this.sym, this.currency);
}

class _DonutSlice {
  final double value;
  final Color color;
  _DonutSlice({required this.value, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSlice> slices;
  final Color ringColor;
  final Color bgColor;
  _DonutPainter({required this.slices, required this.ringColor, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round;

    if (slices.isEmpty) {
      paint.color = ringColor;
      canvas.drawArc(rect, 0, 2 * 3.14159, false, paint);
      return;
    }

    double start = -3.14159 / 2;
    for (final s in slices) {
      if (s.value <= 0) continue;
      final sweep = s.value * 2 * 3.14159;
      paint.color = s.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
