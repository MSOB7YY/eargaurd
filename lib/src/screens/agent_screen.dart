import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../native/agent_bridge.dart';
import '../widgets/live_spectrum.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  bool _running = false;
  bool _micReady = false;
  bool _capEnabled = false;
  int _cap = 8;
  int _max = 15;
  double _threshold = -45;
  int _minHz = 8000;
  int _maxHz = 20000;
  final int _port = 8723;
  List<String> _ips = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _ips = await _localIps();
    await _refresh();
    if (_running) {
      await AgentBridge.startAgent();
      await _refresh();
    }
  }

  Future<void> _refresh() async {
    final running = await AgentBridge.isAgentRunning();
    final s = await AgentBridge.getStatus();
    if (!mounted) return;
    setState(() {
      _running = running;
      _capEnabled = (s['capEnabled'] ?? false) as bool;
      _cap = (s['cap'] ?? 8) as int;
      _max = (s['max'] ?? 15) as int;
      _threshold = ((s['threshold'] ?? -45) as num).toDouble();
      _minHz = (s['minHz'] ?? 8000) as int;
      _maxHz = (s['maxHz'] ?? 20000) as int;
      _micReady = (s['micReady'] ?? false) as bool;
    });
  }

  Future<List<String>> _localIps() async {
    final out = <String>[];
    try {
      for (final ni in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      )) {
        for (final a in ni.addresses) {
          if (!a.isLoopback) out.add(a.address);
        }
      }
    } catch (_) {}
    return out;
  }

  Future<void> _toggleAgent(bool on) async {
    setState(() => _busy = true);
    try {
      if (on) {
        await Permission.microphone.request();
        await Permission.notification.request();
        await AgentBridge.startAgent();
      } else {
        await AgentBridge.stopAgent();
      }
      await Future.delayed(const Duration(milliseconds: 300));
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('This device (agent)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Run as agent'),
              subtitle: Text(
                _running ? 'Control server is running' : 'Stopped',
              ),
              value: _running,
              onChanged: _busy ? null : _toggleAgent,
            ),
          ),
          if (_running) ...[
            _reachableCard(theme),
            _detectionCard(theme),
            _capCard(),
            Card(
              child: ListTile(
                leading: const Icon(Icons.battery_saver),
                title: const Text('Disable battery optimization'),
                subtitle: const Text('Recommended so the service stays alive'),
                onTap: AgentBridge.requestBatteryExemption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reachableCard(ThemeData theme) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reachable at', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          if (_ips.isEmpty)
            const Text('No network address')
          else
            ..._ips.map(
              (ip) => SelectableText(
                'http://$ip:$_port',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _micReady ? Icons.mic : Icons.mic_off,
                size: 18,
                color: _micReady ? Colors.green : theme.colorScheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _micReady
                      ? 'Mic ready for remote checks'
                      : 'Mic not ready — toggle agent while app is open',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _detectionCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LiveSpectrum(minHz: _minHz, maxHz: _maxHz, threshold: _threshold),
            const SizedBox(height: 8),
            Text(
              'Watch band: ${(_minHz / 1000).toStringAsFixed(1)}–${(_maxHz / 1000).toStringAsFixed(1)} kHz',
              style: theme.textTheme.labelLarge,
            ),
            RangeSlider(
              values: RangeValues(_minHz.toDouble(), _maxHz.toDouble()),
              min: 0,
              max: 22050,
              divisions: 44,
              labels: RangeLabels(
                '${(_minHz / 1000).toStringAsFixed(1)}k',
                '${(_maxHz / 1000).toStringAsFixed(1)}k',
              ),
              onChanged: (v) => setState(() {
                _minHz = v.start.round();
                _maxHz = v.end.round();
              }),
              onChangeEnd: (v) =>
                  AgentBridge.setBand(v.start.round(), v.end.round()),
            ),
            Text(
              'Warn threshold: ${_threshold.toStringAsFixed(0)} dBFS  (higher = louder needed)',
              style: theme.textTheme.labelLarge,
            ),
            Slider(
              value: _threshold.clamp(-100, 0),
              min: -100,
              max: 0,
              divisions: 100,
              label: _threshold.toStringAsFixed(0),
              onChanged: (v) => setState(() => _threshold = v),
              onChangeEnd: (v) => AgentBridge.setThreshold(v),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.notifications_active),
                label: const Text('Test warn'),
                onPressed: () => AgentBridge.warn(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _capCard() => Card(
    child: Column(
      children: [
        SwitchListTile(
          title: const Text('Auto-cap volume'),
          subtitle: Text('Ceiling: $_cap / $_max'),
          value: _capEnabled,
          onChanged: _busy
              ? null
              : (v) async {
                  await AgentBridge.setCapEnabled(v);
                  await _refresh();
                },
        ),
        if (_capEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Cap'),
                Expanded(
                  child: Slider(
                    value: _cap.toDouble().clamp(0, _max.toDouble()),
                    min: 0,
                    max: _max.toDouble(),
                    divisions: _max,
                    label: '$_cap',
                    onChanged: (v) => setState(() => _cap = v.round()),
                    onChangeEnd: (v) async {
                      await AgentBridge.setCap(v.round());
                      await _refresh();
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
