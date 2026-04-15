import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  String _period = 'monthly';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _period = prefs.getString('budget_period') ?? 'monthly';
      _isLoading = false;
    });
  }

  Future<void> _setPeriod(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('budget_period', val);
    setState(() => _period = val);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold();

    final state = context.watch<AppState>();
    
    // Calculate global spent per currency
    final Map<String, double> curSpent = {};
    final now = DateTime.now();
    DateTime start = _period == 'weekly' 
        ? now.subtract(Duration(days: now.weekday - 1)) 
        : DateTime(now.year, now.month, 1);
        
    for (var t in state.allTransactionsWithGroupShares) {
      if (t.type.toLowerCase() == 'expense' && t.rawDate != null && !t.rawDate!.isBefore(start)) {
        curSpent[t.currency] = (curSpent[t.currency] ?? 0) + t.amount;
      }
    }

    final activeCurs = <String>{};
    activeCurs.addAll(curSpent.keys);
    activeCurs.addAll(state.wallets.keys);
    for (final g in state.activeGroups) activeCurs.add(g.currency);
    for (final c in AppState.currencies) {
      if (state.getBudgetLimit('all', c.code) > 0) activeCurs.add(c.code);
    }
    
    if (activeCurs.isEmpty && state.transactions.isNotEmpty) {
      activeCurs.add(state.transactions.first.currency);
    } else if (activeCurs.isEmpty) {
      activeCurs.add('EUR');
    }

    int totalBudgeted = 0;
    int onTrack = 0;
    int overBudget = 0;
    
    final curItems = <Widget>[];

    for (final code in activeCurs) {
      final cData = AppState.currencies.firstWhere((c) => c.code == code, orElse: () => CurrencyData(code, '', '🌐', '\$'));
      double spent = curSpent[code] ?? 0;
      double monthlyLimit = state.getBudgetLimit('all', code);
      double limit = _period == 'weekly' && monthlyLimit > 0 ? monthlyLimit / 4.0 : monthlyLimit;
      
      bool hasLimit = limit > 0;
      if (hasLimit) totalBudgeted++;

      if (!hasLimit) {
        curItems.add(
          GestureDetector(
             onTap: () => _openNumpad(context, code, cData.sym, limit, _period),
             child: Container(
               margin: const EdgeInsets.only(bottom: 12),
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: TC.card(context),
                 borderRadius: BorderRadius.circular(14),
                 border: Border.all(color: TC.border(context)),
               ),
               child: Row(
                 children: [
                    Text(cData.flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(code, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TC.text(context))),
                          Text('No budget set · ${cData.sym}${AppCurrencyUtils.formatAmount(spent, 0)} spent', style: TextStyle(fontSize: 11, color: TC.text2(context))),
                        ],
                      ),
                    ),
                    Text('+ Set limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
                 ],
               ),
             ),
          ),
        );
      } else {
        double pct = spent / limit * 100;
        if (pct > 100) overBudget++;
        else onTrack++;
        
        Color barColor = pct >= 100 ? AppColors.red : (pct >= 80 ? Colors.orange : AppColors.green);
        String status = pct >= 100 ? '⚠️ Over budget' : (pct >= 80 ? '⚡ Almost there' : '✓ On track');
        
        curItems.add(
          GestureDetector(
             onTap: () => _openNumpad(context, code, cData.sym, limit, _period),
             child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TC.card(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TC.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(cData.flag, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(code, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TC.text(context))),
                              Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: barColor)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                             Text('${cData.sym}${AppCurrencyUtils.formatAmount(spent, 0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: TC.text(context))),
                             Text('of ${cData.sym}${AppCurrencyUtils.formatAmount(limit, 0)}', style: TextStyle(fontSize: 10, color: TC.text2(context))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 8, width: double.infinity,
                      decoration: BoxDecoration(color: TC.card2(context), borderRadius: BorderRadius.circular(4)),
                      alignment: Alignment.centerLeft,
                      child: LayoutBuilder(builder: (ctx, constraints) {
                        double w = (pct / 100) * constraints.maxWidth;
                        if (w > constraints.maxWidth) w = constraints.maxWidth;
                        return Container(
                          height: 8, width: w,
                          decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4)),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${pct.toStringAsFixed(0)}% used', style: TextStyle(fontSize: 10, color: TC.text3(context))),
                        Text('Tap to edit', style: TextStyle(fontSize: 10, color: TC.text3(context))),
                      ],
                    ),
                  ],
                ),
             ),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: TC.bg(context),
      appBar: AppBar(
        backgroundColor: TC.bg(context),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: TC.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Budget Settings', style: TextStyle(color: TC.text(context), fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
             Text('Budget resets every', style: TextStyle(fontSize: 12, color: TC.text2(context))),
             const SizedBox(height: 8),
             Container(
               padding: const EdgeInsets.all(4),
               decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: TC.border(context))),
               child: Row(
                 children: [
                   Expanded(
                     child: GestureDetector(
                       onTap: () => _setPeriod('weekly'),
                       child: Container(
                         padding: const EdgeInsets.symmetric(vertical: 10),
                         decoration: BoxDecoration(color: _period == 'weekly' ? TC.card2(context) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                         alignment: Alignment.center,
                         child: Text('📅 Weekly', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _period == 'weekly' ? AppColors.green : TC.text2(context))),
                       ),
                     ),
                   ),
                   Expanded(
                     child: GestureDetector(
                       onTap: () => _setPeriod('monthly'),
                       child: Container(
                         padding: const EdgeInsets.symmetric(vertical: 10),
                         decoration: BoxDecoration(color: _period == 'monthly' ? TC.card2(context) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                         alignment: Alignment.center,
                         child: Text('🗓 Monthly', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _period == 'monthly' ? AppColors.green : TC.text2(context))),
                       ),
                     ),
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 8),
             Text(
               _period == 'weekly' ? 'Resets every Monday at midnight' : 'Resets on the 1st of every month',
               style: TextStyle(fontSize: 11, color: TC.text3(context)),
             ),
             const SizedBox(height: 24),
             
             Row(
               children: [
                 Expanded(
                   child: Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: TC.border(context))),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text('With budget', style: TextStyle(fontSize: 10, color: TC.text3(context))),
                         Text('$totalBudgeted of ${activeCurs.length}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: TC.text(context))),
                       ],
                     ),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: TC.border(context))),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text('On track', style: TextStyle(fontSize: 10, color: TC.text3(context))),
                         Text('$onTrack', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.green)),
                       ],
                     ),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: TC.border(context))),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text('Over budget', style: TextStyle(fontSize: 10, color: TC.text3(context))),
                         Text('$overBudget', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.red)),
                       ],
                     ),
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 24),
             
             ...curItems,
          ],
        ),
      ),
    );
  }

  void _openNumpad(BuildContext context, String code, String sym, double currentLimit, String period) {
     showModalBottomSheet(
        context: context, 
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
           return _NumpadSheet(
             currency: code, 
             sym: sym, 
             initialVal: currentLimit,
             period: period,
           );
        }
     );
  }
}

class _NumpadSheet extends StatefulWidget {
  final String currency;
  final String sym;
  final double initialVal;
  final String period;
  
  const _NumpadSheet({required this.currency, required this.sym, required this.initialVal, required this.period});

  @override
  State<_NumpadSheet> createState() => _NumpadSheetState();
}

class _NumpadSheetState extends State<_NumpadSheet> {
  String _valStr = '0';

  @override
  void initState() {
    super.initState();
    if (widget.initialVal > 0) {
      _valStr = widget.initialVal.toStringAsFixed(0);
    }
  }

  void _input(String k) {
    HapticFeedback.lightImpact();
    setState(() {
      if (k == 'del') {
        if (_valStr.length > 1) _valStr = _valStr.substring(0, _valStr.length - 1);
        else _valStr = '0';
      } else if (k == '.') {
        // Only allow one decimal point
        if (!_valStr.contains('.')) {
          _valStr += '.';
        }
      } else {
        if (_valStr == '0') _valStr = k;
        else _valStr += k;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    return Container(
       padding: const EdgeInsets.all(24),
       decoration: BoxDecoration(
         color: TC.card(context),
         borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
       ),
       child: SafeArea(
         top: false,
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Container(width: 40, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 24)),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('Set ${widget.currency} budget', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: TC.text(context))),
                     Text(widget.period == 'weekly' ? 'Weekly limit' : 'Monthly limit', style: TextStyle(fontSize: 12, color: TC.text2(context))),
                   ],
                 ),
                 GestureDetector(
                   onTap: () {
                     HapticFeedback.lightImpact();
                     state.setBudgetLimit('all', widget.currency, 0);
                     Navigator.pop(context);
                   },
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                     decoration: BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(20)),
                     child: const Text('Remove limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.red)),
                   ),
                 ),
               ],
             ),
             Container(
               padding: const EdgeInsets.symmetric(vertical: 32),
               alignment: Alignment.center,
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Text(widget.sym, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: TC.text2(context))),
                   const SizedBox(width: 4),
                   Text(_valStr, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: TC.text(context))),
                 ],
               ),
             ),
             GridView.count(
               crossAxisCount: 3,
               shrinkWrap: true,
               physics: const NeverScrollableScrollPhysics(),
               childAspectRatio: 1.8,
               mainAxisSpacing: 8,
               crossAxisSpacing: 8,
               children: [
                  for (final i in ['1','2','3','4','5','6','7','8','9','.','0','del'])
                    GestureDetector(
                       onTap: () => _input(i),
                       child: Container(
                         decoration: BoxDecoration(color: TC.card2(context), borderRadius: BorderRadius.circular(16)),
                         alignment: Alignment.center,
                         child: i == 'del' ? Icon(Icons.backspace, color: TC.text(context)) 
                                           : Text(i, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: TC.text(context))),
                       ),
                    ),
               ],
             ),
             const SizedBox(height: 24),
             GestureDetector(
               onTap: () {
                 HapticFeedback.lightImpact();
                 double v = double.tryParse(_valStr) ?? 0;
                 if (v > 0) {
                    double monthlyLimit = widget.period == 'weekly' ? v * 4 : v;
                    state.setBudgetLimit('all', widget.currency, monthlyLimit);
                    AnalyticsService.logBudgetSet(widget.period);
                 }
                 Navigator.pop(context);
               },
               child: Container(
                 width: double.infinity,
                 padding: const EdgeInsets.symmetric(vertical: 16),
                 decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(16)),
                 alignment: Alignment.center,
                 child: const Text('Save Budget →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
               ),
             ),
             const SizedBox(height: 16),
           ],
         ),
       ),
    );
  }
}
