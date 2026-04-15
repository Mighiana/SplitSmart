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
import '../widgets/common_widgets.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionData? existing;
  final String? fixedCurrency;
  const AddTransactionScreen({super.key, this.existing, this.fixedCurrency});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amtKey = GlobalKey<AmountDisplayState>();
  final _descCtrl = TextEditingController();

  String _amount = '0';
  String _type = 'expense';
  String _cat = '🍽️';
  String? _receiptPath;
  bool _isEdit = false;
  bool _isSaving = false;
  CurrencyData _currency = AppState.currencies.first;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _isEdit = true;
      _type = e.type;
      _amount =
          e.amount.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      _descCtrl.text = e.desc;
      _cat = e.cat;
      _receiptPath = e.receiptPath;
      _currency = AppState.currencies.firstWhere(
        (c) => c.code == e.currency,
        orElse: () => AppState.currencies.first,
      );
    } else if (widget.fixedCurrency != null) {
      _currency = AppState.currencies.firstWhere(
        (c) => c.code == widget.fixedCurrency,
        orElse: () => AppState.currencies.first,
      );
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
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

  List<CategoryItem> get _cats => _type == 'income'
      ? AppState.incomeCategories
      : AppState.expenseCategories;

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
            const SizedBox(height: 16),
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

        final filename = 'txn_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final saved = await File(img.path).copy(p.join(receiptsDir.path, filename));
        HapticFeedback.mediumImpact();
        setState(() => _receiptPath = saved.path);
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
    final isExpense = _type == 'expense';
    final color = isExpense ? AppColors.red : AppColors.green;

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
                Text(
                  _isEdit ? 'Edit Transaction' : 'Personal Transaction',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: TC.text(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Type selector
            Row(
              children: [
                Expanded(
                  child: SSChip(
                    label: '💸 Expense',
                    active: isExpense,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _type = 'expense';
                        _cat = AppState.expenseCategories.first.icon;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SSChip(
                    label: '💰 Income',
                    active: !isExpense,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _type = 'income';
                        _cat = AppState.incomeCategories.first.icon;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount display
            AmountDisplay(
              key: _amtKey,
              amount: _amount,
              symbol: _currency.sym,
              color: color,
              label: 'Amount',
            ),
            const SizedBox(height: 16),

            // Numpad
            SSNumpad(onKey: _onKey),
            const SizedBox(height: 20),

            // Description
            _label('Description'),
            TextField(
              controller: _descCtrl,
              style: TextStyle(color: TC.text(context), fontSize: 15),
              decoration:
                  const InputDecoration(hintText: 'What was this for?'),
            ),
            const SizedBox(height: 20),

            // Category
            _label('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _cats
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

            // Currency
            if (widget.fixedCurrency == null) ...[
              _label('Currency'),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _pickCurrency(context);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: TC.card(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: TC.border(context), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_currency.flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        '${_currency.code} — ${_currency.name}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: TC.text(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('▾', style: TextStyle(color: TC.text3(context))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Receipt
            _label('Receipt (optional)'),
            if (_receiptPath == null)
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReceiptViewer(
                      imagePath: _receiptPath!,
                      title: 'Receipt Preview',
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(_receiptPath!),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _receiptPath = null);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
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
                ),
              ),
            const SizedBox(height: 28),

            // Save
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _save();
              },
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
                        _isEdit ? 'Save Changes →' : 'Save →',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
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

  void _save() async {
    if (_isSaving) return;
    final amt = double.tryParse(_amount) ?? 0;
    final desc = _descCtrl.text.trim();

    if (amt <= 0) {
      AmountDisplay.shake(_amtKey);
      _showToast('Enter an amount!');
      return;
    }
    if (desc.isEmpty) {
      _showToast('Add a description!');
      return;
    }

    setState(() => _isSaving = true);

    final state = context.read<AppState>();
    final updated = TransactionData(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch,
      type: _type,
      desc: desc,
      amount: amt,
      cat: _cat,
      currency: _currency.code,
      sym: _currency.sym,
      date: widget.existing?.date ?? AppDateUtils.todayStr(),
      receiptPath: _receiptPath,
    );

    try {
      if (_isEdit && widget.existing != null) {
        await state.editTransaction(widget.existing!, updated);
        await AnalyticsService.logTransactionEdited();
      } else {
        await state.addTransaction(updated);
        await AnalyticsService.logTransactionAdded(_type);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showToast('Failed to save transaction: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  void _pickCurrency(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CurrencyPicker(
        onSelect: (c) {
          if (_isEdit && c.code != _currency.code) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: TC.card(context),
                title: Text(
                  'Change currency?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TC.text(context),
                  ),
                ),
                content: Text(
                  'Changing from ${_currency.code} to ${c.code} will update both wallet balances. Make sure both wallets exist.',
                  style: TextStyle(color: TC.text2(context)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: TC.text2(context)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _currency = c);
                    },
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            setState(() => _currency = c);
          }
        },
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _CurrencyPicker extends StatefulWidget {
  final void Function(CurrencyData) onSelect;
  const _CurrencyPicker({required this.onSelect});

  @override
  State<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<_CurrencyPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? AppState.currencies
        : AppState.currencies
            .where(
              (c) =>
                  c.code.toLowerCase().contains(_search.toLowerCase()) ||
                  c.name.toLowerCase().contains(_search.toLowerCase()),
            )
            .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: TC.border(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Currency',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: TC.text(context),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  style: TextStyle(color: TC.text(context), fontSize: 15),
                  decoration: const InputDecoration(hintText: '🔍  Search...'),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final c = filtered[i];
                return GestureDetector(
                  onTap: () {
                    widget.onSelect(c);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: TC.border(context)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.code,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: TC.text(context),
                                ),
                              ),
                              Text(
                                c.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: TC.text2(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          c.sym,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
