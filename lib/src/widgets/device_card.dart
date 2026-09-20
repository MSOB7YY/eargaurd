import 'package:flutter/material.dart';

import '../api/agent_api.dart';
import '../models/device.dart';

class DeviceCard extends StatefulWidget {
  const DeviceCard({super.key, required this.device, this.onRemove});

  final Device device;
  final VoidCallback? onRemove;

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  late final AgentApi _api = AgentApi(widget.device.base);

  DeviceStatus? _status;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _api.status();
      if (mounted) setState(() => _status = s);
    } catch (e) {
      if (mounted) setState(() => _error = 'Offline');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<DeviceStatus> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = await action();
      if (mounted) setState(() => _status = s);
    } catch (e) {
      if (mounted) setState(() => _error = 'Command failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await _api.check();
      if (!mounted) return;
      final micReady = (r['micReady'] ?? false) as bool;
      final warned = (r['warned'] ?? false) as bool;
      final band = (r['band10k'] as num?)?.toDouble() ?? -999;
      final msg = !micReady
          ? 'Mic not ready — open EarGuard on that device once'
          : warned
          ? 'Warning played · 10k band ${band.toStringAsFixed(1)} dBFS'
          : 'OK · 10k band ${band.toStringAsFixed(1)} dBFS';
      _snack(msg);
    } catch (e) {
      _snack('Check failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.device.manual ? Icons.link : Icons.speaker,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s?.name ?? widget.device.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.device.id,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading || _busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _load,
                    tooltip: 'Refresh',
                  ),
                if (widget.device.manual && widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: widget.onRemove,
                    tooltip: 'Remove',
                  ),
              ],
            ),
            if (_error != null && s == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (s != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Volume', style: theme.textTheme.labelLarge),
                  const Spacer(),
                  Text(
                    '${s.volume} / ${s.max}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove),
                    onPressed: _busy ? null : () => _run(() => _api.step(-1)),
                  ),
                  Expanded(
                    child: Slider(
                      value: s.volume.toDouble().clamp(0, s.max.toDouble()),
                      min: 0,
                      max: s.max.toDouble(),
                      divisions: s.max,
                      label: '${s.volume}',
                      onChanged: _busy
                          ? null
                          : (v) => setState(
                              () => _status = DeviceStatus(
                                volume: v.round(),
                                max: s.max,
                                cap: s.cap,
                                capEnabled: s.capEnabled,
                                threshold: s.threshold,
                                micReady: s.micReady,
                                name: s.name,
                              ),
                            ),
                      onChangeEnd: (v) => _run(() => _api.setVolume(v.round())),
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: _busy ? null : () => _run(() => _api.step(1)),
                  ),
                ],
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Auto-cap volume'),
                subtitle: Text('Ceiling: ${s.cap}'),
                value: s.capEnabled,
                onChanged: _busy
                    ? null
                    : (v) => _run(() => _api.setCapEnabled(v)),
              ),
              if (s.capEnabled)
                Row(
                  children: [
                    const Text('Cap'),
                    Expanded(
                      child: Slider(
                        value: s.cap.toDouble().clamp(0, s.max.toDouble()),
                        min: 0,
                        max: s.max.toDouble(),
                        divisions: s.max,
                        label: '${s.cap}',
                        onChanged: _busy
                            ? null
                            : (v) => setState(
                                () => _status = DeviceStatus(
                                  volume: s.volume,
                                  max: s.max,
                                  cap: v.round(),
                                  capEnabled: s.capEnabled,
                                  threshold: s.threshold,
                                  micReady: s.micReady,
                                  name: s.name,
                                ),
                              ),
                        onChangeEnd: (v) => _run(() => _api.setCap(v.round())),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.hearing),
                      label: const Text('Check'),
                      onPressed: _busy ? null : _check,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('Warn'),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              await _api.warn();
                              return s;
                            }),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
