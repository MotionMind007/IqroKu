import '../models/learning_status.dart';

class AssessmentRequest {
  const AssessmentRequest({
    required this.childId,
    required this.bookId,
    required this.pageNumber,
    required this.targetLines,
    required this.audioPath,
    required this.durationSeconds,
    this.attemptId,
  });

  final String childId;
  final int bookId;
  final int pageNumber;
  final List<List<String>> targetLines;
  final String? audioPath;
  final int durationSeconds;
  final String? attemptId;

  Map<String, Object?> toJson() {
    return {
      'childId': childId,
      'bookId': bookId,
      'pageNumber': pageNumber,
      'targetLines': targetLines,
      'audioPath': audioPath,
      'durationSeconds': durationSeconds,
      'attemptId': attemptId,
    };
  }
}

class AssessmentResult {
  const AssessmentResult({
    required this.score,
    required this.status,
    required this.feedback,
    required this.note,
  });

  final int score;
  final LearningStatus status;
  final String feedback;
  final String note;
}

abstract class AssessmentService {
  Future<AssessmentResult> assess(AssessmentRequest request);
}

class MockAssessmentService implements AssessmentService {
  const MockAssessmentService();

  @override
  Future<AssessmentResult> assess(AssessmentRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final durationScore = request.durationSeconds.clamp(1, 12) * 2;
    final pageScore = request.pageNumber % 5;
    final materialBonus = request.targetLines.isEmpty ? -5 : 0;
    final score = (80 + durationScore + pageScore + materialBonus).clamp(
      72,
      96,
    );
    final passed = score >= 80;

    return AssessmentResult(
      score: score,
      status: passed ? LearningStatus.fluent : LearningStatus.review,
      feedback: passed
          ? 'Bacaan sudah cukup lancar. Pertahankan tempo dan lanjutkan dengan percaya diri.'
          : 'Sudah bagus berani membaca. Ulangi pelan-pelan bagian yang masih tersendat.',
      note: passed
          ? 'Hasil penilaian: lancar dengan toleransi latihan anak.'
          : 'Hasil penilaian: perlu ulang agar bacaan makin mantap.',
    );
  }
}
