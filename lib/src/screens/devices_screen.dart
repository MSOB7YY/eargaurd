import 'package:flutter/material.dart';

import '../discovery/discovery.dart';
import '../models/device.dart';
import '../store/store.dart';
import '../widgets/device_card.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final DiscoveryController _discovery = DiscoveryController();
  final Store _store = Store();
  List<Device> _manual = [];

  @override
  void initState() {
    super.initState();
    _discovery.addListener(_onChange);
    _discovery.start();
    _loadManual();
  }

  void _onChange() => setState(() {});

  Future<void> _loadManual() async {
    final m = await _store.loadManual();
    if (mounted) setState(() => _manual = m);
  }

  List<Device> get _all {
    final map = <String, Device>{};
    for (final d in _manual) {
      map[d.id] = d;
    }
    for (final d in _discovery.devices) {
      map[d.id] = d;
    }
    return map.values.toList();
  }

  Future<void> _addManualDialog() async {
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '8723');
    final nameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add device by IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name (optional)'),
            ),
            TextField(
              controller: hostCtrl,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'IP address',
                hintText: '192.168.1.110',
              ),
            ),
            TextField(
              controller: portCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final host = hostCtrl.text.trim();
      final port = int.tryParse(portCtrl.text.trim()) ?? 8723;
      if (host.isNotEmpty) {
        await _store.addManual(
          Device(
            name: nameCtrl.text.trim().isEmpty ? host : nameCtrl.text.trim(),
            host: host,
            port: port,
            manual: true,
          ),
        );
        await _loadManual();
      }
    }
  }

  Future<void> _remove(Device d) async {
    await _store.removeManual(d);
    await _loadManual();
  }

  @override
  void dispose() {
    _discovery.removeListener(_onChange);
    _discovery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devices = _all;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rescan',
            onPressed: () => _discovery.refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add IP'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _discovery.refresh();
          await _loadManual();
        },
        child: devices.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No devices found.\nPull to rescan, or add one by IP.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                itemCount: devices.length,
                itemBuilder: (ctx, i) {
                  final d = devices[i];
                  return DeviceCard(
                    key: ValueKey(d.id),
                    device: d,
                    onRemove: d.manual ? () => _remove(d) : null,
                  );
                },
              ),
      ),
    );
  }
}
