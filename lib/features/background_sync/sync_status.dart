class SyncStatus {
  const SyncStatus({
    required this.periodic,
    required this.oneShot,
    required this.runCount,
    required this.lastRun,
    required this.loop,
  });

  final String periodic;
  final String oneShot;
  final int runCount;
  final DateTime? lastRun;
  final String loop;

  factory SyncStatus.fromJson(Map<String, Object?> json) {
    final lastMs = json['lastRunMs'] as int;
    return SyncStatus(
      periodic: json['periodic'] as String,
      oneShot: json['oneShot'] as String,
      runCount: json['runCount'] as int,
      lastRun: lastMs == 0 ? null : DateTime.fromMillisecondsSinceEpoch(lastMs),
      loop: json['loop'] as String,
    );
  }
}
