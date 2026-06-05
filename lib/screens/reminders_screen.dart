import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_state.dart';
import '../main.dart';
import '../utils/app_utils.dart';
import '../widgets/common_widgets.dart';
import '../services/analytics_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  String _tab = 'Upcoming';
  bool _notify = true;

  void _showAddReminderSheet(BuildContext context, AppState state) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddReminderSheet(state: state),
    );
  }

  double _amountOf(ReminderData r) {
    final m = RegExp(r'[\d.]+').firstMatch(r.amountStr.replaceAll(',', ''));
    return m != null ? (double.tryParse(m.group(0)!) ?? 0) : 0;
  }

  String _symOf(List<ReminderData> list) {
    for (final r in list) {
      final m = RegExp(r'[^\d.,\s]').firstMatch(r.amountStr);
      if (m != null) return m.group(0)!;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reminders = state.reminders;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final overdue = <ReminderData>[];
    final upcoming = <ReminderData>[];
    final done = <ReminderData>[];
    for (final r in reminders) {
      if (r.isCompleted) {
        done.add(r);
      } else {
        final due = DateTime(r.date.year, r.date.month, r.date.day);
        if (due.isBefore(today)) {
          overdue.add(r);
        } else {
          upcoming.add(r);
        }
      }
    }
    overdue.sort((a, b) => a.date.compareTo(b.date));
    upcoming.sort((a, b) => a.date.compareTo(b.date));
    done.sort((a, b) => b.date.compareTo(a.date));

    final sym = _symOf(reminders);
    final totalOverdue = overdue.fold<double>(0, (s, r) => s + _amountOf(r));
    final totalUpcoming = upcoming.fold<double>(0, (s, r) => s + _amountOf(r));

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => context.read<AppState>().refresh(),
          color: TC.primary(context),
          backgroundColor: TC.card(context),
          child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          children: [
            _header(context, state),
            _summaryStrip(context, sym, overdue.length, totalOverdue, upcoming.length, totalUpcoming)
                .animate().fadeIn(duration: 360.ms).slideY(begin: 0.1, curve: Curves.easeOut),
            _neverMissBanner(context).animate().fadeIn(delay: 60.ms, duration: 360.ms),
            _tabs(context, upcoming.length, overdue.length, done.length),
            if (_tab == 'Upcoming') _upcomingTab(context, state, upcoming, today),
            if (_tab == 'Overdue') _overdueTab(context, state, overdue),
            if (_tab == 'Done') _doneTab(context, state, done, sym),
          ],
        ),
        ),
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
              child: Icon(Icons.arrow_back_rounded, size: 18, color: TC.text(context)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PAYMENT ALERTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: TC.primaryMd(context))),
                const SizedBox(height: 3),
                Text('Reminders', style: TC.gloock(context, fontSize: 24, color: TC.text(context), letterSpacing: -0.3)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showAddReminderSheet(context, state),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: TC.primary(context),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: TC.primaryGlow(context), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              alignment: Alignment.center,
              child: const Text('+', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w400)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Summary strip ──────────────────────────────────────────────────────────
  Widget _summaryStrip(BuildContext context, String sym, int overCount, double overTotal, int upCount, double upTotal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      decoration: BoxDecoration(
        color: TC.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1))],
        border: isDark ? Border.all(color: TC.border(context)) : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                decoration: BoxDecoration(
                  color: overCount > 0 ? TC.erPale(context) : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Text('⚠️ OVERDUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: overCount > 0 ? TC.er(context) : TC.text3(context))),
                    const SizedBox(height: 3),
                    Text('$overCount', style: TC.gloock(context, fontSize: 20, color: overCount > 0 ? TC.er(context) : TC.text3(context))),
                    const SizedBox(height: 2),
                    Text('$sym${overTotal.toStringAsFixed(0)} total', style: TextStyle(fontSize: 10, color: TC.text3(context))),
                  ],
                ),
              ),
            ),
            Container(width: 1, color: TC.border(context)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                child: Column(
                  children: [
                    Text('📅 UPCOMING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: TC.text3(context))),
                    const SizedBox(height: 3),
                    Text('$upCount', style: TC.gloock(context, fontSize: 20, color: TC.text(context))),
                    const SizedBox(height: 2),
                    Text('$sym${upTotal.toStringAsFixed(0)} total', style: TextStyle(fontSize: 10, color: TC.text3(context))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Never-miss banner ───────────────────────────────────────────────────────
  Widget _neverMissBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: TC.primaryPale(context), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.notifications_rounded, size: 20, color: TC.primary(context)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Never miss a payment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TC.primary(context))),
                const SizedBox(height: 2),
                Text('Reminders sent 3 days before each due date.', style: TextStyle(fontSize: 11, color: TC.text2(context))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _notify = !_notify); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46, height: 26,
              decoration: BoxDecoration(
                color: _notify ? TC.primary(context) : TC.text4(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _notify ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tabs ─────────────────────────────────────────────────────────────────
  Widget _tabs(BuildContext context, int up, int over, int done) {
    final tabs = [
      ['Upcoming', 'Upcoming $up'],
      ['Overdue', 'Overdue $over'],
      ['Done', 'Done $done'],
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: tabs.map((t) {
            final active = _tab == t[0];
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); setState(() => _tab = t[0]); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? TC.primary(context) : TC.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? TC.primary(context) : TC.border(context)),
                  ),
                  child: Text(t[1], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : TC.text3(context))),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Upcoming tab ─────────────────────────────────────────────────────────
  Widget _upcomingTab(BuildContext context, AppState state, List<ReminderData> upcoming, DateTime today) {
    if (upcoming.isEmpty) {
      return RichEmptyState(
        art: '🔔',
        title: 'Never miss a payment',
        desc: "Add bills and due dates. We'll remind you 3 days before each one.",
        pills: [
          EmptyPill('🏠', 'Rent', onTap: () => _showAddReminderSheet(context, state)),
          EmptyPill('⚡', 'Electricity', onTap: () => _showAddReminderSheet(context, state)),
          EmptyPill('💳', 'Credit Card', onTap: () => _showAddReminderSheet(context, state)),
          EmptyPill('🌐', 'Internet', onTap: () => _showAddReminderSheet(context, state)),
        ],
        ctaLabel: 'Add a Reminder',
        onCta: () => _showAddReminderSheet(context, state),
      );
    }
    final thisWeek = <ReminderData>[];
    final later = <ReminderData>[];
    for (final r in upcoming) {
      final due = DateTime(r.date.year, r.date.month, r.date.day);
      if (due.difference(today).inDays <= 7) {
        thisWeek.add(r);
      } else {
        later.add(r);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (thisWeek.isNotEmpty) ...[
          _sectionHeader(context, '⏰ This Week', TC.wn(context)),
          ...thisWeek.map((r) => _upcomingRow(context, state, r, urgent: true)),
        ],
        if (later.isNotEmpty) ...[
          _sectionHeader(context, '📅 Later This Month', TC.text3(context)),
          ...later.map((r) => _upcomingRow(context, state, r, urgent: false)),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: color)),
    );
  }

  Widget _upcomingRow(BuildContext context, AppState state, ReminderData r, {required bool urgent}) {
    final config = _getConfig(r.title);
    final category = _categoryFor(r.title);
    final color = config.accent;
    final dt = DateFormat('MMM d').format(r.date);
    return _dismissible(context, state, r,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _cardDeco(context),
        child: Row(
          children: [
            _bubble(context, config.icon, color.withValues(alpha: 0.08)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TC.text(context))),
                  const SizedBox(height: 2),
                  Text(category, style: TextStyle(fontSize: 11, color: TC.text3(context))),
                  const SizedBox(height: 2),
                  Text(DateFormat('EEEE, MMM d').format(r.date), style: TextStyle(fontSize: 10, color: TC.text2(context))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (r.amountStr.isNotEmpty)
                  Text(r.amountStr, style: TC.gloock(context, fontSize: 17, color: TC.text(context))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: urgent ? TC.wnPale(context) : TC.primaryPale(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Due $dt', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: urgent ? TC.wn(context) : TC.primary(context))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Overdue tab ──────────────────────────────────────────────────────────
  Widget _overdueTab(BuildContext context, AppState state, List<ReminderData> overdue) {
    if (overdue.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            const Text('✅', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text('No overdue payments!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TC.ok(context))),
          ],
        ),
      );
    }
    return Column(
      children: overdue.map((r) {
        final config = _getConfig(r.title);
        final category = _categoryFor(r.title);
        final dt = DateFormat('MMM d').format(r.date);
        return _dismissible(context, state, r,
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            decoration: _cardDeco(context),
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: TC.erPale(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bubble(context, config.icon, TC.er(context).withValues(alpha: 0.15)),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TC.text(context))),
                        const SizedBox(height: 2),
                        Text(category, style: TextStyle(fontSize: 11, color: TC.text2(context))),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: TC.erPale(context), borderRadius: BorderRadius.circular(20)),
                          child: Text('Due $dt', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: TC.er(context))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (r.amountStr.isNotEmpty)
                        Text(r.amountStr, style: TC.gloock(context, fontSize: 17, color: TC.er(context))),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () { HapticFeedback.lightImpact(); state.toggleReminderCompleted(r); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: TC.er(context), borderRadius: BorderRadius.circular(10)),
                          child: const Text('Pay Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Done tab ─────────────────────────────────────────────────────────────
  Widget _doneTab(BuildContext context, AppState state, List<ReminderData> done, String sym) {
    if (done.isEmpty) {
      return _empty(context, '📭', 'No completed reminders', 'Mark upcoming reminders as done');
    }
    final totalPaid = done.fold<double>(0, (s, r) => s + _amountOf(r));
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: TC.okPale(context), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(Icons.celebration_rounded, size: 20, color: TC.ok(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${done.length} payment${done.length > 1 ? 's' : ''} completed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TC.ok(context))),
                    const SizedBox(height: 2),
                    Text('Total paid: $sym${totalPaid.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: TC.text2(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...done.map((r) {
          final config = _getConfig(r.title);
          final category = _categoryFor(r.title);
          final dt = DateFormat('MMM d').format(r.date);
          return _dismissible(context, state, r,
            child: Opacity(
              opacity: 0.75,
              child: GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); state.toggleReminderCompleted(r); },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: _cardDeco(context),
                  child: Row(
                    children: [
                      _bubble(context, config.icon, TC.okPale(context)),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TC.text(context))),
                            const SizedBox(height: 2),
                            Text('$category · Paid $dt', style: TextStyle(fontSize: 11, color: TC.text3(context))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (r.amountStr.isNotEmpty)
                            Text(r.amountStr, style: TC.gloock(context, fontSize: 17, color: TC.ok(context))),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: TC.okPale(context), borderRadius: BorderRadius.circular(20)),
                            child: Text('Paid', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: TC.ok(context))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Shared bits ────────────────────────────────────────────────────────────
  BoxDecoration _cardDeco(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: TC.surface(context),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1))],
      border: isDark ? Border.all(color: TC.border(context)) : null,
    );
  }

  Widget _bubble(BuildContext context, String icon, Color bg) {
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Text(icon, style: const TextStyle(fontSize: 20)),
    );
  }

  Widget _dismissible(BuildContext context, AppState state, ReminderData r, {required Widget child}) {
    return Dismissible(
      key: Key('reminder_${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => state.deleteReminder(r),
      child: child,
    );
  }

  Widget _empty(BuildContext context, String icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: TC.text2(context))),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 13, color: TC.text3(context))),
        ],
      ).animate().fade().scale(curve: Curves.easeOutBack),
    );
  }
}

class _CardConfig {
  final String icon;
  final Color accent;
  _CardConfig(this.icon, this.accent);
}

_CardConfig _getConfig(String title) {
  final t = title.toLowerCase();
  if (t.contains('rent') || t.contains('house') || t.contains('home')) return _CardConfig('🏠', const Color(0xFF0D7377));
  if (t.contains('electric') || t.contains('power') || t.contains('utility')) return _CardConfig('⚡', const Color(0xFF3B82F6));
  if (t.contains('internet') || t.contains('wifi')) return _CardConfig('🌐', const Color(0xFF3B82F6));
  if (t.contains('phone') || t.contains('mobile')) return _CardConfig('📱', const Color(0xFF8B5CF6));
  if (t.contains('car') || t.contains('auto') || t.contains('insurance')) return _CardConfig('🚗', const Color(0xFF059669));
  if (t.contains('water')) return _CardConfig('💧', const Color(0xFF3B82F6));
  if (t.contains('netflix') || t.contains('tv') || t.contains('youtube') || t.contains('chatgpt')) return _CardConfig('📺', const Color(0xFFE85A6A));
  if (t.contains('spotify') || t.contains('music')) return _CardConfig('🎵', const Color(0xFF059669));
  if (t.contains('credit') || t.contains('card') || t.contains('bill')) return _CardConfig('💳', const Color(0xFFD97706));
  return _CardConfig('📋', const Color(0xFF8B5CF6));
}

String _categoryFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('netflix') || t.contains('youtube') || t.contains('spotify') || t.contains('prime') || t.contains('tv') || t.contains('chatgpt')) return 'Subscription';
  if (t.contains('electric') || t.contains('internet') || t.contains('water') || t.contains('gas') || t.contains('power')) return 'Utility';
  if (t.contains('rent') || t.contains('house')) return 'Rent';
  if (t.contains('gym') || t.contains('fitness')) return 'Health';
  if (t.contains('insurance')) return 'Insurance';
  if (t.contains('credit') || t.contains('card')) return 'Bill';
  if (t.contains('phone') || t.contains('mobile')) return 'Personal';
  return 'Custom';
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
                  colorScheme: const ColorScheme.light(primary: AppColors.green),
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
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.notifications_rounded, size: 24, color: TC.text3(context)),
              const SizedBox(width: 10),
              Text('New Reminder', style: TextStyle(color: TC.text(context), fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Netflix, Rent, Electricity...',
              hintStyle: TextStyle(color: TC.text3(context)),
              prefixIcon: Icon(Icons.edit_outlined, color: TC.text3(context), size: 20),
              filled: true,
              fillColor: TC.card(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.green, width: 1.5)),
            ),
            style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            decoration: InputDecoration(
              hintText: 'Amount (optional) e.g. €15.99',
              hintStyle: TextStyle(color: TC.text3(context)),
              prefixIcon: Icon(Icons.attach_money_outlined, color: TC.text3(context), size: 20),
              filled: true,
              fillColor: TC.card(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.green, width: 1.5)),
            ),
            style: TextStyle(color: TC.text(context), fontWeight: FontWeight.w600),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: AppColors.green, size: 20),
                  const SizedBox(width: 12),
                  Text(DateFormat('MMMM d, yyyy').format(_date), style: TextStyle(color: TC.text(context), fontSize: 16, fontWeight: FontWeight.w600)),
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
                boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              alignment: Alignment.center,
              child: const Text('Add Reminder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}
