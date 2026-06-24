class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.createdAt,
    this.details,
    this.status = 'open',
  });

  final String id;
  final String reporterId;
  final String entityType;
  final String entityId;
  final String reason;
  final String? details;
  final String status;
  final DateTime createdAt;

  factory Report.fromMap(Map<String, dynamic> map) => Report(
        id: map['id'] as String,
        reporterId: map['reporter_id'] as String,
        entityType: map['entity_type'] as String,
        entityId: map['entity_id'] as String,
        reason: map['reason'] as String,
        details: map['details'] as String?,
        status: map['status']?.toString() ?? 'open',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
