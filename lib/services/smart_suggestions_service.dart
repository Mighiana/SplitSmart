import '../providers/app_state.dart';

/// Suggestion based on user's expense history.
class ExpenseSuggestion {
  final String description;
  final double amount;
  final String category;
  final int frequency; // how many times this expense was added

  ExpenseSuggestion({
    required this.description,
    required this.amount,
    required this.category,
    required this.frequency,
  });
}

/// Zero-cost smart suggestions from local SQLite history.
/// No AI, no internet — pure pattern matching.
class SmartSuggestionsService {
  SmartSuggestionsService._();
  static final SmartSuggestionsService instance = SmartSuggestionsService._();

  /// Get top suggestions based on the user's most frequent expenses
  /// in the current group.
  List<ExpenseSuggestion> getSuggestions(AppState state) {
    final g = state.currentGroup;
    if (g == null) return [];

    final expenses = g.expenses;
    if (expenses.isEmpty) return [];

    // Group by description (case-insensitive) and count frequency
    final Map<String, _AggregatedExpense> aggregated = {};
    for (final e in expenses) {
      final key = e.desc.toLowerCase().trim();
      if (key.isEmpty) continue;
      if (aggregated.containsKey(key)) {
        aggregated[key]!.count++;
        // Use the most recent amount
        aggregated[key]!.latestAmount = e.amount;
      } else {
        aggregated[key] = _AggregatedExpense(
          desc: e.desc,
          latestAmount: e.amount,
          cat: e.cat,
          count: 1,
        );
      }
    }

    // Sort by frequency (most common first), then by recency
    final sorted = aggregated.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // Return top 8 suggestions
    return sorted
        .take(8)
        .map((a) => ExpenseSuggestion(
              description: a.desc,
              amount: a.latestAmount,
              category: a.cat,
              frequency: a.count,
            ))
        .toList();
  }

  /// Get suggestions that match a partial query (for autocomplete).
  List<ExpenseSuggestion> getMatchingSuggestions(
      AppState state, String query) {
    if (query.length < 2) return [];
    final all = getSuggestions(state);
    final q = query.toLowerCase();
    return all
        .where((s) => s.description.toLowerCase().contains(q))
        .toList();
  }
}

class _AggregatedExpense {
  final String desc;
  double latestAmount;
  final String cat;
  int count;

  _AggregatedExpense({
    required this.desc,
    required this.latestAmount,
    required this.cat,
    required this.count,
  });
}
