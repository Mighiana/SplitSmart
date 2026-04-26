import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';
import '../services/voice_input_service.dart';
import '../services/smart_suggestions_service.dart';
import '../widgets/common_widgets.dart';

/// Pass [existing] to pre-fill the form for editing.
class AddExpenseScreen extends StatefulWidget {
  final ExpenseData? existing;
  const AddExpenseScreen({super.key, this.existing});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amtKey = GlobalKey<AmountDisplayState>();
  final _descCtrl = TextEditingController();

  String _amount = '0';
  String _cat = '🍽️';
  String _payer = 'You';
  String _split = 'equal';
  String _date = '';
  bool _receipt = false;
  String? _receiptPath;
  bool _isEdit = false;
  bool _isSaving = false;
  bool _isListening = false;
  String _voiceText = '';

  // Custom split — one controller per member
  final Map<String, TextEditingController> _customControllers = {};

  // Percentage split — one controller per member (values sum to 100)
  final Map<String, TextEditingController> _percentControllers = {};

  // Shares split — integer share count per member (default 1)
  final Map<String, int> _sharesMap = {};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _isEdit = true;
      _amount =
          e.amount.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      _descCtrl.text = e.desc;
      _cat = e.cat;
      _payer = e.paidBy;
      _date = e.date;
      _receipt = e.receipt;
      _receiptPath = e.receiptPath;

      if (e.splits != null && e.splits!.isNotEmpty) {
        _split = 'custom';
        for (final entry in e.splits!.entries) {
          _customControllers[entry.key] =
              TextEditingController(text: entry.value.toStringAsFixed(2));
        }
      }
    }
  }

  /// Pre-fill equal amounts only for members that don't already have a value.
  void _initCustomSplits(List<String> members) {
    final amt = double.tryParse(_amount) ?? 0;
    final equal = members.isEmpty ? 0.0 : amt / members.length;
    for (final m in members) {
      if (!_customControllers.containsKey(m)) {
        _customControllers[m] =
            TextEditingController(text: equal.toStringAsFixed(2));
      }
    }
  }

  /// Pre-fill equal percentages for the % split mode.
  void _initPercentSplits(List<String> members) {
    if (members.isEmpty) return;
    final equal = (100 / members.length);
    for (int i = 0; i < members.length; i++) {
      final m = members[i];
      if (!_percentControllers.containsKey(m)) {
        // Last member gets the remainder so it sums to exactly 100
        final pct = (i == members.length - 1)
            ? (100 - equal * (members.length - 1))
            : equal;
        _percentControllers[m] =
            TextEditingController(text: pct.toStringAsFixed(1));
      }
    }
    for (final m in members) {
      _sharesMap.putIfAbsent(m, () => 1);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    for (final c in _customControllers.values) c.dispose();
    for (final c in _percentControllers.values) c.dispose();
    super.dispose();
  }

  void _onKey(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == 'del') {
        _amount = _amount.length > 1
            ? _amount.substring(0, _amount.length - 1)
            : '0';
      } else if (k == '.' && _amount.contains('.')) {
        return;
      } else {
        _amount = _amount == '0' ? k : _amount + k;
      }
    });
  }

  Future<void> _pickReceipt() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Attach Receipt',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Text('📷', style: TextStyle(fontSize: 22)),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Text('🖼️', style: TextStyle(fontSize: 22)),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final img = await picker.pickImage(source: source, imageQuality: 80);
      if (img != null && mounted) {
        final appDir = await getApplicationDocumentsDirectory();
        final receiptsDir = Directory(p.join(appDir.path, 'receipts'));
        await receiptsDir.create(recursive: true);

        final filename = 'exp_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final saved = await File(img.path).copy(p.join(receiptsDir.path, filename));

        HapticFeedback.mediumImpact();
        setState(() {
          _receipt = true;
          _receiptPath = saved.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to attach receipt: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final g = state.currentGroup;
    if (g == null) {
      // Guard: currentGroup must be set before opening this screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No group selected')),
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: TC.card(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: TC.border(context)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '←',
                      style: TextStyle(
                        fontSize: 18,
                        color: TC.text(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit Expense' : 'Add Expense',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: TC.text(context),
                    ),
                  ),
                ),
                Text(
                  '${g.emoji} ${g.name}',
                  style: TextStyle(fontSize: 12, color: TC.text3(context)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Smart Input Bar ──────────────────────────────────────
            if (!_isEdit)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    _SmartActionButton(
                      icon: '🎤',
                      label: _isListening ? 'Listening...' : 'Voice (English only)',
                      isLoading: _isListening,
                      color: AppColors.amber,
                      onTap: () => _toggleVoice(g),
                    ),
                  ],
                ),
              ),

            // Voice feedback
            if (_isListening || _voiceText.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    _isListening
                        ? const Text('🔴', style: TextStyle(fontSize: 16))
                        : const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isListening
                            ? (_voiceText.isEmpty ? 'Speak now...' : _voiceText)
                            : '"$_voiceText"',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: TC.text(context),
                          fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                    if (!_isListening && _voiceText.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _voiceText = ''),
                        child: Icon(Icons.close, size: 18, color: TC.text3(context)),
                      ),
                  ],
                ),
              ),

            // Amount display
            AmountDisplay(key: _amtKey, amount: _amount, symbol: g.sym),
            const SizedBox(height: 16),

            // Numpad
            SSNumpad(onKey: _onKey),
            const SizedBox(height: 20),

            // Description
            _label('Description'),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Dinner, Uber, Groceries...',
              ),
              onChanged: (_) => setState(() {}), // trigger suggestions rebuild
            ),

            // ── Smart Suggestions ─────────────────────────────────────
            Builder(builder: (_) {
              final suggestions = SmartSuggestionsService.instance
                  .getMatchingSuggestions(state, _descCtrl.text);
              if (suggestions.isEmpty && _descCtrl.text.length < 2) {
                // Show top frequent suggestions when field is empty
                final top = SmartSuggestionsService.instance.getSuggestions(state);
                if (top.isNotEmpty && !_isEdit) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: top.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final s = top[i];
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _descCtrl.text = s.description;
                                _amount = s.amount.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
                                _cat = s.category;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: TC.card(context),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: TC.border(context)),
                              ),
                              child: Text(
                                '${s.category} ${s.description}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TC.text2(context)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }
              }
              if (suggestions.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: suggestions.map((s) {
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _descCtrl.text = s.description;
                            _amount = s.amount.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
                            _cat = s.category;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.greenDim,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${s.category} ${s.description} · ${g.sym}${s.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 20),

            // Category
            _label('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppState.expenseCategories
                  .map(
                    (c) => SSChip(
                      label: '${c.icon} ${c.label}',
                      active: c.icon == _cat,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _cat = c.icon);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),

            // Paid by
            _label('Paid By'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: g.members.map((m) {
                  final active = m == _payer;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _payer = m);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active ? AppColors.greenDim : AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? AppColors.green : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        m,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? AppColors.green : AppColors.text2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Split mode selector ────────────────────────────────────
            _label('Split'),
            // 4-chip pill row: Equal | % | Shares | Custom
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TC.border(context)),
              ),
              child: Row(
                children: [
                  _splitChip(context, 'Equal', 'equal'),
                  _splitChip(context, '%', 'percent'),
                  _splitChip(context, 'Shares', 'shares'),
                  _splitChip(context, 'Custom', 'custom'),
                ],
              ),
            ),

            // ── Equal: nothing extra needed ────────────────────────────

            // ── Percentage split fields ────────────────────────────────
            if (_split == 'percent')
              Builder(builder: (ctx) {
                final g = ctx.read<AppState>().currentGroup;
                if (g == null) return const SizedBox.shrink();
                _initPercentSplits(g.members);
                double totalPct = 0;
                for (final m in g.members) {
                  totalPct += double.tryParse(
                          _percentControllers[m]?.text ?? '0') ?? 0;
                }
                final pctOk = (totalPct - 100).abs() < 0.6;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('PERCENTAGE PER PERSON',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TC.text3(ctx), letterSpacing: 1.5)),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: pctOk ? AppColors.greenDim : AppColors.redDim,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pctOk ? '✓ 100%' : '${totalPct.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: pctOk ? AppColors.green : AppColors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...g.members.map((m) {
                      _percentControllers.putIfAbsent(m, () =>
                          TextEditingController(text: '0.0'));
                      final amt = double.tryParse(_amount) ?? 0;
                      final pct = double.tryParse(_percentControllers[m]?.text ?? '0') ?? 0;
                      final computed = amt * pct / 100;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            AvatarCircle(label: m, size: 32),
                            const SizedBox(width: 10),
                            Expanded(child: Text(m,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: TC.text(ctx)))),
                            // computed $ preview
                            Text('${g.sym}${computed.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 12, color: TC.text2(ctx))),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _percentControllers[m],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.end,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(ctx)),
                                decoration: const InputDecoration(
                                  suffixText: '%',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              }),

            // ── Shares split fields ────────────────────────────────────
            if (_split == 'shares')
              Builder(builder: (ctx) {
                final g = ctx.read<AppState>().currentGroup;
                if (g == null) return const SizedBox.shrink();
                for (final m in g.members) _sharesMap.putIfAbsent(m, () => 1);
                final totalShares = g.members.fold<int>(0, (s, m) => s + (_sharesMap[m] ?? 1));
                final amt = double.tryParse(_amount) ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('SHARES PER PERSON',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TC.text3(ctx), letterSpacing: 1.5)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.greenDim,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$totalShares total shares',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...g.members.map((m) {
                      final myShares = _sharesMap[m] ?? 1;
                      final myAmt = totalShares > 0 ? amt * myShares / totalShares : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            AvatarCircle(label: m, size: 32),
                            const SizedBox(width: 10),
                            Expanded(child: Text(m,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: TC.text(ctx)))),
                            // computed $
                            Text('${g.sym}${myAmt.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 12, color: TC.text2(ctx))),
                            const SizedBox(width: 12),
                            // minus button
                            GestureDetector(
                              onTap: () {
                                if (myShares > 1) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _sharesMap[m] = myShares - 1);
                                }
                              },
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: TC.card(ctx),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: TC.border(ctx)),
                                ),
                                alignment: Alignment.center,
                                child: Text('−', style: TextStyle(fontSize: 18, color: myShares > 1 ? TC.text(ctx) : TC.text3(ctx))),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${myShares}x',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: TC.text(ctx))),
                            const SizedBox(width: 8),
                            // plus button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _sharesMap[m] = myShares + 1);
                              },
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.greenDim,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                                ),
                                alignment: Alignment.center,
                                child: const Text('+', style: TextStyle(fontSize: 18, color: AppColors.green)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              }),

            // ── Custom (exact $) split fields ──────────────────────────
            if (_split == 'custom')
              Builder(
                builder: (context) {
                  final g = context.read<AppState>().currentGroup;
                  if (g == null) return const SizedBox.shrink();
                  final total = double.tryParse(_amount) ?? 0;
                  final splitTotal = g.members.fold(0.0, (sum, m) {
                    final ctrl = _customControllers[m];
                    return sum + (ctrl != null ? (double.tryParse(ctrl.text) ?? 0) : 0.0);
                  });
                  final diff = (splitTotal - total).abs();
                  final isValid = diff < 0.01;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('AMOUNTS PER PERSON',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TC.text3(context), letterSpacing: 1.5)),
                          const Spacer(),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isValid ? AppColors.greenDim : AppColors.redDim,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isValid ? '✓ Balanced' : 'Δ ${g.sym}${diff.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                  color: isValid ? AppColors.green : AppColors.red),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...g.members.map((m) {
                        _customControllers.putIfAbsent(m, () => TextEditingController(text: '0.00'));
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              AvatarCircle(label: m, size: 32),
                              const SizedBox(width: 10),
                              Expanded(child: Text(m,
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: TC.text(context)))),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _customControllers[m],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(context)),
                                  decoration: InputDecoration(
                                    prefixText: '${g.sym} ',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            const SizedBox(height: 20),

            // Receipt
            _label('Receipt (optional)'),
            if (!_receipt)
              GestureDetector(
                onTap: _pickReceipt,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: TC.border(context),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Text('📷', style: TextStyle(fontSize: 28)),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to attach receipt photo',
                        style: TextStyle(
                          fontSize: 13,
                          color: TC.text2(context),
                        ),
                      ),
                      Text(
                        'Camera or gallery',
                        style: TextStyle(
                          fontSize: 11,
                          color: TC.text3(context),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: _pickReceipt,
                child: Container(
                  height: _receiptPath != null ? 180 : null,
                  padding: _receiptPath != null
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _receiptPath != null
                        ? Colors.transparent
                        : AppColors.greenDim,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: _receiptPath != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.file(
                                  File(_receiptPath!),
                                  fit: BoxFit.cover,
                                ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _receipt = false;
                                    _receiptPath = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.card.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: AppColors.red,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.green,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '📎 Receipt attached',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Text('📎', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Receipt attached',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.green,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _receipt = false;
                                  _receiptPath = null;
                                });
                              },
                              child: const Text(
                                'Remove',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            const SizedBox(height: 28),

            // Save button
            GestureDetector(
              onTap: _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Save Changes →' : 'Save Expense →',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),

            // Delete (only in edit mode)
            if (_isEdit) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _delete,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.redDim,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '🗑  Delete Expense',
                    style: TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: TC.text3(context),
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _splitChip(BuildContext ctx, String label, String mode) {
    final active = _split == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          final g = context.read<AppState>().currentGroup;
          if (g == null) return;
          if (mode == 'custom') _initCustomSplits(g.members);
          if (mode == 'percent') _initPercentSplits(g.members);
          if (mode == 'shares') _initPercentSplits(g.members); // also seeds _sharesMap
          setState(() => _split = mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.black : TC.text2(ctx),
            ),
          ),
        ),
      ),
    );
  }

  void _save() async {

    if (_isSaving) return;
    final amt = double.tryParse(_amount) ?? 0;
    final desc = _descCtrl.text.trim();

    if (amt <= 0) {
      AmountDisplay.shake(_amtKey);
      _showToast('Enter an amount!');
      return;
    }

    // SEC-H2: Prevent extreme values that could break balance calculations
    if (amt > 999999999) {
      AmountDisplay.shake(_amtKey);
      _showToast('Amount is too large!');
      return;
    }

    if (desc.isEmpty) {
      _showToast('Add a description!');
      return;
    }

    // SEC-M2: Enforce description length limit
    if (desc.length > 200) {
      _showToast('Description is too long (max 200 characters)');
      return;
    }

    Map<String, double>? splits;
    final state2 = context.read<AppState>();
    final members = state2.currentGroup?.members ?? [];

    if (_split == 'custom') {
      if (members.isEmpty) { _showToast('No group members found'); return; }
      splits = {};
      double splitTotal = 0;
      for (final m in members) {
        final v = double.tryParse(_customControllers[m]?.text ?? '0') ?? 0;
        splits[m] = v;
        splitTotal += v;
      }
      if ((splitTotal - amt).abs() > 0.01) {
        _showToast('Custom split must add up to ${state2.currentGroup?.sym ?? ''}${amt.toStringAsFixed(2)}');
        return;
      }
    } else if (_split == 'percent') {
      if (members.isEmpty) { _showToast('No group members found'); return; }
      double totalPct = 0;
      for (final m in members) {
        totalPct += double.tryParse(_percentControllers[m]?.text ?? '0') ?? 0;
      }
      if ((totalPct - 100).abs() > 0.6) {
        _showToast('Percentages must add up to 100% (currently ${totalPct.toStringAsFixed(1)}%)');
        return;
      }
      splits = {};
      for (final m in members) {
        final pct = double.tryParse(_percentControllers[m]?.text ?? '0') ?? 0;
        splits[m] = amt * pct / 100;
      }
    } else if (_split == 'shares') {
      if (members.isEmpty) { _showToast('No group members found'); return; }
      final totalShares = members.fold<int>(0, (s, m) => s + (_sharesMap[m] ?? 1));
      splits = {};
      for (final m in members) {
        final myShares = _sharesMap[m] ?? 1;
        splits[m] = totalShares > 0 ? amt * myShares / totalShares : 0;
      }
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    final state = context.read<AppState>();
    final g = state.currentGroup;
    if (g == null) {
      _showToast('No group selected');
      setState(() => _isSaving = false);
      return;
    }
    final dateToSave = _isEdit ? _date : _todayStr();

    final newExp = ExpenseData(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch,
      desc: desc,
      amount: amt,
      cat: _cat,
      paidBy: _payer,
      date: dateToSave,
      receipt: _receipt,
      receiptPath: _receiptPath,
      splits: splits,
      createdBy: _isEdit ? widget.existing?.createdBy : 'You',
      updatedBy: _isEdit ? 'You' : null,
    );

    try {
      if (_isEdit && widget.existing != null) {
        await state.editExpenseInGroup(g, widget.existing!, newExp);
        await AnalyticsService.logExpenseEdited();
      } else {
        await state.addExpenseToGroup(g, newExp);
        await AnalyticsService.logExpenseAdded(
          isCustomSplit: _split != 'equal',
          hasReceipt: _receipt,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showToast('Failed to save expense: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  void _delete() {
    HapticFeedback.heavyImpact();
    // SEC-L5: Capture state before dialog to avoid stale context
    final state = context.read<AppState>();
    final g = state.currentGroup;
    final existing = widget.existing;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Delete expense?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.text2),
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              if (g != null && existing != null) {
                state.deleteExpense(g, existing);
                AnalyticsService.logExpenseDeleted();
              }
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _todayStr() => AppDateUtils.todayStr();

  void _showToast(String msg, {IconData? icon, Color? iconColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? AppColors.green, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(msg)),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }



  // ─── Voice Input ────────────────────────────────────────────────────
  Future<void> _toggleVoice(GroupData g) async {
    final voice = VoiceInputService.instance;

    if (_isListening) {
      await voice.stopListening();
      setState(() => _isListening = false);
      // Parse final text
      if (_voiceText.isNotEmpty) {
        _applyVoiceResult(g);
      }
      return;
    }

    HapticFeedback.mediumImpact();
    final available = await voice.init();
    if (!available) {
      _showToast('Speech recognition not available on this device');
      return;
    }

    setState(() {
      _isListening = true;
      _voiceText = '';
    });

    await voice.startListening(
      onResult: (text) {
        if (mounted) setState(() => _voiceText = text);
      },
      onDone: () {
        if (mounted) {
          setState(() => _isListening = false);
          if (_voiceText.isNotEmpty) {
            _applyVoiceResult(g);
          }
        }
      },
    );
  }

  void _applyVoiceResult(GroupData g) {
    final result = VoiceInputService.instance.parseSpokenText(_voiceText, g.members);
    HapticFeedback.heavyImpact();

    setState(() {
      if (result.amount != null) {
        _amount = result.amount!.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      }
      if (result.description != null && result.description!.isNotEmpty) {
        _descCtrl.text = result.description!;
      }
      if (result.paidBy != null) {
        _payer = result.paidBy!;
      }
    });

    if (result.hasData) {
      _showToast('Got it!${result.amount != null ? " ${g.sym}${result.amount!.toStringAsFixed(2)}" : ""}${result.description != null ? " — ${result.description}" : ""}', icon: Icons.check_circle_rounded, iconColor: AppColors.green);
    }
  }
}

// ─── Smart Action Button Widget ─────────────────────────────────────────
class _SmartActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool isLoading;
  final Color color;
  final VoidCallback? onTap;

  const _SmartActionButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isLoading
                ? color.withValues(alpha: 0.15)
                : TC.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLoading ? color : TC.border(context),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                )
              else
                Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isLoading ? color : TC.text(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
