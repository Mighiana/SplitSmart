import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';

/// Free "bank import" — let the user import a bank/statement CSV.
/// Pick file → map columns (Date / Description / Amount) + currency → preview → import.
class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  List<List<String>> _rows = [];
  List<String> _headers = [];
  bool _hasHeader = true;
  String? _fileName;
  bool _importing = false;

  int? _dateCol;
  int? _descCol;
  int? _amountCol;
  late String _currency;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _currency = state.homeCurrency ??
        (state.wallets.keys.isNotEmpty ? state.wallets.keys.first : 'USD');
  }

  // ── Minimal CSV parser (handles quoted fields + commas) ──
  List<String> _parseLine(String line) {
    final out = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        out.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    out.add(sb.toString().trim());
    return out;
  }

  Future<void> _pickFile() async {
    HapticFeedback.lightImpact();
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (res == null || res.files.single.path == null) return;
      final path = res.files.single.path!;
      final content = await File(path).readAsString();
      final lines = content
          .split(RegExp(r'\r\n|\r|\n'))
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty) {
        _toast('That file looks empty.');
        return;
      }
      final parsed = lines.map(_parseLine).toList();
      setState(() {
        _fileName = path.split(Platform.pathSeparator).last;
        _rows = parsed;
        _headers = parsed.first;
        _hasHeader = true;
        // Smart-guess column mapping from header names.
        _dateCol = _guess(['date', 'time', 'when']);
        _descCol = _guess(['desc', 'name', 'detail', 'merchant', 'payee', 'memo', 'narration']);
        _amountCol = _guess(['amount', 'value', 'sum', 'debit', 'price']);
      });
    } catch (e) {
      _toast('Could not read file: $e');
    }
  }

  int? _guess(List<String> keys) {
    for (int i = 0; i < _headers.length; i++) {
      final h = _headers[i].toLowerCase();
      if (keys.any((k) => h.contains(k))) return i;
    }
    return null;
  }

  List<List<String>> get _dataRows =>
      _hasHeader && _rows.isNotEmpty ? _rows.sublist(1) : _rows;

  double? _parseAmount(String s) {
    var t = s.replaceAll(RegExp(r'[^0-9eE.,\-]'), '');
    if (t.isEmpty) return null;
    // Treat last separator as decimal; strip the rest (handles 1,234.56 and 1.234,56)
    final lastComma = t.lastIndexOf(',');
    final lastDot = t.lastIndexOf('.');
    if (lastComma > lastDot) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }
    return double.tryParse(t);
  }

  DateTime? _parseDate(String s) {
    final t = s.trim();
    final iso = DateTime.tryParse(t);
    if (iso != null) return iso;
    // Try d/m/y or m/d/y or d.m.y
    final m = RegExp(r'^(\d{1,4})[/.\-](\d{1,2})[/.\-](\d{1,4})').firstMatch(t);
    if (m != null) {
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      var c = int.parse(m.group(3)!);
      // If first part looks like a year
      if (a > 31) return DateTime(a, b, c);
      if (c < 100) c += 2000;
      // assume day-first if a>12
      if (a > 12) return DateTime(c, b, a);
      return DateTime(c, b, a); // default day/month/year
    }
    return null;
  }

  bool get _ready => _dateCol != null && _amountCol != null && _descCol != null;

  Future<void> _import() async {
    if (!_ready || _importing) return;
    setState(() => _importing = true);
    HapticFeedback.mediumImpact();
    final state = context.read<AppState>();
    final sym = AppState.currencies
        .firstWhere((c) => c.code == _currency,
            orElse: () => CurrencyData(_currency, _currency, '💰', _currency))
        .sym;
    // De-dup signature: currency | amount | description | day.
    String sig(String cur, double amount, String desc, DateTime d) =>
        '$cur|${amount.abs().toStringAsFixed(2)}|${desc.trim().toLowerCase()}|${d.year}-${d.month}-${d.day}';
    final seen = <String>{
      for (final t in state.transactions)
        sig(t.currency, t.amount, t.desc,
            t.rawDate ?? DateTime.tryParse(t.date) ?? DateTime(2000)),
    };

    int count = 0, skipped = 0;
    final base = DateTime.now().millisecondsSinceEpoch;
    // Keyword → category guesser so imported rows land in real categories
    // instead of all defaulting to "Other".
    for (var i = 0; i < _dataRows.length; i++) {
      final r = _dataRows[i];
      final amt = _amountCol! < r.length ? _parseAmount(r[_amountCol!]) : null;
      if (amt == null || amt == 0) continue;
      final desc = (_descCol! < r.length ? r[_descCol!] : 'Imported').trim();
      final dt = (_dateCol! < r.length ? _parseDate(r[_dateCol!]) : null) ?? DateTime.now();
      final cleanDesc = desc.isEmpty ? 'Imported' : desc;
      final key = sig(_currency, amt, cleanDesc, dt);
      if (seen.contains(key)) { skipped++; continue; }
      seen.add(key);
      final isIncome = amt > 0;
      try {
        await state.addTransaction(TransactionData(
          id: base + i,
          type: isIncome ? 'income' : 'expense',
          desc: cleanDesc,
          amount: amt.abs(),
          cat: _guessCategory(cleanDesc, isIncome),
          currency: _currency,
          sym: sym,
          date: dt.toIso8601String(),
        ));
        count++;
      } catch (_) {}
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          skipped > 0
              ? 'Imported $count · skipped $skipped duplicate${skipped == 1 ? '' : 's'}'
              : 'Imported $count transactions',
          style: TC.geist(context))),
      );
    }
  }

  /// Best-effort category from the transaction description so imported rows
  /// aren't all "Other". Returns a standard category emoji (the storage key).
  static String _guessCategory(String desc, bool isIncome) {
    final d = desc.toLowerCase();
    bool has(List<String> ks) => ks.any(d.contains);
    if (isIncome) {
      if (has(['salary', 'payroll', 'wage', 'paycheck'])) return '💼';
      if (has(['freelance', 'upwork', 'fiverr', 'client', 'invoice'])) return '💻';
      if (has(['gift'])) return '🎁';
      if (has(['dividend', 'interest', 'stock', 'crypto', 'investment', 'return'])) return '📈';
      if (has(['allowance', 'pocket'])) return '🏧';
      return '💼';
    }
    if (has(['rent', 'landlord', 'lease'])) return '🏠';
    if (has(['uber', 'lyft', 'bolt', 'taxi', 'careem', 'ola', 'bus', 'train', 'metro', 'fuel', 'petrol', 'gas station', 'parking', 'transport'])) return '🚌';
    if (has(['restaurant', 'cafe', 'coffee', 'starbucks', 'mcdonald', 'kfc', 'pizza', 'grocery', 'groceries', 'lidl', 'aldi', 'supermarket', 'dinner', 'lunch', 'bakery', 'food'])) return '🍽️';
    if (has(['amazon', 'shop', 'store', 'mall', 'zara', 'ikea', 'aliexpress', 'ebay', 'clothes'])) return '🛒';
    if (has(['netflix', 'spotify', 'cinema', 'movie', 'game', 'concert', 'bar', 'club', 'entertain'])) return '🎉';
    if (has(['hotel', 'flight', 'airbnb', 'booking', 'airline', 'trip', 'travel'])) return '✈️';
    if (has(['pharmacy', 'doctor', 'hospital', 'clinic', 'medic', 'health', 'gym', 'fitness'])) return '💊';
    if (has(['course', 'tuition', 'udemy', 'school', 'university', 'class', 'book'])) return '📚';
    if (has(['electric', 'water', 'internet', 'utility', 'phone', 'mobile', 'bill'])) return '💡';
    return '💰'; // Other
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m, style: TC.geist(context))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(children: [
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
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('IMPORT', style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: TC.primaryMd(context))),
                  Text('Import from CSV', style: TC.gloock(context, fontSize: 22, color: TC.text(context), letterSpacing: -0.4)),
                ]),
              ]),
            ),
            Expanded(
              child: _rows.isEmpty ? _picker(context) : _mapper(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _picker(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112, height: 112,
              decoration: BoxDecoration(color: TC.primaryPale(context), borderRadius: BorderRadius.circular(32)),
              alignment: Alignment.center,
              child: const Text('📄', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 24),
            Text('Import a statement', style: TC.gloock(context, fontSize: 22, color: TC.text(context))),
            const SizedBox(height: 10),
            Text('Export a CSV from your bank or another app, then bring all your history in at once.',
                textAlign: TextAlign.center,
                style: TC.geist(context, fontSize: 14, color: TC.text2(context), height: 1.6)),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: TC.primary(context),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: TC.primaryGlow(context), blurRadius: 18, offset: const Offset(0, 6))],
                ),
                alignment: Alignment.center,
                child: const Text('Choose CSV file', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapper(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: TC.border(context))),
          child: Row(children: [
            const Text('📄', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(child: Text('${_fileName ?? 'file.csv'} · ${_dataRows.length} rows',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TC.geist(context, fontSize: 13, fontWeight: FontWeight.w600, color: TC.text(context)))),
            GestureDetector(onTap: _pickFile, child: Text('Change', style: TC.geist(context, fontSize: 12, fontWeight: FontWeight.w700, color: TC.primaryMd(context)))),
          ]),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _hasHeader,
          activeTrackColor: TC.primary(context),
          title: Text('First row is a header', style: TC.geist(context, fontSize: 14, fontWeight: FontWeight.w600, color: TC.text(context))),
          onChanged: (v) => setState(() => _hasHeader = v),
        ),
        const SizedBox(height: 6),
        _colMap(context, 'Date column', _dateCol, (v) => setState(() => _dateCol = v)),
        _colMap(context, 'Description column', _descCol, (v) => setState(() => _descCol = v)),
        _colMap(context, 'Amount column', _amountCol, (v) => setState(() => _amountCol = v)),
        const SizedBox(height: 4),
        _currencyRow(context),
        const SizedBox(height: 18),
        if (_ready) ...[
          Text('PREVIEW', style: TC.geist(context, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: TC.text3(context))),
          const SizedBox(height: 8),
          ..._dataRows.take(4).map((r) => _previewRow(context, r)),
          const SizedBox(height: 8),
          Text('Negative amounts import as expenses, positive as income.',
              style: TC.geist(context, fontSize: 11, color: TC.text3(context))),
        ],
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _ready ? _import : null,
          child: Opacity(
            opacity: _ready ? 1 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: TC.primary(context),
                borderRadius: BorderRadius.circular(15),
                boxShadow: _ready ? [BoxShadow(color: TC.primaryGlow(context), blurRadius: 18, offset: const Offset(0, 6))] : null,
              ),
              alignment: Alignment.center,
              child: _importing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Import ${_dataRows.length} rows', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _colMap(BuildContext context, String label, int? value, ValueChanged<int?> onChanged) {
    final cols = List.generate(_headers.length, (i) => i);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: TC.border(context))),
        child: Row(children: [
          Expanded(child: Text(label, style: TC.geist(context, fontSize: 14, fontWeight: FontWeight.w500, color: TC.text(context)))),
          DropdownButton<int>(
            value: value,
            hint: Text('Select', style: TC.geist(context, fontSize: 13, color: TC.text3(context))),
            underline: const SizedBox.shrink(),
            dropdownColor: TC.card(context),
            items: cols.map((i) => DropdownMenuItem(
              value: i,
              child: Text(
                _hasHeader && i < _headers.length ? _headers[i] : 'Column ${i + 1}',
                style: TC.geist(context, fontSize: 13, color: TC.text(context)),
              ),
            )).toList(),
            onChanged: onChanged,
          ),
        ]),
      ),
    );
  }

  Widget _currencyRow(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: TC.surface(context),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (sheetCtx) => SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.6,
            child: ListView(
              children: AppState.currencies.map((c) => ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                title: Text('${c.code} — ${c.name}', style: TC.geist(context, fontSize: 14, color: TC.text(context))),
                trailing: c.code == _currency ? Icon(Icons.check_circle_rounded, color: TC.primary(context), size: 20) : null,
                onTap: () { setState(() => _currency = c.code); Navigator.pop(sheetCtx); },
              )).toList(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(color: TC.card(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: TC.border(context))),
        child: Row(children: [
          Expanded(child: Text('Currency', style: TC.geist(context, fontSize: 14, fontWeight: FontWeight.w500, color: TC.text(context)))),
          Text(_currency, style: TC.geist(context, fontSize: 14, fontWeight: FontWeight.w700, color: TC.text(context))),
          const SizedBox(width: 6),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: TC.text3(context)),
        ]),
      ),
    );
  }

  Widget _previewRow(BuildContext context, List<String> r) {
    final amt = _amountCol! < r.length ? _parseAmount(r[_amountCol!]) : null;
    final desc = _descCol! < r.length ? r[_descCol!] : '';
    final isInc = (amt ?? 0) > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Text(desc.isEmpty ? 'Imported' : desc, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TC.geist(context, fontSize: 13, color: TC.text(context)))),
        Text(amt == null ? '—' : '${isInc ? '+' : '-'}${AppCurrencyUtils.formatAmount(amt.abs(), 2)}',
            style: TC.gloock(context, fontSize: 13, color: isInc ? TC.ok(context) : TC.er(context))),
      ]),
    );
  }
}
