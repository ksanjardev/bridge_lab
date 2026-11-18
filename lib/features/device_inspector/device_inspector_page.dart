import 'package:flutter/material.dart';
import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart';

import 'android_sdk.g.dart';

class DeviceInspectorPage extends StatefulWidget {
  const DeviceInspectorPage({super.key});

  @override
  State<DeviceInspectorPage> createState() => _DeviceInspectorPageState();
}

class _DeviceInspectorPageState extends State<DeviceInspectorPage> {
  // The Android application Context, handed to us by package:jni.
  late final Context _context = androidApplicationContext.as(Context.type);

  int? _battery;
  String? _storage;
  int? _micros;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    try {
      final watch = Stopwatch()..start();

      // 1) Battery: ask the system service, cast it, read one property.
      final battery = _context
          .getSystemService$1(Context.BATTERY_SERVICE)!
          .as(BatteryManager.type);
      final level =
      battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);

      // 2) Storage: StatFs over the app data directory.
      final path = Environment.dataDirectory!.path!.toDartString();
      final stat = StatFs(path.toJString());
      final totalGb = stat.totalBytes / 1e9;
      final freeGb = stat.availableBytes / 1e9;

      watch.stop();
      setState(() {
        _battery = level;
        _storage = '${freeGb.toStringAsFixed(1)} GB free of ${totalGb.toStringAsFixed(1)} GB';
        _micros = watch.elapsedMicroseconds;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  void _vibrate() {
    try {
      final vibrator = _context
          .getSystemService$1(Context.VIBRATOR_SERVICE)!
          .as(Vibrator.type);
      vibrator.vibrate(
        VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE),
      );
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device =
        '${Build.MANUFACTURER?.toDartString() ?? '?'} ${Build.MODEL?.toDartString() ?? '?'}';
    final android =
        'Android ${Build$VERSION.RELEASE?.toDartString() ?? '?'} (API ${Build$VERSION.SDK_INT})';

    return Scaffold(
      appBar: AppBar(title: const Text('Device Inspector')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device, style: theme.textTheme.headlineSmall),
            Text(android, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.battery_full),
                title: const Text('Battery'),
                subtitle: Text(_battery == null ? '…' : '$_battery %'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.sd_storage_outlined),
                title: const Text('Storage'),
                subtitle: Text(_storage ?? '…'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _vibrate,
                  icon: const Icon(Icons.vibration),
                  label: const Text('Vibrate'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_micros != null)
              Text(
                'Both readings took $_micros µs, straight from Dart into the Android SDK.',
                style: theme.textTheme.bodySmall,
              ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
      ),
    );
  }
}