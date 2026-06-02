import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
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
    for (final c in _customControllers.values) {
      c.dispose();
    }
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _receiptPreviewImage(String path) {
    final isRemote = path.startsWith('http://') || path.startsWith('https://');
    if (isRemote) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _receiptPreviewError(),
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _receiptPreviewError(),
    );
  }

  Widget _receiptPreviewError() {
    return Container(
      color: TC.erPale(context),
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, color: TC.er(context)),
    );
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TC.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Attach Receipt',
                style: TC.geist(context, fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Text('📷', style: TextStyle(fontSize: 22)),
                title: Text('Take a photo', style: TC.geist(context)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Text('🖼️', style: TextStyle(fontSize: 22)),
                title: Text('Choose from gallery', style: TC.geist(context)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
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
            content: Text('Failed to attach receipt: $e', style: TC.geist(context)),
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No group selected', style: TC.geist(context))),
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
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
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: TC.text(context), size: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit Expense' : 'Add Expense',
                    style: TC.gloock(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TC.text(context),
                    ),
                  ),
                ),
                Text(
                  '${g.emoji} ${g.name}',
                  style: TC.geist(context, fontSize: 12, fontWeight: FontWeight.w600, color: TC.text3(context)),
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
                      color: TC.wn(context),
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
                  color: TC.wnPale(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TC.wn(context).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    _isListening
                        ? const Text('🔴', style: TextStyle(fontSize: 16))
                        : Icon(Icons.check_circle_rounded, color: TC.ok(context), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isListening
                            ? (_voiceText.isEmpty ? 'Speak now...' : _voiceText)
                            : '"$_voiceText"',
                        style: TC.geist(
                          context,
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: TC.text(context),
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
              style: TC.geist(context, fontSize: 15, color: TC.text(context)),
              decoration: InputDecoration(
                hintText: 'Dinner, Uber, Groceries...',
                hintStyle: TC.geist(context, color: TC.text3(context)),
              ),
              onChanged: (_) => setState(() {}), // trigger suggestions rebuild
            ),

            // ── Smart Suggestions ─────────────────────────────────────
            Builder(builder: (_) {
              final suggestions = SmartSuggestionsService.instance
                  .getMatchingSuggestions(state, _descCtrl.text);
              if (suggestions.isEmpty && _descCtrl.text.length < 2) {
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
                                style: TC.geist(context, fontSize: 12, fontWeight: FontWeight.w600, color: TC.text2(context)),
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
                            color: TC.primaryPale(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: TC.primary(context).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${s.category} ${s.description} · ${g.sym}${s.amount.toStringAsFixed(2)}',
                            style: TC.geist(context, fontSize: 12, fontWeight: FontWeight.w600, color: TC.primary(context)),
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
                    (c) {
                      final isActive = c.icon == _cat;
                      final catColor = Color(
                        int.tryParse(c.color.replaceAll('#', '0xFF')) ?? 0xFF1E7D4F,
                      );
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _cat = c.icon);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? catColor.withValues(alpha: 0.15)
                                : TC.card(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isActive ? catColor : TC.border(context),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: isActive ? 0.25 : 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  c.materialIcon ?? Icons.category_rounded,
                                  size: 14,
                                  color: catColor,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                c.label,
                                style: TC.geist(
                                  context,
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  color: isActive ? catColor : TC.text2(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
                        color: active ? TC.primaryPale(context) : TC.card(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? TC.primary(context) : TC.border(context),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        m,
                        style: TC.geist(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? TC.primary(context) : TC.text2(context),
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
                            style: TC.geist(ctx, fontSize: 11, fontWeight: FontWeight.w700, color: TC.text3(ctx), letterSpacing: 1.5)),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: pctOk ? TC.okPale(ctx) : TC.erPale(ctx),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pctOk ? '✓ 100%' : '${totalPct.toStringAsFixed(1)}%',
                            style: TC.geist(ctx, fontSize: 10, fontWeight: FontWeight.w700,
                                color: pctOk ? TC.ok(ctx) : TC.er(ctx)),
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
                            AvatarCircle(label: m, size: 32, bg: TC.primaryPale(ctx), fg: TC.primary(ctx)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(m,
                                style: TC.geist(ctx, fontWeight: FontWeight.w600, fontSize: 14, color: TC.text(ctx)))),
                            Text('${g.sym}${computed.toStringAsFixed(2)}',
                                style: TC.gloock(ctx, fontSize: 12, color: TC.text2(ctx))),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _percentControllers[m],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.end,
                                style: TC.geist(ctx, fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(ctx)),
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
                for (final m in g.members) {
                  _sharesMap.putIfAbsent(m, () => 1);
                }
                final totalShares = g.members.fold<int>(0, (s, m) => s + (_sharesMap[m] ?? 1));
                final amt = double.tryParse(_amount) ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('SHARES PER PERSON',
                            style: TC.geist(ctx, fontSize: 11, fontWeight: FontWeight.w700, color: TC.text3(ctx), letterSpacing: 1.5)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: TC.primaryPale(ctx),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$totalShares total shares',
                              style: TC.geist(ctx, fontSize: 10, fontWeight: FontWeight.w700, color: TC.primary(ctx))),
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
                            AvatarCircle(label: m, size: 32, bg: TC.primaryPale(ctx), fg: TC.primary(ctx)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(m,
                                style: TC.geist(ctx, fontWeight: FontWeight.w600, fontSize: 14, color: TC.text(ctx)))),
                            Text('${g.sym}${myAmt.toStringAsFixed(2)}',
                                style: TC.gloock(ctx, fontSize: 12, color: TC.text2(ctx))),
                            const SizedBox(width: 12),
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
                                style: TC.geist(ctx, fontSize: 15, fontWeight: FontWeight.w800, color: TC.text(ctx))),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _sharesMap[m] = myShares + 1);
                              },
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: TC.primaryPale(ctx),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: TC.primary(ctx).withValues(alpha: 0.4)),
                                ),
                                alignment: Alignment.center,
                                child: Text('+', style: TextStyle(fontSize: 18, color: TC.primary(ctx))),
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
                              style: TC.geist(context, fontSize: 11, fontWeight: FontWeight.w700, color: TC.text3(context), letterSpacing: 1.5)),
                          const Spacer(),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isValid ? TC.okPale(context) : TC.erPale(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isValid ? '✓ Balanced' : 'Δ ${g.sym}${diff.toStringAsFixed(2)}',
                              style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w700,
                                  color: isValid ? TC.ok(context) : TC.er(context)),
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
                              AvatarCircle(label: m, size: 32, bg: TC.primaryPale(context), fg: TC.primary(context)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(m,
                                  style: TC.geist(context, fontWeight: FontWeight.w600, fontSize: 14, color: TC.text(context)))),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _customControllers[m],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.end,
                                  style: TC.geist(context, fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(context)),
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
                        style: TC.geist(
                          context,
                          fontSize: 13,
                          color: TC.text2(context),
                        ),
                      ),
                      Text(
                        'Camera or gallery',
                        style: TC.geist(
                          context,
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
                        : TC.okPale(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: TC.ok(context).withValues(alpha: 0.3),
                    ),
                  ),
                  child: _receiptPath != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: _receiptPreviewImage(_receiptPath!),
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
                                    color: TC.card(context).withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: TC.er(context),
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
                                  color: TC.ok(context),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '📎 Receipt attached',
                                  style: TC.geist(
                                    context,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
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
                            Expanded(
                              child: Text(
                                'Receipt attached',
                                style: TC.geist(
                                  context,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: TC.ok(context),
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
                              child: Text(
                                'Remove',
                                style: TC.geist(
                                  context,
                                  fontSize: 13,
                                  color: TC.er(context),
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
                  color: TC.primary(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Save Changes →' : 'Save Expense →',
                        style: TC.geist(
                          context,
                          color: Colors.white,
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
                    color: TC.erPale(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: TC.er(context).withValues(alpha: 0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '🗑  Delete Expense',
                    style: TC.geist(
                      context,
                      color: TC.er(context),
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
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TC.geist(
            context,
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
          if (mode == 'shares') _initPercentSplits(g.members);
          setState(() => _split = mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? TC.primary(ctx) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TC.geist(
              ctx,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : TC.text2(ctx),
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

    if (amt > 999999999) {
      AmountDisplay.shake(_amtKey);
      _showToast('Amount is too large!');
      return;
    }

    if (desc.isEmpty) {
      _showToast('Add a description!');
      return;
    }

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
        final errStr = e.toString();
        final String msg;
        if (errStr.contains('permission-denied')) {
          msg = 'Only the person who added this expense can edit it.';
        } else if (errStr.contains('not-found')) {
          msg = 'Expense not found. It may have been deleted.';
        } else {
          msg = 'Could not save expense. Please try again.';
        }
        _showToast(msg, icon: Icons.lock_outline_rounded, iconColor: Colors.orange);
        setState(() => _isSaving = false);
      }
    }
  }

  void _delete() {
    HapticFeedback.heavyImpact();
    final state = context.read<AppState>();
    final g = state.currentGroup;
    final existing = widget.existing;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: TC.card(dialogCtx),
        title: Text(
          'Delete expense?',
          style: TC.geist(dialogCtx, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This action cannot be undone.',
          style: TC.geist(dialogCtx, color: TC.text2(dialogCtx)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(dialogCtx);
            },
            child: Text(
              'Cancel',
              style: TC.geist(dialogCtx, color: TC.text2(dialogCtx)),
            ),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(dialogCtx);
              if (g != null && existing != null) {
                final ok = await state.deleteExpense(g, existing);
                AnalyticsService.logExpenseDeleted();
                if (ok && mounted) {
                  Navigator.pop(context);
                } else if (!ok && mounted) {
                  _showToast('Failed to delete expense. Please try again.');
                }
              }
            },
            child: Text(
              'Delete',
              style: TC.geist(dialogCtx, color: TC.er(dialogCtx), fontWeight: FontWeight.w700),
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
              Icon(icon, color: iconColor ?? TC.ok(context), size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(msg, style: TC.geist(context))),
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
      _showToast(
        'Got it!${result.amount != null ? " ${g.sym}${result.amount!.toStringAsFixed(2)}" : ""}${result.description != null ? " — ${result.description}" : ""}',
        icon: Icons.check_circle_rounded,
        iconColor: TC.ok(context),
      );
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
                style: TC.geist(
                  context,
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
