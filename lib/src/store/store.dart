import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';

class Store {
  static const String _key = 'manual_devices';

  Future<List<Device>> loadManual() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_key) ?? const [];
    return raw.map((e) {
      final j = jsonDecode(e) as Map<String, dynamic>;
      return Device(
        name: (j['name'] ?? 'Manual') as String,
        host: j['host'] as String,
        port: j['port'] as int,
        manual: true,
      );
    }).toList();
  }

  Future<void> addManual(Device d) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_key) ?? <String>[];
    raw.removeWhere((e) {
      final j = jsonDecode(e) as Map<String, dynamic>;
      return j['host'] == d.host && j['port'] == d.port;
    });
    raw.add(jsonEncode({'name': d.name, 'host': d.host, 'port': d.port}));
    await sp.setStringList(_key, raw);
  }

  Future<void> removeManual(Device d) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_key) ?? <String>[];
    raw.removeWhere((e) {
      final j = jsonDecode(e) as Map<String, dynamic>;
      return j['host'] == d.host && j['port'] == d.port;
    });
    await sp.setStringList(_key, raw);
  }
}
