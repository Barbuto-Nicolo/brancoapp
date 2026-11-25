import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'parsers/cell_utils.dart';

class CacheEntry {
  const CacheEntry(this.aggiornatoAl, this.tab);
  final DateTime aggiornatoAl;

  /// Risposta grezza di batchGet: nome tab → righe.
  final Map<String, List<Riga>> tab;
}

/// Cache locale dell'ultima lettura (un solo record per profilo).
/// Contiene dati personali: viene cancellata al logout. Non finisce mai nei log.
class CacheStore {
  static String _chiave(String profilo) => 'cache_v1_$profilo';

  Future<void> salva(String profilo, Map<String, List<Riga>> tab, DateTime quando) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chiave(profilo),
      jsonEncode({'t': quando.toIso8601String(), 'tab': tab}),
    );
  }

  /// null se manca o è illeggibile (in tal caso si riparte dalla rete).
  Future<CacheEntry?> leggi(String profilo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_chiave(profilo));
      if (s == null) return null;
      final j = jsonDecode(s) as Map<String, dynamic>;
      final tab = (j['tab'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, [for (final r in v as List) List<Object?>.from(r as List)]),
      );
      return CacheEntry(DateTime.parse(j['t'] as String), tab);
    } catch (_) {
      return null;
    }
  }

  Future<void> cancella(String profilo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chiave(profilo));
  }
}
