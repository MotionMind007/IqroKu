import 'learning_status.dart';

class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.currentLesson,
    required this.progress,
  });

  final String id;
  final String name;
  final int age;
  final String currentLesson;
  final double progress;
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
}
