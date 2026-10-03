import 'package:connectivity_plus/connectivity_plus.dart';

/// Detecta la disponibilidad de conectividad del dispositivo.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<bool> get onlineStream =>
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  Future<bool> check() async => _isOnline(await _connectivity.checkConnectivity());

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
