import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _historyKey = 'search_history_queries';
  static const int _maxEntries = 12;

  Future<List<String>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? const <String>[];
    return history
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  Future<List<String>> addQuery(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return loadHistory();
    }

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_historyKey) ?? const <String>[];
    final updated = <String>[
      normalized,
      ...current.where(
        (entry) => entry.trim().toLowerCase() != normalized.toLowerCase(),
      ),
    ].take(_maxEntries).toList();

    await prefs.setStringList(_historyKey, updated);
    return updated;
  }
}
