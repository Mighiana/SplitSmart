import '../providers/app_state.dart';

/// Type-tolerant mapping of shared Firestore group docs into app models.
///
/// Expense and settlement docs are written by *other* group members, so a
/// tampered client can store wrong-typed fields. Every field is coerced here
/// instead of cast, so one malformed doc cannot crash a member's group sync.
class CloudDocParser {
  CloudDocParser._();

  static String _str(Object? v, [String fallback = '']) =>
      v is String ? v : fallback;

  static String? _optStr(Object? v) => v is String ? v : null;

  static Map<String, double>? _amountMap(Object? v) {
    if (v is! Map) return null;
    final out = <String, double>{};
    v.forEach((k, val) {
      if (val is num && val.isFinite) {
        out[k.toString()] = val.toDouble();
      }
    });
    return out.isEmpty ? null : out;
  }

  static double _amount(Object? v) =>
      v is num && v.isFinite && v >= 0 ? v.toDouble() : 0;

  /// Receipt URLs from other members are only trusted when they point at
  /// Firebase Storage; any other remote URL (e.g. a tracking pixel) is
  /// dropped. Non-URL values are device-local paths and are kept.
  static String? safeReceiptPath(Object? v) {
    if (v is! String || v.isEmpty) return null;
    final lower = v.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return v;
    }
    final uri = Uri.tryParse(v);
    if (uri == null || uri.scheme != 'https') return null;
    final host = uri.host.toLowerCase();
    if (host == 'firebasestorage.googleapis.com' ||
        host.endsWith('.firebasestorage.app')) {
      return v;
    }
    return null;
  }

  static ExpenseData expense(Map<String, dynamic> d, int id) => ExpenseData(
        id: id,
        desc: _str(d['desc']),
        amount: _amount(d['amount']),
        cat: _str(d['cat'], '💰'),
        paidBy: _str(d['paidBy']),
        paidById: _optStr(d['paidById']),
        date: _str(d['date']),
        receipt: d['receipt'] == true,
        receiptPath: safeReceiptPath(d['receiptUrl']),
        splits: _amountMap(d['splits']),
        splitIds: _amountMap(d['splitIds']),
        createdBy: _optStr(d['createdBy']),
        updatedBy: _optStr(d['updatedBy']),
        addedBy: _optStr(d['addedBy']),
        subcat: _optStr(d['subcat']),
      );

  static SettlementData settlement(Map<String, dynamic> d) => SettlementData(
        from: _str(d['from']),
        to: _str(d['to']),
        fromId: _optStr(d['fromId']),
        toId: _optStr(d['toId']),
        amount: _amount(d['amount']),
        method: _str(d['method'], 'Cash'),
        date: _str(d['date']),
      );
}
