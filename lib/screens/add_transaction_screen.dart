import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';
import '../widgets/common_widgets.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionData? existing;
  final String? fixedCurrency;
  final String? initialType; // 'expense' or 'income'
  const AddTransactionScreen({super.key, this.existing, this.fixedCurrency, this.initialType});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amtKey = GlobalKey<AmountDisplayState>();
  final _descCtrl = TextEditingController();

  String _amount = '0';
  String _type = 'expense';
  String _cat = '🍽️';
  String? _subcat;
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
      _subcat = e.subcat;
      _receiptPath = e.receiptPath;
      _currency = AppState.currencies.firstWhere(
        (c) => c.code == e.currency,
        orElse: () => AppState.currencies.first,
      );
    } else {
      if (widget.initialType != null) {
        _type = widget.initialType!;
        _cat = _type == 'income'
            ? AppState.incomeCategories.first.icon
            : AppState.expenseCategories.first.icon;
      }
      if (widget.fixedCurrency != null) {
        _currency = AppState.currencies.firstWhere(
          (c) => c.code == widget.fixedCurrency,
          orElse: () => AppState.currencies.first,
        );
      }
      _loadLastCategory();
    }
  }

  /// Pre-select the category the user most recently used for this type, so
  /// the common case is one tap fewer.
  Future<void> _loadLastCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('last_cat_$_type');
    if (saved == null || saved.isEmpty || !mounted) return;
    final list = _type == 'income'
        ? AppState.incomeCategories
        : AppState.expenseCategories;
    if (list.any((c) => c.icon == saved)) setState(() => _cat = saved);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Widget _receiptPreviewImage(String path) {
    final isRemote = path.startsWith('http://') || path.startsWith('https://');
    if (isRemote) {
      return Image.network(
        path,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _receiptPreviewError(),
      );
    }

    return Image.file(
      File(path),
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _receiptPreviewError(),
    );
  }

  Widget _receiptPreviewError() {
    return Container(
      height: 200,
      width: double.infinity,
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
              const SizedBox(height: 16),
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

        final filename = 'txn_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final saved = await File(img.path).copy(p.join(receiptsDir.path, filename));
        HapticFeedback.mediumImpact();
        setState(() => _receiptPath = saved.path);
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
    final isExpense = _type == 'expense';
    final activeColor = isExpense ? TC.er(context) : TC.ok(context);

    return Scaffold(
      backgroundColor: TC.bg(context),
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
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: TC.text(context), size: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isEdit ? 'Edit Transaction' : 'Personal Transaction',
                  style: TC.gloock(
                    context,
                    fontSize: 18,
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
                        _subcat = null;
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
                        _subcat = null;
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
              color: activeColor,
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
              style: TC.geist(context, fontSize: 15, color: TC.text(context)),
              decoration: InputDecoration(
                hintText: 'What was this for?',
                hintStyle: TC.geist(context, color: TC.text3(context)),
              ),
            ),
            const SizedBox(height: 20),

            // Category
            _label('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _cats
                  .map(
                    (c) {
                      final isActive = c.icon == _cat;
                      final catColor = Color(
                        int.tryParse(c.color.replaceAll('#', '0xFF')) ?? 0xFF1E7D4F,
                      );
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() { _cat = c.icon; _subcat = null; });
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
            _subcategorySection(),
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
                        style: TC.geist(
                          context,
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
                      child: _receiptPreviewImage(_receiptPath!),
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
                        _isEdit ? 'Save Changes →' : 'Save →',
                        style: TC.geist(
                          context,
                          color: Colors.white,
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

  /// Optional sub-category dropdown for the selected expense category.
  /// Hidden for income or categories without sub-categories.
  Widget _subcategorySection() {
    if (_type == 'income') return const SizedBox.shrink();
    return SubcategoryDropdown(
      parentCat: _cat,
      value: _subcat,
      onChanged: (v) => setState(() => _subcat = v),
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

  void _save() async {
    if (_isSaving) return;
    final amt = double.tryParse(_amount) ?? 0;
    var desc = _descCtrl.text.trim();

    if (amt <= 0) {
      AmountDisplay.shake(_amtKey);
      _showToast('Enter an amount!');
      return;
    }
    // Description is optional — fall back to the category/subcategory label.
    if (desc.isEmpty) {
      desc = _subcat != null
          ? AppState.labelForKey(_subcat!)
          : AppState.labelForKey(_cat);
    }

    setState(() => _isSaving = true);

    final state = context.read<AppState>();
    final updated = TransactionData(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch,
      type: _type,
      desc: desc,
      amount: amt,
      cat: _cat,
      subcat: _subcat,
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
      // Remember this category as the default for next time (per type).
      SharedPreferences.getInstance()
          .then((p) => p.setString('last_cat_$_type', _cat));
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
                  style: TC.geist(
                    context,
                    fontWeight: FontWeight.w700,
                    color: TC.text(context),
                  ),
                ),
                content: Text(
                  'Changing from ${_currency.code} to ${c.code} will update both wallet balances. Make sure both wallets exist.',
                  style: TC.geist(context, color: TC.text2(context)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TC.geist(context, color: TC.text2(context)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _currency = c);
                    },
                    child: Text(
                      'Change',
                      style: TC.geist(
                        context,
                        color: TC.primary(context),
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
        content: Text(msg, style: TC.geist(context)),
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
                  style: TC.geist(
                    context,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: TC.text(context),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  style: TC.geist(context, color: TC.text(context), fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '🔍  Search...',
                    hintStyle: TC.geist(context, color: TC.text3(context)),
                  ),
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
                                style: TC.geist(
                                  context,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: TC.text(context),
                                ),
                              ),
                              Text(
                                c.name,
                                style: TC.geist(
                                  context,
                                  fontSize: 12,
                                  color: TC.text2(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          c.sym,
                          style: TC.gloock(
                            context,
                            fontWeight: FontWeight.w800,
                            color: TC.primary(context),
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
