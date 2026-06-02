import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import '../services/analytics_service.dart';
import 'goal_detail_screen.dart';

class SavingGoalsScreen extends StatefulWidget {
  final String? initialCurrency;
  const SavingGoalsScreen({super.key, this.initialCurrency});

  @override
  State<SavingGoalsScreen> createState() => _SavingGoalsScreenState();
}

class _SavingGoalsScreenState extends State<SavingGoalsScreen> {
  String? _selectedCurrency;
  String _filter = 'All'; // All | On Track | Needs Push
  late ConfettiController _confettiController;

  // Per-goal accent palette (SavingGoal has no colour field).
  static const _palette = [
    Color(0xFF3B82F6), // blue
    Color(0xFFD97706), // amber
    Color(0xFF059669), // green
    Color(0xFF8B5CF6), // purple
    Color(0xFFE85A6A), // red
  ];

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.initialCurrency;
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Color _goalColor(SavingGoal g) => _palette[g.id % _palette.length];

  String _money(String code, double amt) {
    final sym = AppState.currencies
        .firstWhere((c) => c.code == code,
            orElse: () => CurrencyData(code, code, '💰', code))
        .sym;
    return '$sym${AppCurrencyUtils.formatAmount(amt, 0)}';
  }

  String _emojiFor(String t) {
    final lower = t.toLowerCase();
    if (lower.contains('car') || lower.contains('vehicle')) return '🚗';
    if (lower.contains('home') || lower.contains('house')) return '🏠';
    if (lower.contains('vacation') || lower.contains('trip') || lower.contains('travel') || lower.contains('japan') || lower.contains('italy')) return '✈️';
    if (lower.contains('emergency')) return '🏦';
    if (lower.contains('macbook') || lower.contains('laptop') || lower.contains('pc') || lower.contains('computer')) return '💻';
    if (lower.contains('ps5') || lower.contains('xbox') || lower.contains('game') || lower.contains('console')) return '🎮';
    if (lower.contains('gadget') || lower.contains('tech') || lower.contains('phone')) return '📱';
    return '🎯';
  }


  String _deadlineLabel(SavingGoal g) =>
      g.targetDate != null ? DateFormat('MMM yyyy').format(g.targetDate!) : 'No date';

  // ─── Add / Edit goal sheet ────────────────────────────────────────────────
  void _showAddGoalSheet(BuildContext context, AppState state, [SavingGoal? existing]) {
    final curController = TextEditingController(text: existing?.currency ?? _selectedCurrency ?? state.wallets.keys.firstOrNull ?? 'USD');
    final titleController = TextEditingController(text: existing?.title ?? '');
    final targetController = TextEditingController(text: existing?.targetAmount.toString() ?? '');
    final savedController = TextEditingController(text: existing?.savedAmount.toString() ?? '');
    DateTime? localTargetDate = existing?.targetDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(existing == null ? 'Add Saving Goal' : 'Edit Saving Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context))),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      autofocus: existing == null,
                      style: TextStyle(color: TC.text(context)),
                      decoration: InputDecoration(
                        labelText: 'Goal Title (e.g., New Car)',
                        labelStyle: TextStyle(color: TC.text3(context)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TC.border(context))),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: curController,
                      style: TextStyle(color: TC.text(context)),
                      decoration: InputDecoration(
                        labelText: 'Currency Code (e.g., USD)',
                        labelStyle: TextStyle(color: TC.text3(context)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TC.border(context))),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: TC.text(context)),
                      decoration: InputDecoration(
                        labelText: 'Target Amount',
                        labelStyle: TextStyle(color: TC.text3(context)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TC.border(context))),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final dt = await showDatePicker(
                          context: context,
                          initialDate: localTargetDate ?? DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 36500)),
                        );
                        if (dt != null) {
                          setModalState(() => localTargetDate = dt);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: TC.border(context))),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: TC.text3(context), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              localTargetDate != null
                                ? 'Target Date: ${localTargetDate!.day.toString().padLeft(2,'0')}.${localTargetDate!.month.toString().padLeft(2,'0')}.${localTargetDate!.year}'
                                : 'Select Target Date (Optional)',
                              style: TextStyle(color: localTargetDate != null ? TC.text(context) : TC.text3(context), fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (existing != null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: savedController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: TC.text(context)),
                        decoration: InputDecoration(
                          labelText: 'Currently Saved',
                          labelStyle: TextStyle(color: TC.text3(context)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TC.border(context))),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        final targetStr = targetController.text.replaceAll(',', '');
                        final savedStr = savedController.text.replaceAll(',', '');
                        final target = double.tryParse(targetStr) ?? 0;
                        final saved = savedStr.isEmpty
                            ? (existing?.savedAmount ?? 0)
                            : (double.tryParse(savedStr) ?? existing?.savedAmount ?? 0);
                        final title = titleController.text.trim();
                        final cur = curController.text.trim().toUpperCase();

                        if (title.isEmpty || cur.isEmpty || target <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields accurately.')));
                          return;
                        }

                        if (existing == null) {
                          state.addSavingGoal(cur, title, target, targetDate: localTargetDate);
                          AnalyticsService.logSavingGoalAdded();
                        } else {
                          state.updateSavingGoal(existing, title: title, targetAmount: target, savedAmount: saved, targetDate: localTargetDate);
                        }
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        child: Text(existing == null ? 'Create Goal' : 'Save Changes', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    if (existing != null) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final nav = Navigator.of(context);
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: TC.card(ctx),
                              title: Text('Delete Goal', style: TextStyle(color: TC.text(ctx))),
                              content: Text('Are you sure you want to delete "${existing.title}"?', style: TextStyle(color: TC.text2(ctx))),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: TC.text3(ctx)))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            state.deleteSavingGoal(existing.id);
                            if (mounted) nav.pop();
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                          ),
                          alignment: Alignment.center,
                          child: const Text('🗑 Delete Goal', style: TextStyle(color: AppColors.red, fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  // ─── Deposit sheet ────────────────────────────────────────────────────────
  void _showDepositSheet(BuildContext context, AppState state, SavingGoal goal) {
    final amtController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Savings to "${goal.title}"', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context))),
                const SizedBox(height: 16),
                TextField(
                  controller: amtController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: TextStyle(color: TC.text(context)),
                  decoration: InputDecoration(
                    labelText: 'Amount to add',
                    labelStyle: TextStyle(color: TC.text3(context)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TC.border(context))),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    final amtStr = amtController.text.replaceAll(',', '');
                    final amt = double.tryParse(amtStr) ?? 0;
                    if (amt <= 0) return;
                    final newSaved = goal.savedAmount + amt;
                    state.depositToGoal(goal, amt);
                    if (newSaved >= goal.targetAmount && goal.savedAmount < goal.targetAmount) {
                      _confettiController.play();
                    }
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: const Text('Add to Goal', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, AppState state, SavingGoal g) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GoalDetailScreen(
        goal: g,
        onDeposit: () => _showDepositSheet(context, state, g),
        onEdit: () => _showAddGoalSheet(context, state, g),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final goals = List.of(state.savingGoals)
      ..sort((a, b) {
        final aDone = a.savedAmount >= a.targetAmount;
        final bDone = b.savedAmount >= b.targetAmount;
        if (aDone && !bDone) return 1;
        if (!aDone && bDone) return -1;
        return b.id.compareTo(a.id);
      });

    final filtered = goals.where((g) {
      final pct = g.targetAmount > 0 ? ((g.savedAmount / g.targetAmount) * 100).round() : 0;
      if (_filter == 'On Track') return pct >= 60;
      if (_filter == 'Needs Push') return pct < 60;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: goals.isEmpty
                ? Column(
                    children: [
                      _header(context, state),
                      const Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: EmptyState(
                              icon: '🎯',
                              title: 'No Goals yet',
                              subtitle: 'Tap "+ Goal" above to get started.',
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _header(context, state),
                      _filterChips(context),
                      ...List.generate(filtered.length, (i) {
                        return _goalCard(context, state, filtered[i])
                            .animate(delay: (i * 60).ms)
                            .fadeIn(duration: 440.ms)
                            .slideY(begin: 0.12, curve: Curves.easeOut);
                      }),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                        child: GestureDetector(
                          onTap: () => _showAddGoalSheet(context, state),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: TC.primary(context),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: TC.primaryGlow(context), blurRadius: 16, offset: const Offset(0, 6))],
                            ),
                            alignment: Alignment.center,
                            child: const Text('+ Create New Goal', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14159 / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _header(BuildContext context, AppState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: TC.bg2(context), borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: Text('←', style: TextStyle(fontSize: 16, color: TC.text(context))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FINANCIAL TARGETS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: TC.primaryMd(context))),
                const SizedBox(height: 3),
                Text('Saving Goals', style: TC.gloock(context, fontSize: 24, color: TC.text(context), letterSpacing: -0.3)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () { HapticFeedback.mediumImpact(); _showAddGoalSheet(context, state); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: TC.primary(context),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [BoxShadow(color: TC.primaryGlow(context), blurRadius: 16, offset: const Offset(0, 5))],
              ),
              child: const Text('+ Goal', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Overall progress hero ──────────────────────────────────────────────────
  // ─── Filter chips ─────────────────────────────────────────────────────────
  Widget _filterChips(BuildContext context) {
    const filters = ['All', 'On Track', 'Needs Push'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Row(
        children: filters.map((f) {
          final active = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(() => _filter = f); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? TC.primary(context) : TC.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? TC.primary(context) : TC.border(context)),
                ),
                child: Text(f, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : TC.text2(context))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Goal card ──────────────────────────────────────────────────────────────
  Widget _goalCard(BuildContext context, AppState state, SavingGoal g) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _goalColor(g);
    final progress = g.targetAmount > 0 ? (g.savedAmount / g.targetAmount).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).round();

    return Dismissible(
      key: Key('goal_${g.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(20)),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: TC.card(context),
            title: Text('Delete Goal', style: TextStyle(color: TC.text(context))),
            content: Text('Are you sure you want to delete "${g.title}"?', style: TextStyle(color: TC.text2(context))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: TC.text3(context)))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold))),
            ],
          ),
        );
      },
      onDismissed: (_) {
        state.deleteSavingGoal(g.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Goal "${g.title}" deleted')));
      },
      child: GestureDetector(
        onTap: () => _navigateToDetail(context, state, g),
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TC.surface(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4)),
            ],
            border: isDark ? Border.all(color: TC.border(context)) : null,
          ),
          child: Column(
            children: [
              // Centered category icon
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(_emojiFor(g.title), style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(height: 10),
              Text(
                g.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TC.gloock(context, fontSize: 19, color: TC.text(context)),
              ),
              const SizedBox(height: 2),
              Text(
                'Target date: ${_deadlineLabel(g)}',
                style: TextStyle(fontSize: 12, color: TC.text3(context)),
              ),
              const SizedBox(height: 16),
              // Progress bar with % inside the coloured fill
              _goalProgressBar(context, pct, color),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved: ${_money(g.currency, g.savedAmount)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                  ),
                  Text(
                    'Goal: ${_money(g.currency, g.targetAmount)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TC.text(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Slim progress bar with the percentage shown inside the coloured fill.
  Widget _goalProgressBar(BuildContext context, int pct, Color color) {
    final clamped = pct.clamp(0, 100);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final fillW = (w * clamped / 100).clamp(40.0, w);
        return Stack(
          children: [
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: TC.bg2(context),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Container(
              height: 28,
              width: fillW,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '$clamped%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
