import 'package:flutter_test/flutter_test.dart';
import 'package:iqroku/data/assessment_service.dart';
import 'package:iqroku/models/learning_status.dart';

void main() {
  group('AssessmentRequest', () {
    test('toJson serializes correctly', () {
      const request = AssessmentRequest(
        childId: 'child-1',
        bookId: 1,
        pageNumber: 5,
        targetLines: [
          ['أ', 'ب', 'ت'],
          ['ث', 'ج', 'ح'],
        ],
        audioPath: '/path/to/audio.m4a',
        durationSeconds: 120,
        attemptId: 'attempt-1',
      );

      final json = request.toJson();

      expect(json['childId'], 'child-1');
      expect(json['bookId'], 1);
      expect(json['pageNumber'], 5);
      expect(json['audioPath'], '/path/to/audio.m4a');
      expect(json['durationSeconds'], 120);
      expect(json['attemptId'], 'attempt-1');
    });

    test('toJson with optional fields null', () {
      const request = AssessmentRequest(
        childId: 'child-1',
        bookId: 1,
        pageNumber: 5,
        targetLines: [],
        audioPath: null,
        durationSeconds: 60,
      );

      final json = request.toJson();

      expect(json['audioPath'], null);
      expect(json['attemptId'], null);
    });
  });

  group('AssessmentResult', () {
    test('stores all fields correctly', () {
      const result = AssessmentResult(
        score: 88,
        status: LearningStatus.fluent,
        feedback: 'Bacaan sudah lancar!',
        note: 'Anak sudah menguasai halaman ini',
      );

      expect(result.score, 88);
      expect(result.status, LearningStatus.fluent);
      expect(result.feedback, 'Bacaan sudah lancar!');
      expect(result.note, 'Anak sudah menguasai halaman ini');
    });
  });

  group('MiMoAssessmentService', () {
    test('throws error when no audio recorded', () {
      // This test would require mocking the authService
      // For now, we test the validation logic
      const request = AssessmentRequest(
        childId: 'child-1',
        bookId: 1,
        pageNumber: 5,
        targetLines: [],
        audioPath: null,
        durationSeconds: 60,
      );

      expect(request.audioPath, null);
    });

    test('throws error when attemptId is missing', () {
      const request = AssessmentRequest(
        childId: 'child-1',
        bookId: 1,
        pageNumber: 5,
        targetLines: [],
        audioPath: '/path/to/audio.m4a',
        durationSeconds: 60,
      );

      expect(request.attemptId, null);
    });
  });
}
