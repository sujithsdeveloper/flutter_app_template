import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads Indian states and districts from the bundled JSON asset.
class IndiaGeoData {
  IndiaGeoData._();

  static const _assetPath = 'assets/data/india_states_districts.json';

  static Map<String, List<String>>? _cache;

  /// Sorted map of state/UT name → district names.
  static Future<Map<String, List<String>>> load() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final states = decoded['states'] as List<dynamic>? ?? const [];

    final map = <String, List<String>>{};
    for (final entry in states) {
      if (entry is! Map) continue;
      final name = (entry['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final districts = (entry['districts'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList()
        ..sort();
      map[name] = districts;
    }

    final sorted = Map<String, List<String>>.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    _cache = sorted;
    return sorted;
  }

  static List<String> districtsFor(
    Map<String, List<String>> data,
    String? state,
  ) {
    if (state == null) return const [];
    return data[state] ?? const [];
  }
}
