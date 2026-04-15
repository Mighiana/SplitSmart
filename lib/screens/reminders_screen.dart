import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../widgets/common_widgets.dart';
import '../main.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  @override
  Widget build(BuildContext context) {
    var state = context.watch<AppState>();
    var reminders = state.reminders;

    var pending = reminders.where((r) => !r.isCompleted).toList();
    var completed = reminders.where((r) => r.isCompleted).toList();

    return Scaffold(
      backgroundColor: TC.surface(context),
      appBar: AppBar(
        backgroundColor: TC.surface(context),
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Icon(Icons.arrow_back_ios_new, color: TC.text(context), size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PAYMENT ALERTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.green, letterSpacing: 2)),
            Text('Reminders', style: TextStyle(color: TC.text(context), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
          ],
        ),
      ),
      body: reminders.isEmpty
          ? Center(
              child: EmptyState(
                icon: '🔔',
                title: 'No reminders',
                subtitle: 'Add a reminder for an upcoming payment',
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                if (pending.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text('UPCOMING',
                        style: TextStyle(
                            color: TC.text3(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ),
                  ...pending.map((r) => _ReminderTile(r: r, state: state)),
                ],
                if (completed.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text('COMPLETED',
                        style: TextStyle(
                            color: TC.text3(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ),
                  ...completed.map((r) => _ReminderTile(r: r, state: state)),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReminderSheet(context, state),
        backgroundColor: AppColors.green,
        child: const Icon(Icons.add, color: Colors.black),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddReminderSheet(state: state),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final ReminderData r;
  final AppState state;

  const _ReminderTile({required this.r, required this.state});

  @override
  Widget build(BuildContext context) {
    final isPast = !r.isCompleted && r.date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    
    return Dismissible(
      key: Key('reminder_${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        state.deleteReminder(r);
      },
      child: ListTile(
        onTap: () {
          HapticFeedback.selectionClick();
          state.toggleReminderCompleted(r);
        },
        leading: Icon(
          r.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: r.isCompleted ? AppColors.green : (isPast ? AppColors.red : TC.text3(context)),
        ),
        title: Text(
          r.title,
          style: TextStyle(
            color: r.isCompleted ? TC.text3(context) : TC.text(context),
            decoration: r.isCompleted ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          DateFormat('MMM d, yyyy').format(r.date) + (r.amountStr.isNotEmpty ? ' • ${r.amountStr}' : ''),
          style: TextStyle(
            color: isPast && !r.isCompleted ? AppColors.red : TC.text2(context),
          ),
        ),
      ),
    );
  }
}

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
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.green,
              surface: Color(0xFF1A1A2E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) return;
    
    final r = ReminderData(
      id: 0, // Assigned by DB
      title: _titleCtrl.text.trim(),
      amountStr: _amountCtrl.text.trim(),
      date: _date,
    );
    
    widget.state.addReminder(r);
    AnalyticsService.logReminderAdded();
    Navigator.pop(context);
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
          Text('New Reminder',
              style: TextStyle(
                  color: TC.text(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Pay Netflix, Rent due...',
              hintStyle: TextStyle(color: TC.text3(context)),
              filled: true,
              fillColor: TC.card(context),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            style: TextStyle(color: TC.text(context)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            decoration: InputDecoration(
              hintText: 'Amount (optional) e.g. \$15.99',
              hintStyle: TextStyle(color: TC.text3(context)),
              filled: true,
              fillColor: TC.card(context),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            style: TextStyle(color: TC.text(context)),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: AppColors.green, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('MMMM d, yyyy').format(_date),
                    style: TextStyle(color: TC.text(context), fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Reminder',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
