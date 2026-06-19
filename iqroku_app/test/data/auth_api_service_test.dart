import 'package:flutter_test/flutter_test.dart';
import 'package:iqroku/data/auth_api_service.dart';

void main() {
  group('ParentAccount', () {
    test('fromJson with valid data', () {
      final json = {
        'id': 'parent-1',
        'name': 'Ahmad Fauzi',
        'email': 'ahmad@example.com',
        'hasPin': true,
      };

      final account = ParentAccount.fromJson(json);

      expect(account.id, 'parent-1');
      expect(account.name, 'Ahmad Fauzi');
      expect(account.email, 'ahmad@example.com');
      expect(account.hasPin, isTrue);
    });

    test('fromJson with null values uses defaults', () {
      final json = <String, Object?>{'id': null, 'name': null, 'email': null};

      final account = ParentAccount.fromJson(json);

      expect(account.id, '');
      expect(account.name, 'Orang Tua');
      expect(account.email, '');
      expect(account.hasPin, isFalse);
    });

    test('toJson serializes correctly', () {
      const account = ParentAccount(
        id: 'parent-1',
        name: 'Ahmad Fauzi',
        email: 'ahmad@example.com',
        hasPin: true,
      );

      final json = account.toJson();

      expect(json['id'], 'parent-1');
      expect(json['name'], 'Ahmad Fauzi');
      expect(json['email'], 'ahmad@example.com');
      expect(json['hasPin'], isTrue);
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
        'session': {'token': 'session_abc123', 'type': 'password'},
        'emailVerification': {
          'required': true,
          'expiresAt': '2026-06-19T00:00:00.000Z',
          'devToken': 'verify-token',
        },
      };

      final result = AuthResult.fromJson(json);

      expect(result.parent.id, 'parent-1');
      expect(result.parent.name, 'Ahmad');
      expect(result.sessionToken, 'session_abc123');
      expect(result.emailVerification?.required, isTrue);
      expect(result.emailVerification?.devToken, 'verify-token');
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

  group('AuthFlowInfo', () {
    test('fromJson uses optional dev token', () {
      final flow = AuthFlowInfo.fromJson({
        'required': true,
        'expiresAt': '2026-06-19T00:00:00.000Z',
        'devToken': 'token-dev',
      });

      expect(flow.required, isTrue);
      expect(flow.expiresAt, '2026-06-19T00:00:00.000Z');
      expect(flow.devToken, 'token-dev');
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

  group('SubscriptionStatus', () {
    test('fromJson parses active subscription dates', () {
      final status = SubscriptionStatus.fromJson({
        'active': true,
        'plan': 'plus',
        'activatedAt': '2026-06-19T00:00:00.000Z',
        'activeUntil': '2026-07-19T00:00:00.000Z',
      });

      expect(status.active, isTrue);
      expect(status.plan, 'plus');
      expect(status.activatedAt, isNotNull);
      expect(status.activeUntil, isNotNull);
    });
  });

  group('DokuCheckoutResult', () {
    test('fromJson parses checkout URL and payment order', () {
      final checkout = DokuCheckoutResult.fromJson({
        'checkoutUrl': 'https://checkout.doku.example/pay',
        'payment': {
          'invoiceNumber': 'IQK20260619ABC',
          'status': 'pending',
          'amount': 49000,
          'currency': 'IDR',
        },
      });

      expect(checkout.checkoutUrl, 'https://checkout.doku.example/pay');
      expect(checkout.payment.invoiceNumber, 'IQK20260619ABC');
      expect(checkout.payment.status, 'pending');
      expect(checkout.payment.amount, 49000);
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

  group('AuthApiService helpers', () {
    test('backendUrl resolves relative media URLs', () {
      final service = AuthApiService(baseUrl: 'https://iqroku.example');

      expect(
        service.backendUrl('/uploads/audio/attempt.m4a'),
        'https://iqroku.example/uploads/audio/attempt.m4a',
      );
      expect(
        service.backendUrl('https://cdn.example/audio.m4a'),
        'https://cdn.example/audio.m4a',
      );
    });

    test('audioPlaybackHeaders includes bearer token when available', () {
      final service = AuthApiService(baseUrl: 'https://iqroku.example');

      expect(service.audioPlaybackHeaders(), isEmpty);

      service.authToken = 'session-token';
      expect(service.audioPlaybackHeaders(), {
        'authorization': 'Bearer session-token',
      });
    });
  });
}
