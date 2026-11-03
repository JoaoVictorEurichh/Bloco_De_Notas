import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Observa a conectividade do aparelho para disparar a sincronização assim
/// que a rede volta. Não garante acesso ao Firebase (uma rede Wi‑Fi pode não
/// ter internet); por isso as falhas reais são tratadas no `SyncService`.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();

  Future<bool> get isOnline async {
    try {
      return _hasNetwork(await _connectivity.checkConnectivity());
    } catch (_) {
      return true; // na dúvida, tenta sincronizar.
    }
  }
}
