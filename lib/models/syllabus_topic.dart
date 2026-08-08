enum TopicStatus { notStarted, inProgress, completed, needsRevision }
enum StudyDifficulty { easy, medium, hard }

class SyllabusTopic {
  final int? id;
  final int unitId;
  final String name;
  final int orderIndex;
  final String status;
  final String? difficulty;
  final int? estimatedMinutes;
  final int? neetMarksWeightage; // NEET-specific marks
  final int? timesRevised;
  final int? lastStudiedMillis;
  final int? targetCompletionDateMillis; // NEW: chapter deadline
  final int? mcqsAttempted; // NEW: MCQ tracking
  final int? mcqsCorrect; // NEW: MCQ tracking
  final int? lastMockScore; // NEW: mock test tracking
  final int? bestMockScore; // NEW: mock test tracking
  final int? totalStudyMinutes; // NEW: study time tracking
  final int createdAtMillis;

  SyllabusTopic({
    this.id,
    required this.unitId,
    required this.name,
    this.orderIndex = 0,
    this.status = 'notStarted',
    this.difficulty,
    this.estimatedMinutes,
    this.neetMarksWeightage,
    this.timesRevised,
    this.lastStudiedMillis,
    this.targetCompletionDateMillis,
    this.mcqsAttempted,
    this.mcqsCorrect,
    this.lastMockScore,
    this.bestMockScore,
    this.totalStudyMinutes,
    required this.createdAtMillis,
  });

  SyllabusTopic copyWith({
    int? id,
    int? unitId,
    String? name,
    int? orderIndex,
    String? status,
    String? difficulty,
    int? estimatedMinutes,
    int? neetMarksWeightage,
    int? timesRevised,
    int? lastStudiedMillis,
    int? targetCompletionDateMillis,
    int? mcqsAttempted,
    int? mcqsCorrect,
    int? lastMockScore,
    int? bestMockScore,
    int? totalStudyMinutes,
    int? createdAtMillis,
  }) => SyllabusTopic(
    id: id ?? this.id,
    unitId: unitId ?? this.unitId,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
    status: status ?? this.status,
    difficulty: difficulty ?? this.difficulty,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    neetMarksWeightage: neetMarksWeightage ?? this.neetMarksWeightage,
    timesRevised: timesRevised ?? this.timesRevised,
    lastStudiedMillis: lastStudiedMillis ?? this.lastStudiedMillis,
    targetCompletionDateMillis: targetCompletionDateMillis ?? this.targetCompletionDateMillis,
    mcqsAttempted: mcqsAttempted ?? this.mcqsAttempted,
    mcqsCorrect: mcqsCorrect ?? this.mcqsCorrect,
    lastMockScore: lastMockScore ?? this.lastMockScore,
    bestMockScore: bestMockScore ?? this.bestMockScore,
    totalStudyMinutes: totalStudyMinutes ?? this.totalStudyMinutes,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
  );

  TopicStatus get statusEnum => TopicStatus.values.firstWhere(
    (e) => e.name == status,
    orElse: () => TopicStatus.notStarted,
  );

  StudyDifficulty? get difficultyEnum => difficulty != null 
    ? StudyDifficulty.values.firstWhere((e) => e.name == difficulty, orElse: () => StudyDifficulty.medium)
    : null;

  double? get mcqAccuracy => (mcqsAttempted != null && mcqsAttempted! > 0)
      ? (mcqsCorrect ?? 0) / mcqsAttempted! * 100
      : null;

  bool get hasDeadline => targetCompletionDateMillis != null;

  bool get isOverdue {
    if (targetCompletionDateMillis == null || status == 'completed') return false;
    final deadline = DateTime.fromMillisecondsSinceEpoch(targetCompletionDateMillis!);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).isAfter(
      DateTime(deadline.year, deadline.month, deadline.day),
    );
  }

  int? get daysUntilDeadline {
    if (targetCompletionDateMillis == null) return null;
    final deadline = DateTime.fromMillisecondsSinceEpoch(targetCompletionDateMillis!);
    final now = DateTime.now();
    return DateTime(deadline.year, deadline.month, deadline.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'unitId': unitId,
    'name': name,
    'orderIndex': orderIndex,
    'status': status,
    'difficulty': difficulty,
    'estimatedMinutes': estimatedMinutes,
    'neetMarksWeightage': neetMarksWeightage,
    'timesRevised': timesRevised,
    'lastStudiedMillis': lastStudiedMillis,
    'targetCompletionDateMillis': targetCompletionDateMillis,
    'mcqsAttempted': mcqsAttempted,
    'mcqsCorrect': mcqsCorrect,
    'lastMockScore': lastMockScore,
    'bestMockScore': bestMockScore,
    'totalStudyMinutes': totalStudyMinutes,
    'createdAtMillis': createdAtMillis,
  };

  factory SyllabusTopic.fromMap(Map<String, dynamic> map) => SyllabusTopic(
    id: map['id'] as int?,
    unitId: map['unitId'] as int,
    name: map['name'] as String,
    orderIndex: map['orderIndex'] as int? ?? 0,
    status: map['status'] as String? ?? 'notStarted',
    difficulty: map['difficulty'] as String?,
    estimatedMinutes: map['estimatedMinutes'] as int?,
    neetMarksWeightage: map['neetMarksWeightage'] as int?,
    timesRevised: map['timesRevised'] as int?,
    lastStudiedMillis: map['lastStudiedMillis'] as int?,
    targetCompletionDateMillis: map['targetCompletionDateMillis'] as int?,
    mcqsAttempted: map['mcqsAttempted'] as int?,
    mcqsCorrect: map['mcqsCorrect'] as int?,
    lastMockScore: map['lastMockScore'] as int?,
    bestMockScore: map['bestMockScore'] as int?,
    totalStudyMinutes: map['totalStudyMinutes'] as int?,
    createdAtMillis: map['createdAtMillis'] as int,
  );
}
