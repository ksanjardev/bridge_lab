import 'package:flutter/services.dart';

import 'device_status.dart';

class StatusService {
  static const _events = EventChannel('bridge_lab/status');

  Stream<DeviceStatus> watch() =>
      _events.receiveBroadcastStream().map((e) => DeviceStatus.fromMap(Map<String, Object?>.from(e as Map)));
}
