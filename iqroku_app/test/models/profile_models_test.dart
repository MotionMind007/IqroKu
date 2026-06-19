import 'package:flutter_test/flutter_test.dart';
import 'package:iqroku/models/learning_status.dart';
import 'package:iqroku/models/profile_models.dart';

void main() {
  group('ChildProfile', () {
    test('fromJson with valid data', () {
      final json = {
        'id': 'child-1',
        'name': 'Ahmad',
        'age': 8,
        'currentLesson': 'Iqro 2 - Halaman 5',
        'progress': 0.65,
        'avatarAsset': 'assets/brand/male-avatar.png',
        'repeatFromPage': 8,
        'repeatFromBook': 2,
      };

      final profile = ChildProfile.fromJson(json);

      expect(profile.id, 'child-1');
      expect(profile.name, 'Ahmad');
      expect(profile.age, 8);
      expect(profile.currentLesson, 'Iqro 2 - Halaman 5');
      expect(profile.progress, 0.65);
      expect(profile.avatarAsset, 'assets/brand/male-avatar.png');
      expect(profile.repeatFromPage, 8);
      expect(profile.repeatFromBook, 2);
    });

    test('fromJson with null values uses defaults', () {
      final json = <String, Object?>{
        'id': null,
        'name': null,
        'age': null,
        'currentLesson': null,
        'progress': null,
        'avatarAsset': null,
      };

      final profile = ChildProfile.fromJson(json);

      expect(profile.id, '');
      expect(profile.name, 'Anak');
      expect(profile.age, 7);
      expect(profile.currentLesson, 'Iqro 1 - Halaman 1');
      expect(profile.progress, 0.0);
      expect(profile.avatarAsset, 'assets/brand/male-avatar.png');
      expect(profile.repeatFromPage, 1);
      expect(profile.repeatFromBook, 1);
    });

    test('fromJson with missing fields uses defaults', () {
      final json = <String, Object?>{};

      final profile = ChildProfile.fromJson(json);

      expect(profile.id, '');
      expect(profile.name, 'Anak');
      expect(profile.age, 7);
    });

    test('toJson serializes correctly', () {
      const profile = ChildProfile(
        id: 'child-1',
        name: 'Ahmad',
        age: 8,
        currentLesson: 'Iqro 2 - Halaman 5',
        progress: 0.65,
        avatarAsset: 'assets/brand/male-avatar.png',
      );

      final json = profile.toJson();

      expect(json['id'], 'child-1');
      expect(json['name'], 'Ahmad');
      expect(json['age'], 8);
      expect(json['progress'], 0.65);
      expect(json['repeatFromPage'], 1);
      expect(json['repeatFromBook'], 1);
    });

    test('copyWith creates new instance with changes', () {
      const original = ChildProfile(
        id: 'child-1',
        name: 'Ahmad',
        age: 8,
        currentLesson: 'Iqro 1',
        progress: 0.5,
        avatarAsset: 'assets/brand/male-avatar.png',
      );

      final updated = original.copyWith(
        name: 'Muhammad',
        progress: 0.75,
        repeatFromPage: 3,
      );

      expect(updated.name, 'Muhammad');
      expect(updated.progress, 0.75);
      expect(updated.repeatFromPage, 3);
      expect(updated.repeatFromBook, 1);
      expect(updated.id, 'child-1'); // unchanged
      expect(updated.age, 8); // unchanged
    });
  });

  group('LearningNote', () {
    test('fromJson with valid data', () {
      final json = {
        'title': 'Iqro 1 - Halaman 5',
        'date': '17 Jun 2026',
        'status': 'fluent',
        'note': 'Bacaan sudah lancar',
      };

      final note = LearningNote.fromJson(json);

      expect(note.title, 'Iqro 1 - Halaman 5');
      expect(note.date, '17 Jun 2026');
      expect(note.status, LearningStatus.fluent);
      expect(note.note, 'Bacaan sudah lancar');
    });

    test('fromJson with null values uses defaults', () {
      final json = <String, Object?>{
        'title': null,
        'date': null,
        'status': null,
        'note': null,
      };

      final note = LearningNote.fromJson(json);

      expect(note.title, '');
      expect(note.date, '');
      expect(note.status, LearningStatus.learning);
      expect(note.note, '');
    });

    test('fromJson with unknown status defaults to learning', () {
      final json = {
        'title': 'Test',
        'date': '2026-01-01',
        'status': 'unknown_status',
        'note': 'Test note',
      };

      final note = LearningNote.fromJson(json);

      expect(note.status, LearningStatus.learning);
    });

    test('toJson serializes correctly', () {
      const note = LearningNote(
        title: 'Iqro 1 - Halaman 5',
        date: '17 Jun 2026',
        status: LearningStatus.fluent,
        note: 'Bacaan sudah lancar',
      );

      final json = note.toJson();

      expect(json['title'], 'Iqro 1 - Halaman 5');
      expect(json['status'], 'fluent');
    });
  });

  group('LearningAttempt', () {
    test('fromJson with valid data', () {
      final json = {
        'id': 'attempt-1',
        'childId': 'child-1',
        'bookId': 1,
        'pageNumber': 5,
        'date': '2026-06-17',
        'durationSeconds': 120,
        'status': 'fluent',
        'assessmentStatus': 'fluent',
        'audioPath': '/path/to/audio.m4a',
        'score': 88,
        'feedback': 'Bagus!',
        'note': 'Lancar',
      };

      final attempt = LearningAttempt.fromJson(json);

      expect(attempt.id, 'attempt-1');
      expect(attempt.childId, 'child-1');
      expect(attempt.bookId, 1);
      expect(attempt.pageNumber, 5);
      expect(attempt.durationSeconds, 120);
      expect(attempt.status, LearningStatus.fluent);
      expect(attempt.assessmentStatus, ReadingAssessmentStatus.fluent);
      expect(attempt.score, 88);
    });

    test('fromJson with null values uses defaults', () {
      final json = <String, Object?>{
        'id': null,
        'childId': null,
        'bookId': null,
        'pageNumber': null,
        'date': null,
        'durationSeconds': null,
        'status': null,
      };

      final attempt = LearningAttempt.fromJson(json);

      expect(attempt.id, '');
      expect(attempt.childId, '');
      expect(attempt.bookId, 1);
      expect(attempt.pageNumber, 1);
      expect(attempt.date, '');
      expect(attempt.durationSeconds, 0);
      expect(attempt.status, LearningStatus.learning);
    });

    test('fromJson with unknown status defaults to learning', () {
      final json = {
        'id': 'attempt-1',
        'childId': 'child-1',
        'bookId': 1,
        'pageNumber': 1,
        'date': '2026-01-01',
        'durationSeconds': 60,
        'status': 'invalid_status',
      };

      final attempt = LearningAttempt.fromJson(json);

      expect(attempt.status, LearningStatus.learning);
    });

    test('toJson serializes correctly', () {
      const attempt = LearningAttempt(
        id: 'attempt-1',
        childId: 'child-1',
        bookId: 1,
        pageNumber: 5,
        date: '2026-06-17',
        durationSeconds: 120,
        status: LearningStatus.fluent,
        assessmentStatus: ReadingAssessmentStatus.fluent,
        score: 88,
        feedback: 'Bagus!',
        note: 'Lancar',
      );

      final json = attempt.toJson();

      expect(json['id'], 'attempt-1');
      expect(json['status'], 'fluent');
      expect(json['assessmentStatus'], 'fluent');
      expect(json['score'], 88);
    });

    test('copyWith creates new instance with changes', () {
      const original = LearningAttempt(
        id: 'attempt-1',
        childId: 'child-1',
        bookId: 1,
        pageNumber: 5,
        date: '2026-06-17',
        durationSeconds: 120,
        status: LearningStatus.learning,
      );

      final updated = original.copyWith(
        status: LearningStatus.fluent,
        score: 90,
      );

      expect(updated.status, LearningStatus.fluent);
      expect(updated.score, 90);
      expect(updated.id, 'attempt-1');
      expect(updated.durationSeconds, 120);
    });
  });

  group('ReadingAssessmentStatus', () {
    test('has correct labels', () {
      expect(ReadingAssessmentStatus.recorded.label, 'Menunggu Review');
      expect(ReadingAssessmentStatus.assessing.label, 'Menunggu Review');
      expect(ReadingAssessmentStatus.fluent.label, 'Disetujui');
      expect(ReadingAssessmentStatus.needsReview.label, 'Perlu Ulang');
    });
  });
}
