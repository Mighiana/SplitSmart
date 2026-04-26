import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../widgets/common_widgets.dart';
import '../main.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';

// ─── Reminders Screen ────────────────────────────────────────────────────────
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reminders = state.reminders;
    final pending = reminders.where((r) => !r.isCompleted).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final completed = reminders.where((r) => r.isCompleted).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: TC.bg(context),
      appBar: AppBar(
        backgroundColor: TC.bg(context),
        elevation: 0,
        leading: GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TC.border(context)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.arrow_back_ios_new, color: TC.text(context), size: 16),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PAYMENT ALERTS',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.green, letterSpacing: 2),
            ),
            Text(
              'Reminders',
              style: TextStyle(color: TC.text(context), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => _showAddReminderSheet(context, state),
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: Colors.black, size: 22),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TC.border(context)),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
              ),
              dividerColor: Colors.transparent,
              labelColor: AppColors.green,
              unselectedLabelColor: TC.text3(context),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: [
                Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Flexible(child: Text('Upcoming', overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${pending.length}',
                            style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Flexible(child: Text('Completed', overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: TC.card(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: TC.border(context)),
                          ),
                          child: Text(
                            '${completed.length}',
                            style: TextStyle(color: TC.text2(context), fontSize: 11, fontWeight: FontWeight.w700),
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
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── Upcoming ──────────────────────────────────────────────────────
          pending.isEmpty
              ? _buildEmpty('🔔', 'No upcoming reminders', 'Tap + to add a payment reminder')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: pending.length + 2,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'UPCOMING',
                          style: TextStyle(
                            color: TC.text3(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      );
                    }
                    if (i == pending.length + 1) {
                      return _buildAllSetContainer(context, pending.length, state);
                    }
                    return _ReminderCard(r: pending[i - 1], state: state);
                  },
                ),

          // ── Completed ─────────────────────────────────────────────────────
          completed.isEmpty
              ? _buildEmpty('📭', 'No completed reminders', 'Mark upcoming reminders as done')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: completed.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'COMPLETED',
                          style: TextStyle(
                            color: TC.text3(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      );
                    }
                    return _ReminderCard(r: completed[i - 1], state: state);
                  },
                ),
        ],
      ),
      // ── Banner ────────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: GestureDetector(
          onTap: () => _showAddReminderSheet(context, state),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.greenDim,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('🔔', style: TextStyle(fontSize: 22)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.check_rounded, color: Colors.black, size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Never miss a payment',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.green),
                      ),
                      Text(
                        "We'll remind you before your bills are due.",
                        style: TextStyle(color: TC.text2(context), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.green, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(String icon, String title, String subtitle) {
    return Center(
      child: EmptyState(icon: icon, title: title, subtitle: subtitle),
    );
  }

  Widget _buildAllSetContainer(BuildContext context, int count, AppState state) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        // A simple border to represent the dashed line in the mockup
        border: Border.all(color: AppColors.green.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.calendar_month_rounded, color: AppColors.green.withValues(alpha: 0.5), size: 28),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "You're all set!",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  "Only $count payments scheduled.\nAdd more reminders to stay on track.",
                  style: TextStyle(color: TC.text2(context), fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showAddReminderSheet(context, state),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    "Add Reminder",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context, AppState state) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddReminderSheet(state: state),
    );
  }
}

class _CardConfig {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  _CardConfig(this.icon, this.bgColor, this.iconColor);
}

// ─── Reminder Card ────────────────────────────────────────────────────────────
class _ReminderCard extends StatelessWidget {
  final ReminderData r;
  final AppState state;

  const _ReminderCard({required this.r, required this.state});

  String _countdownText() {
    if (r.isCompleted) return 'Done';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(r.date.year, r.date.month, r.date.day);
    final diff = due.difference(today).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }

  Color _countdownColor() {
    if (r.isCompleted) return AppColors.green;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(r.date.year, r.date.month, r.date.day);
    final diff = due.difference(today).inDays;
    if (diff <= 3) return const Color(0xFFE57373); // Light Red
    if (diff <= 30) return const Color(0xFFFFB74D); // Orange
    return const Color(0xFF4CAF50);
  }

  _CardConfig _getCardConfig(String title) {
    final t = title.toLowerCase();
    if (t.contains('netflix') || t.contains('youtube') || t.contains('tv')) {
      return _CardConfig(Icons.play_circle_filled, const Color(0xFFFFEBEE), const Color(0xFFD32F2F));
    }
    if (t.contains('spotify') || t.contains('music')) {
      return _CardConfig(Icons.music_note_rounded, const Color(0xFFE8F5E9), const Color(0xFF388E3C));
    }
    if (t.contains('chatgpt') || t.contains('ai') || t.contains('gpt')) {
      return _CardConfig(Icons.smart_toy_rounded, const Color(0xFFE0F2F1), const Color(0xFF00796B));
    }
    if (t.contains('electric') || t.contains('power') || t.contains('energy') || t.contains('bolt')) {
      return _CardConfig(Icons.bolt_rounded, const Color(0xFFFFF8E1), const Color(0xFFFFA000));
    }
    if (t.contains('internet') || t.contains('wifi')) {
      return _CardConfig(Icons.wifi_rounded, const Color(0xFFE3F2FD), const Color(0xFF1976D2));
    }
    if (t.contains('rent') || t.contains('house') || t.contains('home')) {
      return _CardConfig(Icons.home_rounded, const Color(0xFFF3E5F5), const Color(0xFF7B1FA2));
    }
    return _CardConfig(Icons.receipt_long_rounded, const Color(0xFFF5F5F5), const Color(0xFF757575));
  }

  String _categoryFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('netflix') || t.contains('youtube') || t.contains('spotify') || t.contains('prime') || t.contains('tv')) return 'Subscription';
    if (t.contains('electric') || t.contains('internet') || t.contains('water') || t.contains('gas') || t.contains('power')) return 'Utilities';
    if (t.contains('rent') || t.contains('house')) return 'Housing';
    if (t.contains('gym') || t.contains('fitness')) return 'Health';
    if (t.contains('insurance')) return 'Insurance';
    if (t.contains('credit') || t.contains('loan') || t.contains('chatgpt')) return 'Subscription';
    return 'Reminder';
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _countdownText();
    final countdownColor = _countdownColor();
    final config = _getCardConfig(r.title);
    final category = _categoryFor(r.title);

    return Dismissible(
      key: Key('reminder_${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.redDim,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.red),
      ),
      onDismissed: (_) => state.deleteReminder(r),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          state.toggleReminderCompleted(r);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TC.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TC.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Checkbox circle ───────────────────────────────────────────
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  state.toggleReminderCompleted(r);
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: r.isCompleted ? AppColors.green : Colors.grey.withValues(alpha: 0.5),
                      width: r.isCompleted ? 0 : 2,
                    ),
                    color: r.isCompleted ? AppColors.green : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: r.isCompleted
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              // ── Pastel icon circle ─────────────────────────────────────────
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: config.bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(config.icon, color: config.iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              // ── Title + subtitle + date ───────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: r.isCompleted ? TC.text3(context) : TC.text(context),
                        decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category,
                      style: TextStyle(fontSize: 12, color: TC.text3(context)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 12, color: TC.text3(context)),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('d MMM yyyy').format(r.date),
                          style: TextStyle(fontSize: 12, color: TC.text3(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ── Right column: amount + countdown ──────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (r.amountStr.isNotEmpty)
                    Text(
                      '${_getCurrency(state)}${r.amountStr}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: TC.text(context),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: countdownColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      countdown,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: countdownColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrency(AppState state) {
    if (state.wallets.isNotEmpty) {
      final code = state.wallets.keys.first;
      final cData = AppState.currencies.firstWhere(
        (c) => c.code == code,
        orElse: () => AppState.currencies.first,
      );
      return cData.sym;
    }
    return '€';
  }
}

// ─── Add Reminder Sheet ───────────────────────────────────────────────────────
class _AddReminderSheet extends StatefulWidget {
  final AppState state;
  const _AddReminderSheet({required this.state});

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.green,
                    surface: Color(0xFF1A1A2E),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.green,
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final r = ReminderData(
      id: 0,
      title: _titleCtrl.text.trim(),
      amountStr: _amountCtrl.text.trim(),
      date: _date,
    );
    await widget.state.addReminder(r);
    AnalyticsService.logReminderAdded();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, keyboard + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Text(
                'New Reminder',
                style: TextStyle(color: TC.text(context), fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Title field
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Netflix, Rent, Electricity...',
              hintStyle: TextStyle(color: TC.text3(context)),
              prefixIcon: Icon(Icons.edit_outlined, color: TC.text3(context), size: 20),
              filled: true,
              fillColor: TC.card(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.green, width: 1.5),
              ),
            ),
            style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          // Amount field
          TextField(
            controller: _amountCtrl,
            decoration: InputDecoration(
              hintText: 'Amount (optional) e.g. €15.99',
              hintStyle: TextStyle(color: TC.text3(context)),
              prefixIcon: Icon(Icons.attach_money_outlined, color: TC.text3(context), size: 20),
              filled: true,
              fillColor: TC.card(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.green, width: 1.5),
              ),
            ),
            style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w600),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 12),
          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, color: AppColors.green, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('MMMM d, yyyy').format(_date),
                    style: TextStyle(color: TC.text(context), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: TC.text3(context)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'Add Reminder',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
