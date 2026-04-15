// Number and currency formatting centralized
class AppCurrencyUtils {
  /// Formats amount with commas (e.g. 1234.56 -> 1,234.56 or 1,234)
  static String formatAmount(double amount, [int decimals = 2]) {
    final parts = amount.toStringAsFixed(decimals).split('.');
    final whole = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    if (decimals == 0) return whole;
    return '$whole.${parts[1]}';
  }
}
