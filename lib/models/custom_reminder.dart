/// A custom reminder attached to an event.
/// [type] is 'notification' or 'alarm'.
class CustomReminder {
  final int? id;
  final int eventId;
  final int minutesBefore;
  final String type; // 'notification' or 'alarm'
  final String? soundUri;
  final bool isEnabled;

  const CustomReminder({
    this.id,
    required this.eventId,
    required this.minutesBefore,
    this.type = 'notification',
    this.soundUri,
    this.isEnabled = true,
  });

  bool get isAlarm => type == 'alarm';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'minutesBefore': minutesBefore,
      'type': type,
      'soundUri': soundUri,
      'isEnabled': isEnabled ? 1 : 0,
    };
  }

  factory CustomReminder.fromMap(Map<String, dynamic> map) {
    return CustomReminder(
      id: map['id'] as int?,
      eventId: map['eventId'] as int,
      minutesBefore: map['minutesBefore'] as int,
      type: map['type'] as String? ?? 'notification',
      soundUri: map['soundUri'] as String?,
      isEnabled: (map['isEnabled'] as int? ?? 1) == 1,
    );
  }

  CustomReminder copyWith({
    int? id,
    int? eventId,
    int? minutesBefore,
    String? type,
    String? soundUri,
    bool? isEnabled,
  }) {
    return CustomReminder(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      type: type ?? this.type,
      soundUri: soundUri ?? this.soundUri,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
