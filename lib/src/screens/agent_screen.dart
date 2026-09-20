import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../native/agent_bridge.dart';

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
      // Re-assert foreground mic type after a possible reboot/app relaunch.
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
            Card(
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
                          color: _micReady
                              ? Colors.green
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _micReady
                              ? 'Mic ready for remote checks'
                              : 'Mic not ready — toggle agent while app is open',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Card(
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
                              onChanged: (v) =>
                                  setState(() => _cap = v.round()),
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
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '10kHz+ warn threshold',
                      style: theme.textTheme.labelLarge,
                    ),
                    Text(
                      '${_threshold.toStringAsFixed(0)} dBFS  (higher = less sensitive)',
                      style: theme.textTheme.bodySmall,
                    ),
                    Slider(
                      value: _threshold.clamp(-90, 0),
                      min: -90,
                      max: 0,
                      divisions: 90,
                      label: _threshold.toStringAsFixed(0),
                      onChanged: (v) => setState(() => _threshold = v),
                      onChangeEnd: (v) async {
                        await AgentBridge.setThreshold(v);
                        await _refresh();
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.hearing),
                            label: const Text('Test check'),
                            onPressed: _busy
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final r = await AgentBridge.check();
                                    if (!mounted) return;
                                    final band =
                                        (r['band10k'] as num?)?.toDouble() ??
                                        -999;
                                    final warned =
                                        (r['warned'] ?? false) as bool;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'band ${band.toStringAsFixed(1)} dBFS · warned=$warned',
                                        ),
                                      ),
                                    );
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.notifications_active),
                            label: const Text('Test warn'),
                            onPressed: _busy ? null : () => AgentBridge.warn(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
}
