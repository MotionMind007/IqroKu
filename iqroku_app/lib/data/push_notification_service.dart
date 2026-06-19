import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'auth_api_service.dart';

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
  Future<void> unregisterDevice(AuthApiService authService);
  void dispose();
}

class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Future<void> registerParentDevice(AuthApiService authService) async {}

  @override
  Future<void> unregisterDevice(AuthApiService authService) async {}

  @override
  void dispose() {}
}

class FirebasePushNotificationService implements PushNotificationService {
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _lastToken;
  bool _initialized = false;
  bool _backgroundHandlerRegistered = false;

  @override
  Future<void> registerParentDevice(AuthApiService authService) async {
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
      await authService.registerDeviceToken(
        token: token,
        platform: _platform,
        userType: 'parent',
      );

      _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
          .listen((nextToken) {
            _lastToken = nextToken;
            unawaited(
              authService.registerDeviceToken(
                token: nextToken,
                platform: _platform,
                userType: 'parent',
              ),
            );
          });
    } on MissingPluginException catch (error) {
      debugPrint('Push notification plugin unavailable: $error');
    } on FirebaseException catch (error) {
      debugPrint('Firebase push setup failed: ${error.code}');
    } catch (error) {
      debugPrint('Push notification setup failed: $error');
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
    } catch (error) {
      debugPrint('Push token unregister failed: $error');
    }
  }

  @override
  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel());
    _tokenRefreshSubscription = null;
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
