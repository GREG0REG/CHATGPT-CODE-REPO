// lib/models/notification_history.dart
/// Log entry for a sent or scheduled notification.
/// NOTE: DB schema (v16) does NOT have wasSnoozed column.
/// This model handles graceful degradation.
class NotificationHistory {
  final int? id;
  final int? eventId;
  final String eventTitle;
  final String reminderType; // e.g. 'day_before', 'hour_before', 'custom', 'snooze'
  final int sentAtMillis;
  final bool wasSnoozed;

  const NotificationHistory({
    this.id,
    this.eventId,
    required this.eventTitle,
    required this.reminderType,
    required this.sentAtMillis,
    this.wasSnoozed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'reminderType': reminderType,
      'sentAtMillis': sentAtMillis,
      // 'wasSnoozed' intentionally omitted — DB doesn't have this column
    };
  }

  factory NotificationHistory.fromMap(Map<String, dynamic> map) {
    return NotificationHistory(
      id: map['id'] as int?,
      eventId: map['eventId'] as int?,
      eventTitle: map['eventTitle'] as String,
      reminderType: map['reminderType'] as String,
      sentAtMillis: map['sentAtMillis'] as int,
      wasSnoozed: false, // DB doesn't store this, default to false
    );
  }
}
