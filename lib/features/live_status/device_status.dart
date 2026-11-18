class DeviceStatus {
  const DeviceStatus({
    required this.batteryPercent,
    required this.charging,
    required this.powerSource,
    required this.temperatureC,
    required this.powerSave,
    required this.airplaneMode,
    required this.network,
    required this.reason,
  });

  final int batteryPercent;
  final bool charging;
  final String powerSource;
  final double temperatureC;
  final bool powerSave;
  final bool airplaneMode;
  final String network;
  final String reason; // which broadcast caused this event

  factory DeviceStatus.fromMap(Map<String, Object?> m) => DeviceStatus(
    batteryPercent: m['batteryPercent'] as int,
    charging: m['charging'] as bool,
    powerSource: m['powerSource'] as String,
    temperatureC: (m['temperatureC'] as num).toDouble(),
    powerSave: m['powerSave'] as bool,
    airplaneMode: m['airplaneMode'] as bool,
    network: m['network'] as String,
    reason: m['reason'] as String,
  );
}