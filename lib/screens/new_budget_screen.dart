import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../utils/icon_map.dart';

/// Create / edit a named budget (Phase A — Wallet-style).
class NewBudgetScreen extends StatefulWidget {
  final Budget? existing;
  const NewBudgetScreen({super.key, this.existing});

  @override
  State<NewBudgetScreen> createState() => _NewBudgetScreenState();
}

class _NewBudgetScreenState extends State<NewBudgetScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late String _period;
  late String _currency;
  late List<String> _categories; // empty = All
  late bool _notify;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(
        text: e != null && e.amount > 0 ? e.amount.toStringAsFixed(0) : '');
    _period = e?.period ?? 'monthly';
    _categories = List<String>.from(e?.categories ?? const []);
    _notify = e?.notifyOverspent ?? true;
    final state = context.read<AppState>();
    _currency = e?.currency ??
        state.homeCurrency ??
        (state.wallets.keys.isNotEmpty ? state.wallets.keys.first : 'USD');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (name.isEmpty) {
      _toast('Give the budget a name');
      return;
    }
    if (amount <= 0) {
      _toast('Enter an amount');
      return;
    }
    setState(() => _saving = true);
    final state = context.read<AppState>();
    try {
      if (widget.existing == null) {
        await state.addBudget(
            name: name,
            amount: amount,
            currency: _currency,
            period: _period,
            categories: _categories,
            notifyOverspent: _notify);
      } else {
        await state.updateBudget(widget.existing!.copyWith(
            name: name,
            amount: amount,
            currency: _currency,
            period: _period,
            categories: _categories,
            notifyOverspent: _notify));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _toast('Could not save budget');
        setState(() => _saving = false);
      }
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m, style: TC.geist(context))));

  String _sym(String code) => AppState.currencies
      .firstWhere((c) => c.code == code,
          orElse: () => CurrencyData(code, code, '💰', code))
      .sym;

  void _pickCurrency() {
    HapticFeedback.lightImpact();
    String q = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          final list = AppState.currencies.where((c) {
            if (q.isEmpty) return true;
            final s = q.toLowerCase();
            return c.code.toLowerCase().contains(s) ||
                c.name.toLowerCase().contains(s);
          }).toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * 0.7,
              child: Column(children: [
                const SizedBox(height: 10),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: TC.border(context))),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(children: [
                      Icon(Icons.search_rounded, size: 18, color: TC.text3(context)),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(
                        autofocus: true,
                        style: TC.geist(context, fontSize: 14),
                        decoration: InputDecoration(hintText: 'Search currency', hintStyle: TC.geist(context, fontSize: 14, color: TC.text3(context)), border: InputBorder.none, isDense: true),
                        onChanged: (v) => setSheet(() => q = v),
                      )),
                    ]),
                  ),
                ),
                Expanded(child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return ListTile(
                      leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                      title: Text('${c.code} — ${c.name}', style: TC.geist(context, fontSize: 14, fontWeight: FontWeight.w600, color: TC.text(context))),
                      trailing: c.code == _currency ? Icon(Icons.check_circle_rounded, color: TC.primary(context), size: 20) : null,
                      onTap: () { HapticFeedback.selectionClick(); setState(() => _currency = c.code); Navigator.pop(sheetCtx); },
                    );
                  },
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _toggleCat(String key) {
    setState(() {
      if (_categories.contains(key)) {
        _categories.remove(key);
      } else {
        _categories.add(key);
      }
    });
  }

  Widget _checkbox(bool sel, Color color) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: sel ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: sel ? color : TC.border(context), width: 1.6),
        ),
        child: sel ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
      );

  void _pickCategories() {
    HapticFeedback.lightImpact();
    const cats = AppState.expenseCategories;
    final expanded = <String>{};
    Color catColor(String hex) =>
        Color(int.tryParse(hex.replaceAll('#', '0xFF')) ?? 0xFF0D7377);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          final allSelected = _categories.isEmpty;
          void toggle(String key) {
            HapticFeedback.selectionClick();
            _toggleCat(key);
            setSheet(() {});
          }

          return SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.8,
            child: Column(children: [
              const SizedBox(height: 10),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: TC.border(context), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
                child: Row(children: [
                  Text('Categories', style: TC.gloock(context, fontSize: 18, color: TC.text(context))),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetCtx),
                    child: Text('Done', style: TC.geist(context, fontSize: 13, fontWeight: FontWeight.w700, color: TC.primary(context))),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Pick whole categories, or expand one to target specific subcategories.',
                    style: TC.geist(context, fontSize: 11.5, color: TC.text3(context), height: 1.4)),
              ),
              // All categories
              InkWell(
                onTap: () { HapticFeedback.selectionClick(); setState(() => _categories = []); setSheet(() {}); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  child: Row(children: [
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: TC.primary(context).withValues(alpha: 0.14), shape: BoxShape.circle), child: Icon(Icons.all_inclusive_rounded, size: 18, color: TC.primary(context))),
                    const SizedBox(width: 12),
                    Expanded(child: Text('All categories', style: TC.geist(context, fontSize: 14.5, fontWeight: FontWeight.w600, color: TC.text(context)))),
                    _checkbox(allSelected, TC.primary(context)),
                  ]),
                ),
              ),
              Divider(color: TC.border(context), height: 1),
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: cats.length,
                itemBuilder: (_, i) {
                  final c = cats[i];
                  final subs = AppState.subsFor(c.icon);
                  final color = catColor(c.color);
                  final parentSel = _categories.contains(c.icon);
                  final isOpen = expanded.contains(c.icon);
                  final selectedSubs = subs.where((s) => _categories.contains(s.icon)).length;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    InkWell(
                      onTap: subs.isEmpty
                          ? () => toggle(c.icon)
                          : () => setSheet(() { isOpen ? expanded.remove(c.icon) : expanded.add(c.icon); }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        child: Row(children: [
                          Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle), child: Icon(c.materialIcon ?? iconForEmoji(c.icon), size: 18, color: color)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.label, style: TC.geist(context, fontSize: 14.5, fontWeight: FontWeight.w600, color: TC.text(context))),
                            if (subs.isNotEmpty)
                              Text(selectedSubs > 0 ? '$selectedSubs of ${subs.length} selected' : '${subs.length} subcategories',
                                  style: TC.geist(context, fontSize: 11, color: selectedSubs > 0 ? color : TC.text3(context))),
                          ])),
                          GestureDetector(onTap: () => toggle(c.icon), child: _checkbox(parentSel, color)),
                          if (subs.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: TC.text3(context)),
                          ],
                        ]),
                      ),
                    ),
                    if (isOpen)
                      ...subs.map((s) {
                        final sel = _categories.contains(s.icon);
                        return InkWell(
                          onTap: () => toggle(s.icon),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(66, 7, 20, 7),
                            child: Row(children: [
                              Icon(s.materialIcon ?? Icons.category_rounded, size: 16, color: color),
                              const SizedBox(width: 10),
                              Expanded(child: Text(s.label, style: TC.geist(context, fontSize: 13.5, fontWeight: FontWeight.w500, color: TC.text2(context)))),
                              _checkbox(sel, color),
                            ]),
                          ),
                        );
                      }),
                    Divider(color: TC.border(context), height: 1, indent: 20, endIndent: 20),
                  ]);
                },
              )),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: TC.card(context), shape: BoxShape.circle, border: Border.all(color: TC.border(context))),
                      alignment: Alignment.center,
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: TC.text(context)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BUDGET', style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: TC.primaryMd(context))),
                      Text(isEdit ? 'Edit Budget' : 'New Budget', style: TC.gloock(context, fontSize: 22, color: TC.text(context), letterSpacing: -0.4)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                children: [
                  _label('Name'),
                  _fieldBox(TextField(
                    controller: _nameCtrl,
                    style: TC.geist(context, fontSize: 15, color: TC.text(context)),
                    decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: 'e.g. Monthly spending', hintStyle: TC.geist(context, color: TC.text3(context))),
                  )),
                  const SizedBox(height: 16),
                  _label('Period'),
                  Row(children: [
                    _periodChip('Weekly', 'weekly'),
                    const SizedBox(width: 8),
                    _periodChip('Monthly', 'monthly'),
                    const SizedBox(width: 8),
                    _periodChip('Yearly', 'yearly'),
                  ]),
                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('Amount'),
                      _fieldBox(TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TC.gloock(context, fontSize: 20, color: TC.text(context)),
                        decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: '0', hintStyle: TC.gloock(context, fontSize: 20, color: TC.text3(context))),
                      )),
                    ])),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('Currency'),
                      GestureDetector(
                        onTap: _pickCurrency,
                        child: _boxDeco(child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${_sym(_currency)} $_currency', style: TC.geist(context, fontSize: 15, fontWeight: FontWeight.w700, color: TC.text(context))),
                          const SizedBox(width: 6),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: TC.text3(context)),
                        ])),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  _label('Categories'),
                  GestureDetector(
                    onTap: _pickCategories,
                    child: _boxDeco(
                      full: true,
                      child: Row(children: [
                        Expanded(child: _categories.isEmpty
                            ? Text('All categories',
                                style: TC.geist(context, fontSize: 15, fontWeight: FontWeight.w500, color: TC.text(context)))
                            : Row(children: [
                                Text('${_categories.length} selected',
                                    style: TC.geist(context, fontSize: 15, fontWeight: FontWeight.w600, color: TC.text(context))),
                                const SizedBox(width: 8),
                                Expanded(child: ClipRect(child: Row(
                                  children: _categories.take(8).map((k) => Padding(
                                    padding: const EdgeInsets.only(right: 5),
                                    child: Icon(iconForEmoji(k), size: 16, color: colorForEmoji(k, fallback: TC.text2(context))),
                                  )).toList(),
                                ))),
                              ])),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: TC.text3(context)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _boxDeco(
                    full: true,
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Notify when overspent', style: TC.geist(context, fontSize: 14, fontWeight: FontWeight.w600, color: TC.text(context))),
                        const SizedBox(height: 2),
                        Text('Alert when spending exceeds the budget', style: TC.geist(context, fontSize: 11, color: TC.text3(context))),
                      ])),
                      Switch(
                        value: _notify,
                        activeTrackColor: TC.primary(context),
                        onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _notify = v); },
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: TC.primary(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: TC.primaryGlow(context), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      alignment: Alignment.center,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEdit ? 'Save Changes' : 'Create Budget', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t.toUpperCase(),
            style: TC.geist(context, fontSize: 11, fontWeight: FontWeight.w700, color: TC.text3(context), letterSpacing: 1.2)),
      );

  Widget _fieldBox(Widget child) => _boxDeco(full: true, child: child);

  Widget _boxDeco({required Widget child, bool full = false}) => Container(
        width: full ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: TC.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TC.border(context)),
        ),
        child: child,
      );

  Widget _periodChip(String label, String value) {
    final sel = _period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); setState(() => _period = value); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? TC.primary(context) : TC.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? TC.primary(context) : TC.border(context)),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TC.geist(context, fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : TC.text2(context))),
        ),
      ),
    );
  }
}
