import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final _connectivity = Connectivity();

  Future<bool> isOnline() async {
    try {
      final r = await _connectivity.checkConnectivity();
      return _online(r);
    } catch (_) {
      return true;
    }
  }

  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_online).distinct();

  static bool _online(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);
}
