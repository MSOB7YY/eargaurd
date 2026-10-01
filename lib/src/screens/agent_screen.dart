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
  bool _shouldStayReachable = true;
  int _activeStartMinute = 10 * 60;
  int _activeEndMinute = 1 * 60;
  bool _isAwake = false;

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
      _shouldStayReachable = (s['shouldStayReachable'] ?? true) as bool;
      _activeStartMinute = (s['activeStartMinute'] ?? _activeStartMinute) as int;
      _activeEndMinute = (s['activeEndMinute'] ?? _activeEndMinute) as int;
      _isAwake = (s['isAwake'] ?? false) as bool;
    });
  }

  Future<List<String>> _localIps() async {
    final out = <String>[];
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final ni in interfaces) {
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

  Future<void> _setReachability(bool shouldStayReachable, int startMinute, int endMinute) async {
    setState(() {
      _shouldStayReachable = shouldStayReachable;
      _activeStartMinute = startMinute;
      _activeEndMinute = endMinute;
    });
    await AgentBridge.setReachability(shouldStayReachable, startMinute, endMinute);
    await _refresh();
  }

  Future<void> _setBand(int minHz, int maxHz) async {
    setState(() {
      _minHz = minHz;
      _maxHz = maxHz;
    });
    await AgentBridge.setBand(minHz, maxHz);
  }

  Future<void> _setThreshold(double threshold) async {
    setState(() => _threshold = threshold);
    await AgentBridge.setThreshold(threshold);
  }

  Future<void> _setCapEnabled(bool isEnabled) async {
    await AgentBridge.setCapEnabled(isEnabled);
    await _refresh();
  }

  Future<void> _setCap(int cap) async {
    await AgentBridge.setCap(cap);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final runningText = _running ? 'Control server is running' : 'Stopped';
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'This device (agent)',
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh,
            ),
            onPressed: _refresh,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text(
                'Run as agent',
              ),
              subtitle: Text(
                runningText,
              ),
              value: _running,
              onChanged: _busy ? null : _toggleAgent,
            ),
          ),
          if (_running) ...[
            _ReachableAtCard(
              ips: _ips,
              port: _port,
              isMicReady: _micReady,
            ),
            _StayReachableCard(
              isEnabled: _shouldStayReachable,
              startMinute: _activeStartMinute,
              endMinute: _activeEndMinute,
              isAwake: _isAwake,
              onChanged: _setReachability,
            ),
            _DetectionCard(
              minHz: _minHz,
              maxHz: _maxHz,
              threshold: _threshold,
              onBandChanged: _setBand,
              onThresholdChanged: _setThreshold,
            ),
            _CapCard(
              isEnabled: _capEnabled,
              cap: _cap,
              maxVolume: _max,
              isBusy: _busy,
              onEnabledChanged: _setCapEnabled,
              onCapChanged: _setCap,
            ),
            const Card(
              child: ListTile(
                leading: Icon(
                  Icons.battery_saver,
                ),
                title: Text(
                  'Disable battery optimization',
                ),
                subtitle: Text(
                  'Recommended so the service stays alive',
                ),
                onTap: AgentBridge.requestBatteryExemption,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReachableAtCard extends StatelessWidget {
  const _ReachableAtCard({
    required this.ips,
    required this.port,
    required this.isMicReady,
  });

  final List<String> ips;
  final int port;
  final bool isMicReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final micIcon = isMicReady ? Icons.mic : Icons.mic_off;
    final micColor = isMicReady ? Colors.green : theme.colorScheme.error;
    final micText = isMicReady ? 'Mic ready for remote checks' : 'Mic not ready — toggle agent while app is open';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reachable at',
              style: textTheme.labelLarge,
            ),
            const SizedBox(
              height: 4,
            ),
            if (ips.isEmpty)
              const Text(
                'No network address',
              )
            else
              ...ips.map(
                (ip) => SelectableText(
                  'http://$ip:$port',
                  style: textTheme.bodyMedium,
                ),
              ),
            const SizedBox(
              height: 8,
            ),
            Row(
              children: [
                Icon(
                  micIcon,
                  size: 18,
                  color: micColor,
                ),
                const SizedBox(
                  width: 6,
                ),
                Expanded(
                  child: Text(
                    micText,
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// by claude
class _StayReachableCard extends StatelessWidget {
  const _StayReachableCard({
    required this.isEnabled,
    required this.startMinute,
    required this.endMinute,
    required this.isAwake,
    required this.onChanged,
  });

  final bool isEnabled;
  final int startMinute;
  final int endMinute;
  final bool isAwake;
  final void Function(bool isEnabled, int startMinute, int endMinute) onChanged;

  TimeOfDay _toTimeOfDay(int minuteOfDay) {
    final hour = minuteOfDay ~/ 60;
    final minute = minuteOfDay % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final currentMinute = isStart ? startMinute : endMinute;
    final initialTime = _toTimeOfDay(currentMinute);
    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked == null) return;
    final pickedMinute = picked.hour * 60 + picked.minute;
    final newStartMinute = isStart ? pickedMinute : startMinute;
    final newEndMinute = isStart ? endMinute : pickedMinute;
    onChanged(isEnabled, newStartMinute, newEndMinute);
  }

  @override
  Widget build(BuildContext context) {
    final startTime = _toTimeOfDay(startMinute);
    final endTime = _toTimeOfDay(endMinute);
    final fromText = startTime.format(context);
    final toText = endTime.format(context);
    final stateText = isAwake ? 'awake now' : 'sleeping until $fromText';
    final subtitle = isEnabled ? 'Active $fromText–$toText · $stateText' : 'Phone may sleep and stop responding';
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              'Stay reachable',
            ),
            subtitle: Text(
              subtitle,
            ),
            value: isEnabled,
            onChanged: (value) => onChanged(value, startMinute, endMinute),
          ),
          if (isEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(context, true),
                      child: Text(
                        'From $fromText',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(context, false),
                      child: Text(
                        'To $toText',
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetectionCard extends StatefulWidget {
  const _DetectionCard({
    required this.minHz,
    required this.maxHz,
    required this.threshold,
    required this.onBandChanged,
    required this.onThresholdChanged,
  });

  final int minHz;
  final int maxHz;
  final double threshold;
  final void Function(int minHz, int maxHz) onBandChanged;
  final void Function(double threshold) onThresholdChanged;

  @override
  State<_DetectionCard> createState() => _DetectionCardState();
}

class _DetectionCardState extends State<_DetectionCard> {
  late int _minHz = widget.minHz;
  late int _maxHz = widget.maxHz;
  late double _threshold = widget.threshold;

  @override
  void didUpdateWidget(_DetectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minHz != widget.minHz) _minHz = widget.minHz;
    if (oldWidget.maxHz != widget.maxHz) _maxHz = widget.maxHz;
    if (oldWidget.threshold != widget.threshold) _threshold = widget.threshold;
  }

  void _onBandDragged(RangeValues values) {
    final minHz = values.start.round();
    final maxHz = values.end.round();
    setState(() {
      _minHz = minHz;
      _maxHz = maxHz;
    });
  }

  void _onBandDropped(RangeValues values) {
    final minHz = values.start.round();
    final maxHz = values.end.round();
    widget.onBandChanged(minHz, maxHz);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final minKHzText = (_minHz / 1000).toStringAsFixed(1);
    final maxKHzText = (_maxHz / 1000).toStringAsFixed(1);
    final thresholdText = _threshold.toStringAsFixed(0);
    final bandValues = RangeValues(_minHz.toDouble(), _maxHz.toDouble());
    final thresholdValue = _threshold.clamp(-100.0, 0.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LiveSpectrum(
              minHz: _minHz,
              maxHz: _maxHz,
              threshold: _threshold,
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Watch band: $minKHzText–$maxKHzText kHz',
              style: textTheme.labelLarge,
            ),
            RangeSlider(
              values: bandValues,
              min: 0,
              max: 22050,
              divisions: 44,
              labels: RangeLabels('${minKHzText}k', '${maxKHzText}k'),
              onChanged: _onBandDragged,
              onChangeEnd: _onBandDropped,
            ),
            Text(
              'Warn threshold: $thresholdText dBFS  (higher = louder needed)',
              style: textTheme.labelLarge,
            ),
            Slider(
              value: thresholdValue,
              min: -100,
              max: 0,
              divisions: 100,
              label: thresholdText,
              onChanged: (value) => setState(() => _threshold = value),
              onChangeEnd: widget.onThresholdChanged,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(
                  Icons.notifications_active,
                ),
                label: const Text(
                  'Test warn',
                ),
                onPressed: AgentBridge.warn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapCard extends StatefulWidget {
  const _CapCard({
    required this.isEnabled,
    required this.cap,
    required this.maxVolume,
    required this.isBusy,
    required this.onEnabledChanged,
    required this.onCapChanged,
  });

  final bool isEnabled;
  final int cap;
  final int maxVolume;
  final bool isBusy;
  final void Function(bool isEnabled) onEnabledChanged;
  final void Function(int cap) onCapChanged;

  @override
  State<_CapCard> createState() => _CapCardState();
}

class _CapCardState extends State<_CapCard> {
  late int _cap = widget.cap;

  @override
  void didUpdateWidget(_CapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cap != widget.cap) _cap = widget.cap;
  }

  @override
  Widget build(BuildContext context) {
    final maxVolume = widget.maxVolume;
    final maxValue = maxVolume.toDouble();
    final sliderValue = _cap.clamp(0, maxVolume).toDouble();
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              'Auto-cap volume',
            ),
            subtitle: Text(
              'Ceiling: $_cap / $maxVolume',
            ),
            value: widget.isEnabled,
            onChanged: widget.isBusy ? null : widget.onEnabledChanged,
          ),
          if (widget.isEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text(
                    'Cap',
                  ),
                  Expanded(
                    child: Slider(
                      value: sliderValue,
                      min: 0,
                      max: maxValue,
                      divisions: maxVolume,
                      label: '$_cap',
                      onChanged: (value) => setState(() => _cap = value.round()),
                      onChangeEnd: (value) => widget.onCapChanged(value.round()),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
