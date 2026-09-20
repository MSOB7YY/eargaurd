import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device.dart';

class AgentApi {
  AgentApi(this.base);

  final String base;

  static const Duration _timeout = Duration(seconds: 4);
  static const Duration _checkTimeout = Duration(seconds: 8);

  Future<DeviceStatus> _statusFrom(http.Response r) => Future.value(
    DeviceStatus.fromJson(jsonDecode(r.body) as Map<String, dynamic>),
  );

  Future<DeviceStatus> status() async {
    final r = await http.get(Uri.parse('$base/status')).timeout(_timeout);
    return _statusFrom(r);
  }

  Future<DeviceStatus> setVolume(int level) async {
    final r = await http
        .post(Uri.parse('$base/volume?level=$level'))
        .timeout(_timeout);
    return _statusFrom(r);
  }

  Future<DeviceStatus> step(int delta) async {
    final r = await http
        .post(Uri.parse('$base/volume/step?delta=$delta'))
        .timeout(_timeout);
    return _statusFrom(r);
  }

  Future<DeviceStatus> setCap(int level) async {
    final r = await http
        .post(Uri.parse('$base/cap?level=$level'))
        .timeout(_timeout);
    return _statusFrom(r);
  }

  Future<DeviceStatus> setCapEnabled(bool on) async {
    final r = await http
        .post(Uri.parse('$base/cap/enable?on=$on'))
        .timeout(_timeout);
    return _statusFrom(r);
  }

  Future<DeviceStatus> setThreshold(double value) async {
    final r = await http
        .post(Uri.parse('$base/threshold?value=$value'))
        .timeout(_timeout);
    return _statusFrom(r);
  }

  Future<void> warn() async {
    await http.post(Uri.parse('$base/warn')).timeout(_timeout);
  }

  Future<Map<String, dynamic>> check() async {
    final r = await http.post(Uri.parse('$base/check')).timeout(_checkTimeout);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
