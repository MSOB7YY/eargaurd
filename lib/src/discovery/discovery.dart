import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;

import '../models/device.dart';

class DiscoveryController extends ChangeNotifier {
  nsd.Discovery? _discovery;
  final Map<String, Device> _found = {};

  List<Device> get devices => _found.values.toList(growable: false);

  Future<void> start() async {
    if (_discovery != null) return;
    try {
      _discovery = await nsd.startDiscovery(
        '_eargaurd._tcp',
        autoResolve: true,
        ipLookupType: nsd.IpLookupType.v4,
      );
      _discovery!.addListener(_sync);
      _sync();
    } catch (_) {
      _discovery = null;
    }
  }

  void _sync() {
    _found.clear();
    for (final s in _discovery?.services ?? const <nsd.Service>[]) {
      final port = s.port;
      if (port == null) continue;
      final host = (s.addresses != null && s.addresses!.isNotEmpty)
          ? s.addresses!.first.address
          : s.host;
      if (host == null || host.isEmpty) continue;
      final d = Device(name: s.name ?? 'EarGuard', host: host, port: port);
      _found[d.id] = d;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await stop();
    await start();
  }

  Future<void> stop() async {
    final d = _discovery;
    _discovery = null;
    if (d != null) {
      d.removeListener(_sync);
      try {
        await nsd.stopDiscovery(d);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
