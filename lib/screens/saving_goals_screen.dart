import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import '../services/analytics_service.dart';

class SavingGoalsScreen extends StatefulWidget {
  final String? initialCurrency;
  const SavingGoalsScreen({super.key, this.initialCurrency});

  @override
  State<SavingGoalsScreen> createState() => _SavingGoalsScreenState();
}

class _SavingGoalsScreenState extends State<SavingGoalsScreen> {
  String? _selectedCurrency;
  late ConfettiController _confettiController;

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
                        final saved = double.tryParse(savedStr) ?? 0;
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
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: TC.card(context),
                              title: Text('Delete Goal', style: TextStyle(color: TC.text(context))),
                              content: Text('Are you sure you want to delete "${existing.title}"?', style: TextStyle(color: TC.text2(context))),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: TC.text3(context)))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          );
                          if (confirm == true && mounted) {
                            state.deleteSavingGoal(existing.id);
                            Navigator.pop(context);
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
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  void _showDepositSheet(BuildContext context, AppState state, SavingGoal goal) {
    final amtController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(_).viewInsets.bottom),
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
                state.updateSavingGoal(goal, savedAmount: newSaved);
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
      ))),
    );
  }

  Color _getColorForGoal(SavingGoal g) {
    const palette = [
      Color(0xFFFF9F43), // Orange
      Color(0xFF985AFF), // Purple
      Color(0xFF00D2D3), // Cyan
      Color(0xFFff5252), // Red
      Color(0xFF4d9eff), // Blue
      Color(0xFF00D68F), // Green
    ];
    return palette[g.id % palette.length];
  }

  IconData _getIconForTitle(String t) {
    final lower = t.toLowerCase();
    if (lower.contains('car') || lower.contains('vehicle')) return Icons.directions_car_rounded;
    if (lower.contains('home') || lower.contains('house')) return Icons.home_rounded;
    if (lower.contains('vacation') || lower.contains('trip') || lower.contains('travel')) return Icons.flight_takeoff_rounded;
    return Icons.track_changes_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goals = state.savingGoals;
    
    goals.sort((a, b) {
      bool aDone = a.savedAmount >= a.targetAmount;
      bool bDone = b.savedAmount >= b.targetAmount;
      if (aDone && !bDone) return 1;
      if (!aDone && bDone) return -1;
      return b.id.compareTo(a.id);
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: TC.surface(context),
      appBar: AppBar(
        backgroundColor: TC.surface(context),
        elevation: 0,
        iconTheme: IconThemeData(color: TC.text(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FINANCIAL TARGETS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.green, letterSpacing: 2)),
            Text('Saving Goals', style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3)),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
          const SizedBox(height: 16),
          Text(
            'Save responsibly\n& achieve goals',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TC.text(context),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: goals.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: EmptyState(
                        icon: '🎯',
                        title: 'No Goals yet',
                        subtitle: 'Tap "Create goal" to get started.',
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: goals.length,
                    itemBuilder: (context, i) {
                      final g = goals[i];
                      final progress = g.targetAmount > 0 ? (g.savedAmount / g.targetAmount).clamp(0.0, 1.0) : 0.0;
                      final isCompleted = g.savedAmount >= g.targetAmount;
                      final themeColor = _getColorForGoal(g);
                      final iconData = _getIconForTitle(g.title);
                      
                      String targetDateStr = 'No target date';
                      if (g.targetDate != null) {
                        final pd = g.targetDate!;
                        targetDateStr = 'Target date: ${pd.day.toString().padLeft(2,'0')}.${pd.month.toString().padLeft(2,'0')}.${pd.year}';
                      }

                      return Dismissible(
                        key: Key('goal_${g.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerRight,
                          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: TC.card(context),
                              title: Text('Delete Goal', style: TextStyle(color: TC.text(context))),
                              content: Text('Are you sure you want to delete "${g.title}"?', style: TextStyle(color: TC.text2(context))),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: TC.text3(context)))),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          state.deleteSavingGoal(g.id);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Goal "${g.title}" deleted')));
                        },
                        child: GestureDetector(
                          onTap: () {
                            if (!isCompleted) _showDepositSheet(context, state, g);
                          },
                          onLongPress: () => _showAddGoalSheet(context, state, g),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: TC.card(context),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                              border: isDark ? Border.all(color: TC.border(context)) : null,
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: themeColor,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(isCompleted ? Icons.check_circle_rounded : iconData, color: Colors.white, size: 28),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(g.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TC.text(context))),
                                    const SizedBox(height: 4),
                                    Text(targetDateStr, style: TextStyle(fontSize: 12, color: TC.text3(context), fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 16),
                                    Stack(
                                      children: [
                                        Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6))),
                                        FractionallySizedBox(
                                          widthFactor: progress,
                                          child: Container(
                                            height: 12, 
                                            decoration: BoxDecoration(
                                              color: isCompleted ? AppColors.green : themeColor, 
                                              borderRadius: BorderRadius.circular(6),
                                            )
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Saved: ${AppCurrencyUtils.formatAmount(g.savedAmount, 0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isCompleted ? AppColors.green : themeColor)),
                                        Text('Goal:${AppCurrencyUtils.formatAmount(g.targetAmount, 0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TC.text(context))),
                                      ],
                                    ),
                                  ],
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _showAddGoalSheet(context, state, g),
                                    child: Icon(Icons.edit, color: TC.text3(context), size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: GestureDetector(
              onTap: () => _showAddGoalSheet(context, state),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.greenGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 6)),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('＋  Create Goal', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
      Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: 3.14159 / 2, // point straight down
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
}
