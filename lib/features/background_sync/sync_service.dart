import 'package:bridge_lab/features/background_sync/sync_status.dart';
import 'package:flutter/services.dart';

class SyncService {
  static const _channel = MethodChannel('bridge_lab/sync');

  Future<void> schedulePeriodic({required int intervalMinutes, bool wifiOnly = false, bool chargingOnly = false}) =>
      _channel.invokeMethod('schedulePeriodic', {
        'intervalMinutes': intervalMinutes,
        'wifiOnly': wifiOnly,
        'chargingOnly': chargingOnly,
      });

  Future<void> runNow() => _channel.invokeMethod('runNow');

  Future<void> cancel() => _channel.invokeMethod('cancel');

  Future<SyncStatus> status() async {
    final json = await _channel.invokeMapMethod<String, Object?>('getStatus');
    return SyncStatus.fromJson(json!);
  }

  Future<void> startLoop({required int seconds}) =>
      _channel.invokeMethod('startLoop', {'seconds': seconds});
}
