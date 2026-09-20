import 'package:flutter/services.dart';

class AgentBridge {
  static const MethodChannel _c = MethodChannel('eargaurd/agent');

  static Map<String, dynamic> _map(dynamic v) =>
      Map<String, dynamic>.from(v as Map);

  static Future<bool> startAgent() async =>
      (await _c.invokeMethod<bool>('startAgent')) ?? false;

  static Future<bool> stopAgent() async =>
      (await _c.invokeMethod<bool>('stopAgent')) ?? false;

  static Future<bool> isAgentRunning() async =>
      (await _c.invokeMethod<bool>('isAgentRunning')) ?? false;

  static Future<Map<String, dynamic>> getStatus() async =>
      _map(await _c.invokeMethod('getStatus'));

  static Future<Map<String, dynamic>> setVolume(int level) async =>
      _map(await _c.invokeMethod('setVolume', {'level': level}));

  static Future<Map<String, dynamic>> stepVolume(int delta) async =>
      _map(await _c.invokeMethod('stepVolume', {'delta': delta}));

  static Future<Map<String, dynamic>> setCap(int level) async =>
      _map(await _c.invokeMethod('setCap', {'level': level}));

  static Future<Map<String, dynamic>> setCapEnabled(bool on) async =>
      _map(await _c.invokeMethod('setCapEnabled', {'on': on}));

  static Future<Map<String, dynamic>> setThreshold(double value) async =>
      _map(await _c.invokeMethod('setThreshold', {'value': value}));

  static Future<Map<String, dynamic>> setBand(int minHz, int maxHz) async =>
      _map(await _c.invokeMethod('setBand', {'minHz': minHz, 'maxHz': maxHz}));

  static Future<Map<String, dynamic>> analyze(int minHz, int maxHz) async =>
      _map(await _c.invokeMethod('analyze', {'minHz': minHz, 'maxHz': maxHz}));

  static Future<void> warn() async => _c.invokeMethod('warn');

  static Future<Map<String, dynamic>> check() async =>
      _map(await _c.invokeMethod('check'));

  static Future<void> requestBatteryExemption() async =>
      _c.invokeMethod('requestBatteryExemption');

  static Future<String> flavor() async =>
      (await _c.invokeMethod<String>('getFlavor')) ?? '';
}
