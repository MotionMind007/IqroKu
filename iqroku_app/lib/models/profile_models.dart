import 'learning_status.dart';

class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.currentLesson,
    required this.progress,
    required this.avatarAsset,
  });

  final String id;
  final String name;
  final int age;
  final String currentLesson;
  final double progress;
  final String avatarAsset;

  ChildProfile copyWith({
    String? id,
    String? name,
    int? age,
    String? currentLesson,
    double? progress,
    String? avatarAsset,
  }) {
    return ChildProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      currentLesson: currentLesson ?? this.currentLesson,
      progress: progress ?? this.progress,
      avatarAsset: avatarAsset ?? this.avatarAsset,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'currentLesson': currentLesson,
      'progress': progress,
      'avatarAsset': avatarAsset,
    };
  }

  static ChildProfile fromJson(Map<String, Object?> json) {
    return ChildProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Anak',
      age: (json['age'] as num?)?.toInt() ?? 7,
      currentLesson: json['currentLesson'] as String? ?? 'Iqro 1 - Halaman 1',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      avatarAsset: json['avatarAsset'] as String? ?? 'assets/brand/male-avatar.png',
    );
  }
}

class LearningNote {
  const LearningNote({
    required this.title,
    required this.date,
    required this.status,
    required this.note,
  });

  final String title;
  final String date;
  final LearningStatus status;
  final String note;

  Map<String, Object?> toJson() {
    return {'title': title, 'date': date, 'status': status.name, 'note': note};
  }

  static LearningNote fromJson(Map<String, Object?> json) {
    return LearningNote(
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      status: _learningStatusFromJson(json['status']),
      note: json['note'] as String? ?? '',
    );
  }

  static LearningStatus _learningStatusFromJson(Object? value) {
    final name = value as String? ?? '';
    for (final status in LearningStatus.values) {
      if (status.name == name) {
        return status;
      }
    }
    return LearningStatus.learning;
  }
}

class LearningAttempt {
  const LearningAttempt({
    required this.id,
    required this.childId,
    required this.bookId,
    required this.pageNumber,
    required this.date,
    required this.durationSeconds,
    required this.status,
    this.assessmentStatus = ReadingAssessmentStatus.recorded,
    this.audioPath,
    this.score,
    this.feedback,
    this.note,
  });

  final String id;
  final String childId;
  final int bookId;
  final int pageNumber;
  final String date;
  final int durationSeconds;
  final LearningStatus status;
  final ReadingAssessmentStatus assessmentStatus;
  final String? audioPath;
  final int? score;
  final String? feedback;
  final String? note;

  LearningAttempt copyWith({
    String? id,
    String? childId,
    int? bookId,
    int? pageNumber,
    String? date,
    int? durationSeconds,
    LearningStatus? status,
    ReadingAssessmentStatus? assessmentStatus,
    String? audioPath,
    int? score,
    String? feedback,
    String? note,
  }) {
    return LearningAttempt(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      date: date ?? this.date,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      assessmentStatus: assessmentStatus ?? this.assessmentStatus,
      audioPath: audioPath ?? this.audioPath,
      score: score ?? this.score,
      feedback: feedback ?? this.feedback,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'childId': childId,
      'bookId': bookId,
      'pageNumber': pageNumber,
      'date': date,
      'durationSeconds': durationSeconds,
      'status': status.name,
      'assessmentStatus': assessmentStatus.name,
      'audioPath': audioPath,
      'score': score,
      'feedback': feedback,
      'note': note,
    };
  }

  static LearningAttempt fromJson(Map<String, Object?> json) {
    final status = _learningStatusFromJson(json['status']);
    return LearningAttempt(
      id: json['id'] as String? ?? '',
      childId: json['childId'] as String? ?? '',
      bookId: (json['bookId'] as num?)?.toInt() ?? 1,
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      date: json['date'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      status: status,
      assessmentStatus: _assessmentStatusFromJson(
        json['assessmentStatus'] as String?,
        status,
        json['score'] as int?,
      ),
      audioPath: json['audioPath'] as String?,
      score: json['score'] as int?,
      feedback: json['feedback'] as String?,
      note: json['note'] as String?,
    );
  }

  static LearningStatus _learningStatusFromJson(Object? value) {
    final name = value as String? ?? '';
    for (final status in LearningStatus.values) {
      if (status.name == name) {
        return status;
      }
    }
    return LearningStatus.learning;
  }

  static ReadingAssessmentStatus _assessmentStatusFromJson(
    String? value,
    LearningStatus status,
    int? score,
  ) {
    if (value != null) {
      return ReadingAssessmentStatus.values.byName(value);
    }

    if (score == null) {
      return ReadingAssessmentStatus.recorded;
    }
    return status == LearningStatus.review
        ? ReadingAssessmentStatus.needsReview
        : ReadingAssessmentStatus.fluent;
  }
}

enum ReadingAssessmentStatus {
  recorded('Menunggu Penilaian'),
  assessing('Menilai Bacaan'),
  fluent('Lancar'),
  needsReview('Perlu Ulang');

  const ReadingAssessmentStatus(this.label);

  final String label;
}
