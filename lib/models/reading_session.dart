// FILE: lib/models/reading_session.dart
// COMPLETE FILE — Model for reading session tracking (v14)

class ReadingSession {
  final int? id;
  final int bookId;
  final int startPage;
  final int endPage;
  final int pagesRead;
  final int minutesRead;
  final double? pagesPerMinute;
  final int sessionDateMillis;
  final String? note;
  final int createdAtMillis;

  ReadingSession({
    this.id,
    required this.bookId,
    required this.startPage,
    required this.endPage,
    required this.pagesRead,
    required this.minutesRead,
    this.pagesPerMinute,
    required this.sessionDateMillis,
    this.note,
    required this.createdAtMillis,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'startPage': startPage,
      'endPage': endPage,
      'pagesRead': pagesRead,
      'minutesRead': minutesRead,
      'pagesPerMinute': pagesPerMinute,
      'sessionDateMillis': sessionDateMillis,
      'note': note,
      'createdAtMillis': createdAtMillis,
    };
  }

  factory ReadingSession.fromMap(Map<String, dynamic> map) {
    return ReadingSession(
      id: map['id'] as int?,
      bookId: map['bookId'] as int,
      startPage: map['startPage'] as int,
      endPage: map['endPage'] as int,
      pagesRead: map['pagesRead'] as int,
      minutesRead: map['minutesRead'] as int,
      pagesPerMinute: map['pagesPerMinute'] as double?,
      sessionDateMillis: map['sessionDateMillis'] as int,
      note: map['note'] as String?,
      createdAtMillis: map['createdAtMillis'] as int,
    );
  }

  ReadingSession copyWith({
    int? id,
    int? bookId,
    int? startPage,
    int? endPage,
    int? pagesRead,
    int? minutesRead,
    double? pagesPerMinute,
    int? sessionDateMillis,
    String? note,
    int? createdAtMillis,
  }) {
    return ReadingSession(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      pagesRead: pagesRead ?? this.pagesRead,
      minutesRead: minutesRead ?? this.minutesRead,
      pagesPerMinute: pagesPerMinute ?? this.pagesPerMinute,
      sessionDateMillis: sessionDateMillis ?? this.sessionDateMillis,
      note: note ?? this.note,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    );
  }

  @override
  String toString() {
    return 'ReadingSession(id: $id, bookId: $bookId, pagesRead: $pagesRead, minutesRead: $minutesRead, date: $sessionDateMillis)';
  }
}
