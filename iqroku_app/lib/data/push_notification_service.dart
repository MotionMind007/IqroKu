import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'auth_api_service.dart';

void _debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

@pragma('vm:entry-point')
Future<void> iqrokuFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Background delivery must never crash the process if Firebase config
    // is not available in a local/test build.
  }
}

abstract class PushNotificationService {
  Future<void> registerParentDevice(AuthApiService authService);
  Future<void> registerChildDevice(AuthApiService authService, String childId);
  Future<void> unregisterDevice(AuthApiService authService);
  void dispose();
}

class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Future<void> registerParentDevice(AuthApiService authService) async {}

  @override
  Future<void> registerChildDevice(
    AuthApiService authService,
    String childId,
  ) async {}

  @override
  Future<void> unregisterDevice(AuthApiService authService) async {}

  @override
  void dispose() {}
}

class FirebasePushNotificationService implements PushNotificationService {
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _lastToken;
  bool _parentRegistered = false;
  final Set<String> _registeredChildIds = <String>{};
  bool _initialized = false;
  bool _backgroundHandlerRegistered = false;

  @override
  Future<void> registerParentDevice(AuthApiService authService) async {
    await _registerDevice(authService, userType: 'parent');
  }

  @override
  Future<void> registerChildDevice(
    AuthApiService authService,
    String childId,
  ) async {
    await _registerDevice(authService, userType: 'child', childId: childId);
  }

  Future<void> _registerDevice(
    AuthApiService authService, {
    required String userType,
    String? childId,
  }) async {
    if (kIsWeb) {
      return;
    }

    try {
      await _ensureInitialized();
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      _lastToken = token;
      _rememberRegistration(userType: userType, childId: childId);
      await _registerToken(
        authService,
        token,
        userType: userType,
        childId: childId,
      );

      _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
          .listen((nextToken) {
            _lastToken = nextToken;
            unawaited(_registerKnownDevices(authService, nextToken));
          });
    } on MissingPluginException catch (_) {
      _debugLog('Push notification plugin unavailable.');
    } on FirebaseException catch (error) {
      _debugLog('Firebase push setup failed: ${error.code}');
    } catch (_) {
      _debugLog('Push notification setup failed.');
    }
  }

  @override
  Future<void> unregisterDevice(AuthApiService authService) async {
    final token = _lastToken;
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      await authService.unregisterDeviceToken(token);
      _parentRegistered = false;
      _registeredChildIds.clear();
    } catch (_) {
      _debugLog('Push token unregister failed.');
    }
  }

  @override
  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel());
    _tokenRefreshSubscription = null;
  }

  void _rememberRegistration({required String userType, String? childId}) {
    if (userType == 'parent') {
      _parentRegistered = true;
    }
    if (userType == 'child' && childId != null && childId.isNotEmpty) {
      _registeredChildIds.add(childId);
    }
  }

  Future<void> _registerToken(
    AuthApiService authService,
    String token, {
    required String userType,
    String? childId,
  }) async {
    await authService.registerDeviceToken(
      token: token,
      platform: _platform,
      userType: userType,
      childId: childId,
    );
  }

  Future<void> _registerKnownDevices(
    AuthApiService authService,
    String token,
  ) async {
    try {
      if (_parentRegistered) {
        await _registerToken(authService, token, userType: 'parent');
      }
      for (final childId in _registeredChildIds) {
        await _registerToken(
          authService,
          token,
          userType: 'child',
          childId: childId,
        );
      }
    } catch (_) {
      _debugLog('Push token refresh registration failed.');
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    if (!_backgroundHandlerRegistered) {
      FirebaseMessaging.onBackgroundMessage(
        iqrokuFirebaseMessagingBackgroundHandler,
      );
      _backgroundHandlerRegistered = true;
    }
    _initialized = true;
  }

  String get _platform {
    if (kIsWeb) {
      return 'web';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    }
    return 'unknown';
  }
}
