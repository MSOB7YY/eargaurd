import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/analysis.dart';
import '../native/agent_bridge.dart';
import 'spectrum_chart.dart';

class LiveSpectrum extends StatefulWidget {
  const LiveSpectrum({
    super.key,
    required this.minHz,
    required this.maxHz,
    required this.threshold,
  });

  final int minHz;
  final int maxHz;
  final double threshold;

  @override
  State<LiveSpectrum> createState() => _LiveSpectrumState();
}

class _LiveSpectrumState extends State<LiveSpectrum> {
  bool _live = false;
  Analysis? _analysis;

  @override
  void dispose() {
    _live = false;
    super.dispose();
  }

  Future<Analysis?> _sample() async {
    try {
      return Analysis.fromMap(
        await AgentBridge.analyze(widget.minHz, widget.maxHz),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _live = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mic unavailable for analysis')),
        );
      }
      return null;
    }
  }

  Future<void> _setLive(bool on) async {
    if (on) await Permission.microphone.request();
    setState(() => _live = on);
    while (_live && mounted) {
      final a = await _sample();
      if (!mounted || a == null) break;
      setState(() => _analysis = a);
      await Future.delayed(const Duration(milliseconds: 60));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = _analysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Detection', style: theme.textTheme.titleMedium),
            const Spacer(),
            const Text('Live'),
            Switch(value: _live, onChanged: _setLive),
          ],
        ),
        SpectrumChart(
          analysis: a,
          minHz: widget.minHz,
          maxHz: widget.maxHz,
          threshold: widget.threshold,
        ),
        if (a != null)
          Text(
            'Band peak: ${(a.bandPeakHz / 1000).toStringAsFixed(1)}kHz @ ${a.bandPeakDb.toStringAsFixed(1)} dBFS   ·   overall: ${(a.peakHz / 1000).toStringAsFixed(1)}kHz @ ${a.peakDb.toStringAsFixed(1)}',
            style: theme.textTheme.bodySmall,
          )
        else
          Text(
            'Turn on Live, then play the annoying sound near the mic.',
            style: theme.textTheme.bodySmall,
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.hearing),
            label: const Text('Sample once'),
            onPressed: _live
                ? null
                : () async {
                    final res = await _sample();
                    if (mounted && res != null) {
                      setState(() => _analysis = res);
                    }
                  },
          ),
        ),
      ],
    );
  }
}
