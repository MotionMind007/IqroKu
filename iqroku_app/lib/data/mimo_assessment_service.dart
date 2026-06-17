import '../models/learning_status.dart';
import 'assessment_service.dart';
import 'auth_api_service.dart';

class MiMoAssessmentService implements AssessmentService {
  MiMoAssessmentService({required this.authService});

  final AuthApiService authService;

  @override
  Future<AssessmentResult> assess(AssessmentRequest request) async {
    final audioPath = request.audioPath;
    final attemptId = request.attemptId;

    if (audioPath == null || audioPath.isEmpty) {
      throw AssessmentException('No audio recorded');
    }

    if (attemptId == null || attemptId.isEmpty) {
      throw AssessmentException('Attempt ID not available');
    }

    try {
      // Step 1: Upload audio to server (with timeout)
      await authService.uploadAudio(
        attemptId: attemptId,
        audioPath: audioPath,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw AssessmentException('Upload timeout'),
      );

      // Step 2: Call AI assessment endpoint (with timeout)
      final result = await authService.assessAttemptWithAI(
        attemptId: attemptId,
        targetLines: request.targetLines,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw AssessmentException('Assessment timeout'),
      );

      // Parse result
      final score = (result['score'] as num?)?.toInt() ?? 0;
      final statusStr = result['status'] as String? ?? 'review';
      final feedback = result['feedback'] as String? ?? 'Bacaan perlu diperbaiki.';
      final note = result['note'] as String? ?? '';

      return AssessmentResult(
        score: score,
        status: statusStr == 'fluent' ? LearningStatus.fluent : LearningStatus.review,
        feedback: feedback,
        note: note,
      );
    } on AssessmentException {
      rethrow;
    } on AuthApiException catch (e) {
      throw AssessmentException('Assessment failed: ${e.code}');
    } catch (e) {
      throw AssessmentException('Assessment failed: $e');
    }
  }
}

class AssessmentException implements Exception {
  const AssessmentException(this.message);
  final String message;

  @override
  String toString() => message;
}
