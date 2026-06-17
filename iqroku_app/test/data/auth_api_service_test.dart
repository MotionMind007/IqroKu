import 'package:flutter_test/flutter_test.dart';
import 'package:iqroku/data/auth_api_service.dart';

void main() {
  group('ParentAccount', () {
    test('fromJson with valid data', () {
      final json = {
        'id': 'parent-1',
        'name': 'Ahmad Fauzi',
        'email': 'ahmad@example.com',
      };

      final account = ParentAccount.fromJson(json);

      expect(account.id, 'parent-1');
      expect(account.name, 'Ahmad Fauzi');
      expect(account.email, 'ahmad@example.com');
    });

    test('fromJson with null values uses defaults', () {
      final json = <String, Object?>{
        'id': null,
        'name': null,
        'email': null,
      };

      final account = ParentAccount.fromJson(json);

      expect(account.id, '');
      expect(account.name, 'Orang Tua');
      expect(account.email, '');
    });

    test('toJson serializes correctly', () {
      const account = ParentAccount(
        id: 'parent-1',
        name: 'Ahmad Fauzi',
        email: 'ahmad@example.com',
      );

      final json = account.toJson();

      expect(json['id'], 'parent-1');
      expect(json['name'], 'Ahmad Fauzi');
      expect(json['email'], 'ahmad@example.com');
    });
  });

  group('AuthResult', () {
    test('fromJson with valid data', () {
      final json = {
        'parent': {
          'id': 'parent-1',
          'name': 'Ahmad',
          'email': 'ahmad@example.com',
        },
        'session': {
          'token': 'session_abc123',
          'type': 'password',
        },
      };

      final result = AuthResult.fromJson(json);

      expect(result.parent.id, 'parent-1');
      expect(result.parent.name, 'Ahmad');
      expect(result.sessionToken, 'session_abc123');
    });

    test('fromJson with missing session token', () {
      final json = {
        'parent': {
          'id': 'parent-1',
          'name': 'Ahmad',
          'email': 'ahmad@example.com',
        },
        'session': <String, Object?>{},
      };

      final result = AuthResult.fromJson(json);

      expect(result.sessionToken, '');
    });
  });

  group('RemoteAttempt', () {
    test('fromJson with valid data', () {
      final json = {'id': 'attempt-1'};

      final attempt = RemoteAttempt.fromJson(json);

      expect(attempt.id, 'attempt-1');
    });

    test('fromJson with null id', () {
      final json = <String, Object?>{'id': null};

      final attempt = RemoteAttempt.fromJson(json);

      expect(attempt.id, '');
    });
  });

  group('RemoteIqroProgress', () {
    test('fromJson with valid data', () {
      final json = {
        'childId': 'child-1',
        'bookId': 1,
        'pageNumber': 5,
        'status': 'fluent',
      };

      final progress = RemoteIqroProgress.fromJson(json);

      expect(progress.childId, 'child-1');
      expect(progress.bookId, 1);
      expect(progress.pageNumber, 5);
    });

    test('fromJson with null values uses defaults', () {
      final json = <String, Object?>{
        'childId': null,
        'bookId': null,
        'pageNumber': null,
        'status': null,
      };

      final progress = RemoteIqroProgress.fromJson(json);

      expect(progress.childId, '');
      expect(progress.bookId, 1);
      expect(progress.pageNumber, 1);
    });
  });

  group('AuthApiException', () {
    test('stores status code and error code', () {
      const exception = AuthApiException(401, 'unauthorized');

      expect(exception.statusCode, 401);
      expect(exception.code, 'unauthorized');
    });
  });
}
