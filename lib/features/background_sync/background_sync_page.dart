import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sync_service.dart';
import 'sync_status.dart';

class BackgroundSyncPage extends StatefulWidget {
  const BackgroundSyncPage({super.key});

  @override
  State<BackgroundSyncPage> createState() => _BackgroundSyncPageState();
}

class _BackgroundSyncPageState extends State<BackgroundSyncPage> {
  final _service = SyncService();
  SyncStatus? _status;
  int _interval = 15;
  bool _wifiOnly = false;
  bool _chargingOnly = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    // A MethodChannel can't push. We have to ask again and again.
    // This polling is the weakness Phase 2 (EventChannel) fixes.
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final s = await _service.status();
      if (mounted) setState(() => _status = s);
    } on PlatformException catch (e) {
      _showError(e);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (e) {
      _showError(e);
    }
    await _refresh();
  }

  void _showError(PlatformException e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${e.code}: ${e.message}')));
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Background Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: s == null
                  ? const Text('Loading…')
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Periodic job: ${s.periodic}'),
                  Text('One-time job: ${s.oneShot}'),
                  Text('Completed runs: ${s.runCount}'),
                  Text('Last run: ${s.lastRun ?? 'never'}'),
                  Text('Loop job: ${s.loop}')
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Repeat every (minutes)'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 15, label: Text('15')),
              ButtonSegment(value: 30, label: Text('30')),
              ButtonSegment(value: 60, label: Text('60')),
              ButtonSegment(value: 5, label: Text('5 ✗')),
            ],
            selected: {_interval},
            onSelectionChanged: (v) => setState(() => _interval = v.first),
          ),
          SwitchListTile(
            title: const Text('Unmetered network only (Wi-Fi)'),
            value: _wifiOnly,
            onChanged: (v) => setState(() => _wifiOnly = v),
          ),
          SwitchListTile(
            title: const Text('Only while charging'),
            value: _chargingOnly,
            onChanged: (v) => setState(() => _chargingOnly = v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _run(() => _service.schedulePeriodic(
              intervalMinutes: _interval,
              wifiOnly: _wifiOnly,
              chargingOnly: _chargingOnly,
            )),
            child: const Text('Schedule periodic sync'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => _run(_service.runNow),
            child: const Text('Run once now'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => _run(() => _service.startLoop(seconds: 20)),
            child: const Text('Start 20-second loop'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _run(_service.cancel),
            child: const Text('Cancel all'),
          ),
        ],
      ),
    );
  }
}