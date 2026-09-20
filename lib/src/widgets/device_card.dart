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
  bool _checking = false;
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

  Future<void> _apply(
    DeviceStatus optimistic,
    Future<DeviceStatus> Function() call,
  ) async {
    setState(() => _status = optimistic);
    try {
      final s = await call();
      if (mounted) setState(() => _status = s);
    } catch (e) {
      if (mounted) {
        _snack('Command failed');
        _load();
      }
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final r = await _api.check();
      if (!mounted) return;
      final micReady = (r['micReady'] ?? false) as bool;
      final warned = (r['warned'] ?? false) as bool;
      final band = (r['band10k'] as num?)?.toDouble() ?? -999;
      _snack(
        !micReady
            ? 'Mic not ready — open EarGuard on that device once'
            : warned
            ? 'Warning played · peak ${band.toStringAsFixed(1)} dBFS'
            : 'OK · peak ${band.toStringAsFixed(1)} dBFS',
      );
    } catch (e) {
      _snack('Check failed');
    } finally {
      if (mounted) setState(() => _checking = false);
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
                if (_loading)
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
                    onPressed: () => _apply(
                      s.copyWith(volume: (s.volume - 1).clamp(0, s.max)),
                      () => _api.step(-1),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: s.volume.toDouble().clamp(0, s.max.toDouble()),
                      min: 0,
                      max: s.max.toDouble(),
                      divisions: s.max,
                      label: '${s.volume}',
                      onChanged: (v) => setState(
                        () => _status = s.copyWith(volume: v.round()),
                      ),
                      onChangeEnd: (v) => _apply(
                        s.copyWith(volume: v.round()),
                        () => _api.setVolume(v.round()),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: () => _apply(
                      s.copyWith(volume: (s.volume + 1).clamp(0, s.max)),
                      () => _api.step(1),
                    ),
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
                onChanged: (v) => _apply(
                  s.copyWith(capEnabled: v),
                  () => _api.setCapEnabled(v),
                ),
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
                        onChanged: (v) => setState(
                          () => _status = s.copyWith(cap: v.round()),
                        ),
                        onChangeEnd: (v) => _apply(
                          s.copyWith(cap: v.round()),
                          () => _api.setCap(v.round()),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.hearing),
                      label: const Text('Check'),
                      onPressed: _checking ? null : _check,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('Warn'),
                      onPressed: () => _api.warn(),
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
