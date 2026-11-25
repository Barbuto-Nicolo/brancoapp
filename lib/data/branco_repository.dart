import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth/auth_service.dart';
import 'cache_store.dart';
import 'name_matcher.dart';
import 'parsers/cell_utils.dart';
import 'sheets_client.dart';

/// Nessuna connessione (o Google non raggiungibile).
class RetePersaException implements Exception {
  @override
  String toString() => 'RetePersaException';
}

class CaricamentoDati {
  const CaricamentoDati(this.data, this.aggiornatoAl, {required this.daCache});
  final BrancoData data;
  final DateTime aggiornatoAl;
  final bool daCache;
}

abstract class BrancoRepository {
  Future<CaricamentoDati> daRete();
  Future<CaricamentoDati?> daCache();
  Future<void> esci();
}

class SheetsBrancoRepository implements BrancoRepository {
  SheetsBrancoRepository({
    required this.profilo,
    required this.auth,
    required this.cache,
    http.Client? httpClient,
  }) : _http = httpClient;

  final SheetProfile profilo;
  final AuthService auth;
  final CacheStore cache;
  final http.Client? _http;

  static const _timeout = Duration(seconds: 20);

  @override
  Future<CaricamentoDati> daRete() async {
    final client = SheetsClient(profilo: profilo, token: auth.token, httpClient: _http);
    try {
      Map<String, List<Riga>> tab;
      try {
        tab = await client.batchGet().timeout(_timeout);
      } on SheetsException catch (e) {
        if (!e.nonAutorizzato) rethrow;
        tab = await client.batchGet().timeout(_timeout); // token scaduto: un solo nuovo tentativo
      }
      final quando = DateTime.now();
      try {
        await cache.salva(profilo.nome, tab, quando);
      } catch (_) {
        // La cache è un di più: se non si riesce a salvare, si prosegue.
      }
      return CaricamentoDati(BrancoData.daTab(profilo, tab), quando, daCache: false);
    } on SocketException {
      throw RetePersaException();
    } on http.ClientException {
      throw RetePersaException();
    } on TimeoutException {
      throw RetePersaException();
    } on SheetsException catch (e) {
      if (e.nonAutorizzato) throw NonAutenticatoException();
      rethrow;
    }
  }

  @override
  Future<CaricamentoDati?> daCache() async {
    final c = await cache.leggi(profilo.nome);
    if (c == null) return null;
    return CaricamentoDati(BrancoData.daTab(profilo, c.tab), c.aggiornatoAl, daCache: true);
  }

  @override
  Future<void> esci() async {
    await auth.esci();
    await cache.cancella(profilo.nome); // dati personali: via dal telefono
  }
}
