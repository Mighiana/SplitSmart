import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';
import '../widgets/common_widgets.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';

/// Preset color palette for subscriptions.
const _kColors = [
  '#00D68F', // green
  '#4D9EFF', // blue
  '#FF4D6D', // red
  '#FFD166', // yellow
  '#B388FF', // purple
  '#FF6B9D', // pink
  '#26DE81', // teal
  '#FFA94D', // orange
];

/// Emoji presets (user can also type their own).
const _kEmojis = [
  '📺','🎵','🎮','📰','☁️','💼','🏋️','📚',
  '🎬','🛒','🍕','✈️','💊','🎨','📱','🔐',
  '🏠','🎧','🌐','🚗','🎓','💻','📊','🔔',
];

const _kCategories = [
  'Entertainment', 'Health', 'Education', 'Work', 'Other',
];

const _kWeekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday',
  'Friday', 'Saturday', 'Sunday',
];

const _kMonths = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December',
];

class AddSubscriptionScreen extends StatefulWidget {
  final SubscriptionData? existing;
  const AddSubscriptionScreen({super.key, this.existing});

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen>
    with TickerProviderStateMixin {

  // ── Form state ─────────────────────────────────────────────────────────────
  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _cycle        = BillingCycle.monthly;
  int    _billingDay   = 1;    // 1-28 for monthly/yearly; 1-7 for weekly
  int    _billingMonth = 1;    // 1-12, only for yearly
  String _category     = 'Entertainment';
  String _emoji        = '📺';
  String _colorHex     = '#00D68F';
  String _currency     = 'EUR';

  // Validation
  bool _submitted     = false;
  bool _saving        = false;

  // Shake controller for validation errors
  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;

  // Entry animation
  late AnimationController _entryCtrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();

    // Shake animation for invalid submit
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Pre-fill if editing
    if (_isEdit) {
      final e = widget.existing!;
      _nameCtrl.text   = e.name;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _cycle           = e.cycle;
      _billingDay      = e.billingDay;
      _billingMonth    = e.billingMonth;
      _category        = e.category;
      _emoji           = e.emoji;
      _colorHex        = e.colorHex;
      _currency        = e.currency;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _shakeCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Color get _accent {
    try {
      return Color(int.parse('FF${_colorHex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.green;
    }
  }

  CurrencyData get _selectedCurrency =>
      AppState.currencies.firstWhere(
        (c) => c.code == _currency,
        orElse: () => CurrencyData('EUR', 'Euro', '🇪🇺', '€'),
      );

  // ── Validation ─────────────────────────────────────────────────────────────
  bool get _nameValid   => _nameCtrl.text.trim().isNotEmpty;
  bool get _amountValid => (double.tryParse(_amountCtrl.text) ?? 0) > 0;
  bool get _formValid   => _nameValid && _amountValid;

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formValid) {
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0);
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final cur = _selectedCurrency;

    if (_isEdit) {
      final updated = widget.existing!.copyWith(
        name:         _nameCtrl.text.trim(),
        amount:       double.parse(_amountCtrl.text),
        currency:     _currency,
        sym:          cur.sym,
        cycle:        _cycle,
        billingDay:   _billingDay,
        billingMonth: _billingMonth,
        category:     _category,
        emoji:        _emoji,
        colorHex:     _colorHex,
        isActive:     widget.existing!.isActive,
      );
      await context.read<AppState>().updateSubscription(updated);
      await NotificationService.scheduleForSub(updated);
    } else {
      final sub = SubscriptionData(
        id:           0, // auto-assigned by DB
        name:         _nameCtrl.text.trim(),
        amount:       double.parse(_amountCtrl.text),
        currency:     _currency,
        sym:          cur.sym,
        cycle:        _cycle,
        billingDay:   _billingDay,
        billingMonth: _billingMonth,
        category:     _category,
        emoji:        _emoji,
        colorHex:     _colorHex,
        isActive:     true,
        createdAt:    DateTime.now(),
      );
      await context.read<AppState>().addSubscription(sub);
      AnalyticsService.logSubscriptionAdded(_cycle);

      // Schedule notifications for the newly saved subscription (get real id)
      final saved = context.read<AppState>().subscriptions.first;
      await NotificationService.scheduleForSub(saved);

      // Auto-create a recurring expense in Money Manager
      _autoCreateExpense(sub, cur);
    }

    if (mounted) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context);
    }
  }

  /// Creates a one-off expense transaction to track the subscription cost.
  void _autoCreateExpense(SubscriptionData sub, CurrencyData cur) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final now   = DateTime.now();
    final date  = '${now.day} ${months[now.month - 1]}';
    final txn   = TransactionData(
      id:       DateTime.now().millisecondsSinceEpoch,
      type:     'expense',
      desc:     '${sub.emoji} ${sub.name} (subscription)',
      amount:   sub.amount,
      cat:      _categoryEmoji(sub.category),
      currency: sub.currency,
      sym:      cur.sym,
      date:     date,
    );
    context.read<AppState>().addTransaction(txn);
  }

  String _categoryEmoji(String cat) {
    switch (cat) {
      case 'Entertainment': return '🎬';
      case 'Health':        return '💊';
      case 'Education':     return '📚';
      case 'Work':          return '💼';
      default:              return '🔔';
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _entryCtrl,
        child: SlideTransition(
          position: slide,
          child: SafeArea(
            child: Column(
              children: [
                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: TC.card(context),
                            shape: BoxShape.circle,
                            border: Border.all(color: TC.border(context)),
                          ),
                          alignment: Alignment.center,
                          child: Text('←', style: TextStyle(
                              fontSize: 18, color: TC.text(context))),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(_isEdit ? 'Edit Subscription' : 'New Subscription',
                          style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: TC.text(context),
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Form ─────────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Emoji + Color row ─────────────────────────────
                        Row(
                          children: [
                            // Emoji picker button
                            GestureDetector(
                              onTap: _pickEmoji,
                              child: Container(
                                width: 72, height: 72,
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: _accent.withValues(alpha: 0.4),
                                      width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_emoji, style: const TextStyle(fontSize: 28)),
                                    Text('tap',
                                        style: TextStyle(fontSize: 9,
                                            color: TC.text3(context))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Label('Color'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8, runSpacing: 8,
                                    children: _kColors.map((hex) {
                                      final c = Color(int.parse(
                                          'FF${hex.replaceAll('#', '')}', radix: 16));
                                      final sel = hex == _colorHex;
                                      return GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _colorHex = hex);
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          width: 28, height: 28,
                                          decoration: BoxDecoration(
                                            color: c,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: sel ? Colors.white : Colors.transparent,
                                              width: 2.5,
                                            ),
                                            boxShadow: sel
                                                ? [BoxShadow(
                                                    color: c.withValues(alpha: 0.55),
                                                    blurRadius: 8)]
                                                : [],
                                          ),
                                          alignment: Alignment.center,
                                          child: sel
                                              ? const Icon(Icons.check,
                                                  color: Colors.white, size: 14)
                                              : null,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Name ──────────────────────────────────────────
                        _Label('Subscription name'),
                        const SizedBox(height: 8),
                        AnimatedBuilder(
                          animation: _shakeAnim,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(_shakeAnim.value, 0),
                            child: child,
                          ),
                          child: _Field(
                            controller: _nameCtrl,
                            hint: 'e.g. Netflix',
                            error: _submitted && !_nameValid
                                ? 'Name is required'
                                : null,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Amount + Currency ─────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Label('Amount'),
                                  const SizedBox(height: 8),
                                  AnimatedBuilder(
                                    animation: _shakeAnim,
                                    builder: (_, child) => Transform.translate(
                                      offset: Offset(_shakeAnim.value, 0),
                                      child: child,
                                    ),
                                    child: _Field(
                                      controller: _amountCtrl,
                                      hint: '0.00',
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                              decimal: true),
                                      prefix:
                                          '${_selectedCurrency.sym} ',
                                      error: _submitted && !_amountValid
                                          ? 'Enter amount'
                                          : null,
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Label('Currency'),
                                  const SizedBox(height: 8),
                                  _DropdownField<String>(
                                    value: _currency,
                                    items: AppState.currencies
                                        .map((c) => DropdownMenuItem(
                                              value: c.code,
                                              child: Text(
                                                '${c.flag} ${c.code}',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: TC.text(context)),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _currency = v!),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Billing cycle ─────────────────────────────────
                        _Label('Billing cycle'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            BillingCycle.monthly,
                            BillingCycle.weekly,
                            BillingCycle.yearly,
                          ].map((c) {
                            final active = _cycle == c;
                            final label  = c == BillingCycle.monthly ? 'Monthly'
                                         : c == BillingCycle.weekly  ? 'Weekly'
                                         : 'Yearly';
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _cycle = c;
                                    _billingDay = 1;
                                    _billingMonth = 1;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? _accent.withValues(alpha: 0.12)
                                        : TC.card(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: active
                                          ? _accent
                                          : TC.border(context),
                                      width: active ? 1.5 : 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: active
                                            ? _accent
                                            : TC.text2(context),
                                      )),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // ── Billing day picker ────────────────────────────
                        if (_cycle == BillingCycle.monthly) ...[
                          _Label('Billing day of month'),
                          const SizedBox(height: 8),
                          _DayPicker(
                            selected: _billingDay,
                            max: 28,
                            label: (i) => '${i}th',
                            accent: _accent,
                            onSelect: (d) =>
                                setState(() => _billingDay = d),
                          ),
                        ],

                        if (_cycle == BillingCycle.weekly) ...[
                          _Label('Billing day of week'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: List.generate(7, (i) {
                              final active = _billingDay == i + 1;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _billingDay = i + 1);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? _accent.withValues(alpha: 0.12)
                                        : TC.card(context),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: active ? _accent : TC.border(context),
                                      width: active ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(_kWeekdays[i].substring(0, 3),
                                      style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w700,
                                        color: active
                                            ? _accent
                                            : TC.text2(context),
                                      )),
                                ),
                              );
                            }),
                          ),
                        ],

                        if (_cycle == BillingCycle.yearly) ...[
                          _Label('Billing month'),
                          const SizedBox(height: 8),
                          _DropdownField<int>(
                            value: _billingMonth,
                            items: List.generate(
                              12,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text(_kMonths[i],
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: TC.text(context))),
                              ),
                            ),
                            onChanged: (v) =>
                                setState(() => _billingMonth = v!),
                          ),
                          const SizedBox(height: 10),
                          _Label('Billing day'),
                          const SizedBox(height: 8),
                          _DayPicker(
                            selected: _billingDay,
                            max: 28,
                            label: (i) => '${i}',
                            accent: _accent,
                            onSelect: (d) =>
                                setState(() => _billingDay = d),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ── Category ──────────────────────────────────────
                        _Label('Category'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _kCategories.map((cat) {
                            final active = _category == cat;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _category = cat);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: active
                                      ? _accent.withValues(alpha: 0.12)
                                      : TC.card(context),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active
                                        ? _accent
                                        : TC.border(context),
                                    width: active ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(cat,
                                    style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700,
                                      color: active
                                          ? _accent
                                          : TC.text2(context),
                                    )),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 32),

                        // ── Save button ───────────────────────────────────
                        _SaveButton(
                          label: _isEdit
                              ? 'Save Changes'
                              : 'Add Subscription',
                          accent: _accent,
                          loading: _saving,
                          onTap: _save,
                        ),

                        const SizedBox(height: 12),

                        // Notification hint
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🔔',
                                style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              'You\'ll get reminders 3 days before & on billing day',
                              style: TextStyle(
                                  fontSize: 11, color: TC.text3(context)),
                            ),
                          ],
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
    );
  }

  // ── Emoji picker modal ──────────────────────────────────────────────────────
  void _pickEmoji() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: TC.border(context),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('Choose Icon',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                    color: TC.text(context))),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _kEmojis.length,
              itemBuilder: (_, i) {
                final em = _kEmojis[i];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _emoji = em);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: em == _emoji
                          ? _accent.withValues(alpha: 0.15)
                          : TC.card2(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: em == _emoji ? _accent : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(em,
                        style: const TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable form widgets ────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700,
      color: TC.text3(context), letterSpacing: 1.5,
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final String? error;
  final void Function(String)? onChanged;
  final TextInputType? keyboardType;
  const _Field({
    required this.controller,
    required this.hint,
    this.prefix,
    this.error,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Container(
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError ? AppColors.red : TC.border(context),
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
            color: TC.text(context)),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          prefixStyle: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: TC.text2(context)),
          hintStyle: TextStyle(color: TC.text3(context)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          errorText: error,
          errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: TC.card(context),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: TC.border(context)),
    ),
    child: DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      underline: const SizedBox(),
      dropdownColor: TC.card(context),
      style: TextStyle(fontSize: 13, color: TC.text(context),
          fontWeight: FontWeight.w600),
      icon: Icon(Icons.keyboard_arrow_down, color: TC.text2(context)),
    ),
  );
}

class _DayPicker extends StatelessWidget {
  final int selected;
  final int max;
  final String Function(int) label;
  final Color accent;
  final void Function(int) onSelect;
  const _DayPicker({
    required this.selected, required this.max,
    required this.label, required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: max,
        itemBuilder: (ctx, i) {
          final day    = i + 1;
          final active = selected == day;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(day);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 40, height: 40,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: active ? accent : TC.card(ctx),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? accent : TC.border(ctx),
                ),
              ),
              alignment: Alignment.center,
              child: Text('$day',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: active ? Colors.white : TC.text2(ctx),
                  )),
            ),
          );
        },
      ),
    );
  }
}

class _SaveButton extends StatefulWidget {
  final String label;
  final Color accent;
  final bool loading;
  final VoidCallback onTap;
  const _SaveButton({
    required this.label, required this.accent,
    required this.loading, required this.onTap,
  });
  @override
  State<_SaveButton> createState() => _SaveButtonState();
}
class _SaveButtonState extends State<_SaveButton> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => setState(() => _scale = 0.96),
    onTapUp:     (_) { setState(() => _scale = 1.0); widget.onTap(); },
    onTapCancel: () => setState(() => _scale = 1.0),
    child: AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: widget.accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.40),
              blurRadius: 16, offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: widget.loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
              )
            : Text(widget.label,
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800,
                  fontSize: 16,
                )),
      ),
    ),
  );
}
