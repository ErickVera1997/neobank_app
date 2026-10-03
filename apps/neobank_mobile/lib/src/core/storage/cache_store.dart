import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Entrada de caché con su marca temporal.
class CachedEntry {
  const CachedEntry({required this.value, required this.storedAt});

  final Map<String, dynamic> value;
  final DateTime storedAt;
}

/// Caché local de respuestas para modo offline / lectura rápida.
abstract interface class CacheStore {
  Future<void> put(String key, Map<String, dynamic> value);
  Future<CachedEntry?> get(String key);
  Future<void> clear();
}

/// Implementación sobre `shared_preferences`.
class PrefsCacheStore implements CacheStore {
  static const String _prefix = 'neobank.cache.';

  @override
  Future<void> put(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$key',
      jsonEncode({
        'storedAt': DateTime.now().toUtc().toIso8601String(),
        'value': value,
      }),
    );
  }

  @override
  Future<CachedEntry?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return CachedEntry(
        value: (decoded['value'] as Map).cast<String, dynamic>(),
        storedAt: DateTime.parse(decoded['storedAt'] as String).toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await prefs.remove(key);
    }
  }
}

/// Implementación en memoria para pruebas.
class InMemoryCacheStore implements CacheStore {
  final Map<String, CachedEntry> _entries = {};

  @override
  Future<void> put(String key, Map<String, dynamic> value) async {
    _entries[key] = CachedEntry(value: value, storedAt: DateTime.now());
  }

  @override
  Future<CachedEntry?> get(String key) async => _entries[key];

  @override
  Future<void> clear() async => _entries.clear();
}
