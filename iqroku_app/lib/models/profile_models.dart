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
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      currentLesson: json['currentLesson'] as String,
      progress: (json['progress'] as num).toDouble(),
      avatarAsset: json['avatarAsset'] as String,
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
      title: json['title'] as String,
      date: json['date'] as String,
      status: LearningStatus.values.byName(json['status'] as String),
      note: json['note'] as String,
    );
  }
}
