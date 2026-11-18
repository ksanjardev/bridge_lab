import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'device_status.dart';
import 'status_service.dart';

class LiveStatusPage extends StatefulWidget {
  const LiveStatusPage({super.key});

  @override
  State<LiveStatusPage> createState() => _LiveStatusPageState();
}

class _LiveStatusPageState extends State<LiveStatusPage> {
  final _service = StatusService();
  StreamSubscription<DeviceStatus>? _sub;
  DeviceStatus? _latest;
  String? _error;
  int _count = 0;
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    // Listening here triggers onListen in Kotlin.
    _sub = _service.watch().listen(
          (s) {
        final t = DateTime.now().toIso8601String().substring(11, 19);
        setState(() {
          _latest = s;
          _count++;
          _log.insert(0, '$t  ${s.reason.split('.').last}  ${s.batteryPercent}%  ${s.network}');
          if (_log.length > 20) _log.removeLast();
        });
      },
      onError: (Object e) => setState(
            () => _error = e is PlatformException ? '${e.code}: ${e.message}' : '$e',
      ),
    );
  }

  @override
  void dispose() {
    // Cancelling here triggers onCancel in Kotlin.
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _latest;
    return Scaffold(
      appBar: AppBar(title: const Text('Live Device Status')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
            ),
          if (s == null && _error == null) const Center(child: CircularProgressIndicator()),
          if (s != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.batteryPercent}%',
                        style: Theme.of(context).textTheme.displaySmall),
                    LinearProgressIndicator(value: s.batteryPercent / 100),
                    const SizedBox(height: 8),
                    Text(s.charging ? 'Charging via ${s.powerSource}' : 'On battery'),
                    Text('Temperature: ${s.temperatureC} °C'),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.battery_saver),
              title: const Text('Battery saver'),
              trailing: Text(s.powerSave ? 'ON' : 'off'),
            ),
            ListTile(
              leading: const Icon(Icons.airplanemode_active),
              title: const Text('Airplane mode'),
              trailing: Text(s.airplaneMode ? 'ON' : 'off'),
            ),
            ListTile(
              leading: const Icon(Icons.network_check),
              title: const Text('Network'),
              trailing: Text(s.network),
            ),
          ],
          const Divider(),
          Text('Events received: $_count',
              style: Theme.of(context).textTheme.titleMedium),
          for (final line in _log)
            Text(line, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}