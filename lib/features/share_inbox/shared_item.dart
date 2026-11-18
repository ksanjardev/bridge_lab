enum SharedKind { text, image, file }

class SharedItem {
  const SharedItem({
    required this.kind,
    required this.receivedAt,
    this.text,
    this.subject,
    this.name,
    this.path,
    this.mimeType,
    this.sizeBytes,
  });

  final SharedKind kind;
  final DateTime receivedAt;
  final String? text;
  final String? subject;
  final String? name;
  final String? path;
  final String? mimeType;
  final int? sizeBytes;

  factory SharedItem.fromJson(Map<String, Object?> json) => SharedItem(
    kind: SharedKind.values.byName(json['kind'] as String),
    receivedAt:
    DateTime.fromMillisecondsSinceEpoch(json['receivedAtMs'] as int),
    text: json['text'] as String?,
    subject: json['subject'] as String?,
    name: json['name'] as String?,
    path: json['path'] as String?,
    mimeType: json['mimeType'] as String?,
    sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
  );
}