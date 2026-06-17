import 'package:flutter_test/flutter_test.dart';
import 'package:iqroku/data/local_app_storage.dart';
import 'package:iqroku/data/auth_api_service.dart';
import 'package:iqroku/models/learning_status.dart';
import 'package:iqroku/models/profile_models.dart';

void main() {
  group('StoredIqrokuState', () {
    test('toJson with excludeSensitive excludes auth data', () {
      const state = StoredIqrokuState(
        childProfiles: [],
        iqroProgress: {},
        learningNotes: [],
        learningAttempts: [],
        selectedChildId: 'child-1',
        familyPlusActive: false,
        childSetupCompleted: true,
        selectedIqroBook: 1,
        selectedIqroPage: 5,
        parentAccount: ParentAccount(
          id: 'parent-1',
          name: 'Test',
          email: 'test@example.com',
        ),
        authToken: 'some-token',
      );

      final json = state.toJson(excludeSensitive: true);

      expect(json.containsKey('authToken'), false);
      expect(json.containsKey('parentAccount'), false);
      expect(json['selectedChildId'], 'child-1');
      expect(json['familyPlusActive'], false);
    });

    test('toJson without excludeSensitive includes auth data', () {
      const state = StoredIqrokuState(
        childProfiles: [],
        iqroProgress: {},
        learningNotes: [],
        learningAttempts: [],
        selectedChildId: 'child-1',
        familyPlusActive: false,
        childSetupCompleted: true,
        selectedIqroBook: 1,
        selectedIqroPage: 5,
        parentAccount: ParentAccount(
          id: 'parent-1',
          name: 'Test',
          email: 'test@example.com',
        ),
        authToken: 'some-token',
      );

      final json = state.toJson(excludeSensitive: false);

      expect(json.containsKey('authToken'), true);
      expect(json.containsKey('parentAccount'), true);
      expect(json['authToken'], 'some-token');
    });

    test('fromJson with valid data', () {
      final json = <String, Object?>{
        'childProfiles': [
          {
            'id': 'child-1',
            'name': 'Ahmad',
            'age': 8,
            'currentLesson': 'Iqro 1',
            'progress': 0.5,
            'avatarAsset': 'assets/brand/male-avatar.png',
          }
        ],
        'iqroProgress': <String, Object?>{},
        'learningNotes': <Object?>[],
        'learningAttempts': <Object?>[],
        'selectedChildId': 'child-1',
        'familyPlusActive': false,
        'childSetupCompleted': true,
        'selectedIqroBook': 1,
        'selectedIqroPage': 5,
      };

      final state = StoredIqrokuState.fromJson(json);

      expect(state.childProfiles.length, 1);
      expect(state.childProfiles.first.id, 'child-1');
      expect(state.selectedChildId, 'child-1');
      expect(state.selectedIqroBook, 1);
      expect(state.selectedIqroPage, 5);
    });

    test('fromJson with empty data uses defaults', () {
      final json = <String, Object?>{};

      final state = StoredIqrokuState.fromJson(json);

      expect(state.childProfiles, isEmpty);
      expect(state.learningNotes, isEmpty);
      expect(state.learningAttempts, isEmpty);
      expect(state.selectedChildId, '');
      expect(state.familyPlusActive, false);
      expect(state.childSetupCompleted, false);
      expect(state.selectedIqroBook, 1);
      expect(state.selectedIqroPage, 1);
    });

    test('fromJson with external authToken and parentAccount', () {
      final json = <String, Object?>{};

      final state = StoredIqrokuState.fromJson(
        json,
        authToken: 'external-token',
        parentAccount: const ParentAccount(
          id: 'parent-ext',
          name: 'External',
          email: 'ext@example.com',
        ),
      );

      expect(state.authToken, 'external-token');
      expect(state.parentAccount?.id, 'parent-ext');
    });

    test('fromJson with iqroProgress', () {
      final json = {
        'childProfiles': [],
        'iqroProgress': {
          'child-1': {
            '1': {'1': 'fluent', '2': 'learning'},
            '2': {'1': 'notStarted'},
          },
        },
        'learningNotes': [],
        'learningAttempts': [],
        'selectedChildId': 'child-1',
        'familyPlusActive': false,
        'childSetupCompleted': false,
        'selectedIqroBook': 1,
        'selectedIqroPage': 1,
      };

      final state = StoredIqrokuState.fromJson(json);

      expect(state.iqroProgress.length, 1);
      expect(state.iqroProgress['child-1']?[1]?[1], LearningStatus.fluent);
      expect(state.iqroProgress['child-1']?[1]?[2], LearningStatus.learning);
      expect(state.iqroProgress['child-1']?[2]?[1], LearningStatus.notStarted);
    });
  });
}
