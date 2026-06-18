import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../models/learning_status.dart';
import '../models/profile_models.dart';

class AuthApiService {
  AuthApiService({
    this.baseUrl = const String.fromEnvironment(
      'IQROKU_API_BASE',
      defaultValue: 'https://iqroku.motionmind.store',
    ),
  }) {
    if (baseUrl.startsWith('http://')) {
      developer.log(
        'WARNING: Using insecure HTTP connection to $baseUrl. '
        'Use HTTPS in production builds.',
        name: 'AuthApiService',
      );
    }
  }

  final String baseUrl;

  /// Auth token set after login/register, used for authenticated requests.
  String? authToken;

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final json = await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    }, authenticated: false);
    return AuthResult.fromJson(json);
  }

  Future<ParentAccount> verifyEmail(String token) async {
    final json = await _post('/auth/verify-email', {
      'token': token,
    }, authenticated: false);
    return ParentAccount.fromJson(json['parent'] as Map<String, Object?>);
  }

  Future<AuthFlowInfo?> resendVerification(String email) async {
    final json = await _post('/auth/resend-verification', {
      'email': email,
    }, authenticated: false);
    final flow = json['emailVerification'];
    return flow is Map<String, Object?> ? AuthFlowInfo.fromJson(flow) : null;
  }

  Future<AuthFlowInfo?> requestPasswordReset(String email) async {
    final json = await _post('/auth/password-reset/request', {
      'email': email,
    }, authenticated: false);
    final flow = json['passwordReset'];
    return flow is Map<String, Object?> ? AuthFlowInfo.fromJson(flow) : null;
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String password,
  }) async {
    await _post('/auth/password-reset/confirm', {
      'token': token,
      'password': password,
    }, authenticated: false);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final json = await _post('/auth/login', {
      'email': email,
      'password': password,
    }, authenticated: false);
    return AuthResult.fromJson(json);
  }

  Future<AuthResult> loginWithGoogle({
    required String idToken,
    required String email,
    required String name,
    required String googleId,
  }) async {
    final json = await _post('/auth/google', {
      'idToken': idToken,
      'email': email,
      'name': name,
      'googleId': googleId,
    }, authenticated: false);
    return AuthResult.fromJson(json);
  }

  Future<List<ChildProfile>> loadChildren(String parentId) async {
    final response = await http
        .get(_uri('/children', {'parentId': parentId}), headers: _authHeaders())
        .timeout(const Duration(seconds: 15));
    final json = _decodeResponse(response);
    return (json as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(_childFromJson)
        .toList(growable: false);
  }

  Future<List<RemoteIqroProgress>> loadProgress(String childId) async {
    final response = await http
        .get(_uri('/progress', {'childId': childId}), headers: _authHeaders())
        .timeout(const Duration(seconds: 15));
    final json = _decodeResponse(response);
    return (json as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(RemoteIqroProgress.fromJson)
        .toList(growable: false);
  }

  Future<ChildProfile> createChild({
    required String parentId,
    required String name,
    required int age,
    required String avatarAsset,
  }) async {
    final json = await _post('/children', {
      'parentId': parentId,
      'name': name,
      'age': age,
      'avatarAsset': avatarAsset,
    });
    return _childFromJson(json);
  }

  Future<void> updateProgress({
    required String childId,
    required int bookId,
    required int pageNumber,
    required LearningStatus status,
  }) async {
    await _put('/progress', {
      'childId': childId,
      'bookId': bookId,
      'pageNumber': pageNumber,
      'status': status.name,
    });
  }

  Future<RemoteAttempt> createAttempt({
    String? id,
    required String childId,
    required int bookId,
    required int pageNumber,
    required int durationSeconds,
    String? audioPath,
  }) async {
    final body = <String, Object?>{
      'childId': childId,
      'bookId': bookId,
      'pageNumber': pageNumber,
      'durationSeconds': durationSeconds,
      'audioPath': audioPath,
    };
    if (id != null && id.isNotEmpty) {
      body['id'] = id;
    }
    final json = await _post('/attempts', body);
    return RemoteAttempt.fromJson(json);
  }

  Future<void> uploadAudio({
    required String attemptId,
    required String audioPath,
  }) async {
    final uri = _uri('/attempts/$attemptId/audio');
    final request = http.MultipartRequest('POST', uri);

    // Add auth header
    final token = authToken;
    if (token != null && token.isNotEmpty) {
      request.headers['authorization'] = 'Bearer $token';
    }

    // Add audio file
    request.files.add(await http.MultipartFile.fromPath('audio', audioPath));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = response.body.isEmpty
          ? 'upload_failed'
          : jsonDecode(response.body)['error'] ?? 'upload_failed';
      throw AuthApiException(
        response.statusCode,
        error is String ? error : 'upload_failed',
      );
    }
  }

  Future<void> activateSubscription(String parentId) async {
    await _post('/subscriptions/activate', {'parentId': parentId});
  }

  // --- PIN Management ---

  Future<void> setParentPin(String pin) async {
    await _post('/auth/set-parent-pin', {'pin': pin});
  }

  Future<bool> verifyParentPin(String pin) async {
    final result = await _post('/auth/verify-parent-pin', {'pin': pin});
    return result['valid'] == true;
  }

  Future<ChildAccount> childLogin(String childId, String pin) async {
    final result = await _post('/auth/child-login', {
      'childId': childId,
      'pin': pin,
    });
    if (result['valid'] != true) {
      throw const AuthApiException(401, 'invalid_pin');
    }
    return ChildAccount.fromJson(result['child'] as Map<String, Object?>);
  }

  Future<void> setChildPin(String childId, String pin) async {
    await _post('/children/$childId/set-pin', {'pin': pin});
  }

  Future<void> setChildSchedule({
    required String childId,
    required String startTime,
    required String endTime,
    required List<int> days,
  }) async {
    await _post('/children/$childId/schedule', {
      'startTime': startTime,
      'endTime': endTime,
      'days': days,
    });
  }

  // --- Review System ---

  Future<List<Map<String, Object?>>> getPendingReviews() async {
    final result = await _get('/reviews/pending');
    return (result as List<Object?>).cast<Map<String, Object?>>();
  }

  Future<Map<String, Object?>> approveReview(String attemptId) async {
    return await _post('/reviews/approve', {'attemptId': attemptId});
  }

  Future<Map<String, Object?>> repeatReview({
    required String attemptId,
    required int fromPage,
  }) async {
    return await _post('/reviews/repeat', {
      'attemptId': attemptId,
      'fromPage': fromPage,
    });
  }

  // --- Notifications ---

  Future<List<Map<String, Object?>>> getNotifications({
    String userType = 'parent',
    String? childId,
  }) async {
    final queryParams = <String, String>{'type': userType};
    if (childId != null) queryParams['childId'] = childId;
    final result = await _get('/notifications', queryParams);
    return (result as List<Object?>).cast<Map<String, Object?>>();
  }

  Future<int> getUnreadCount({
    String userType = 'parent',
    String? childId,
  }) async {
    final queryParams = <String, String>{'type': userType};
    if (childId != null) queryParams['childId'] = childId;
    final result = await _get('/notifications/unread-count', queryParams);
    final map = result as Map<String, Object?>? ?? {};
    return map['count'] as int? ?? 0;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _post('/notifications/$notificationId/read', {});
  }

  Future<void> markAllNotificationsRead({
    String userType = 'parent',
    String? childId,
  }) async {
    final body = <String, String>{'type': userType};
    if (childId != null) body['childId'] = childId;
    await _post('/notifications/read-all', body);
  }

  String backendUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$root$normalizedPath';
  }

  Map<String, String> audioPlaybackHeaders() {
    final token = authToken;
    if (token == null || token.isEmpty) {
      return const {};
    }
    return {'authorization': 'Bearer $token'};
  }

  Map<String, String> _authHeaders() {
    final token = authToken;
    if (token == null || token.isEmpty) {
      return const {'content-type': 'application/json; charset=utf-8'};
    }
    return {
      'content-type': 'application/json; charset=utf-8',
      'authorization': 'Bearer $token',
    };
  }

  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body, {
    bool authenticated = true,
  }) async {
    final response = await http
        .post(
          _uri(path),
          headers: authenticated
              ? _authHeaders()
              : const {'content-type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _decodeResponse(response) as Map<String, Object?>;
  }

  Future<Map<String, Object?>> _put(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await http
        .put(_uri(path), headers: _authHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _decodeResponse(response) as Map<String, Object?>;
  }

  Future<Object?> _get(String path, [Map<String, String>? query]) async {
    final response = await http
        .get(_uri(path, query), headers: _authHeaders())
        .timeout(const Duration(seconds: 15));
    return _decodeResponse(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path').replace(queryParameters: query);
  }

  Object? _decodeResponse(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final error = body is Map<String, Object?> ? body['error'] : null;
    throw AuthApiException(
      response.statusCode,
      error is String ? error : 'request_failed',
    );
  }

  ChildProfile _childFromJson(Map<String, Object?> json) {
    return ChildProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Anak',
      age: json['age'] as int? ?? 7,
      currentLesson: 'Iqro 1 - Halaman 1',
      progress: 0,
      avatarAsset:
          json['avatarAsset'] as String? ?? 'assets/brand/male-avatar.png',
      repeatFromPage: (json['repeatFromPage'] as num?)?.toInt() ?? 1,
      repeatFromBook: (json['repeatFromBook'] as num?)?.toInt() ?? 1,
    );
  }
}

class RemoteAttempt {
  const RemoteAttempt({required this.id});

  final String id;

  static RemoteAttempt fromJson(Map<String, Object?> json) {
    return RemoteAttempt(id: json['id'] as String? ?? '');
  }
}

class RemoteIqroProgress {
  const RemoteIqroProgress({
    required this.childId,
    required this.bookId,
    required this.pageNumber,
    required this.status,
  });

  final String childId;
  final int bookId;
  final int pageNumber;
  final LearningStatus status;

  static RemoteIqroProgress fromJson(Map<String, Object?> json) {
    return RemoteIqroProgress(
      childId: json['childId'] as String? ?? '',
      bookId: (json['bookId'] as num?)?.toInt() ?? 1,
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      status: _statusFromJson(json['status']),
    );
  }

  static LearningStatus _statusFromJson(Object? value) {
    final name = value as String? ?? '';
    for (final status in LearningStatus.values) {
      if (status.name == name) {
        return status;
      }
    }
    return LearningStatus.learning;
  }
}

class AuthResult {
  const AuthResult({
    required this.parent,
    required this.sessionToken,
    this.emailVerification,
  });

  final ParentAccount parent;
  final String sessionToken;
  final AuthFlowInfo? emailVerification;

  static AuthResult fromJson(Map<String, Object?> json) {
    final parentJson = json['parent'] as Map<String, Object?>;
    final sessionJson = json['session'] as Map<String, Object?>;
    return AuthResult(
      parent: ParentAccount.fromJson(parentJson),
      sessionToken: sessionJson['token'] as String? ?? '',
      emailVerification: json['emailVerification'] is Map<String, Object?>
          ? AuthFlowInfo.fromJson(
              json['emailVerification'] as Map<String, Object?>,
            )
          : null,
    );
  }
}

class AuthFlowInfo {
  const AuthFlowInfo({
    this.required = false,
    this.expiresAt,
    this.devToken,
  });

  final bool required;
  final String? expiresAt;
  final String? devToken;

  static AuthFlowInfo fromJson(Map<String, Object?> json) {
    return AuthFlowInfo(
      required: json['required'] as bool? ?? false,
      expiresAt: json['expiresAt'] as String?,
      devToken: json['devToken'] as String?,
    );
  }
}

class ParentAccount {
  const ParentAccount({
    required this.id,
    required this.name,
    required this.email,
    this.emailVerified = false,
  });

  final String id;
  final String name;
  final String email;
  final bool emailVerified;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'emailVerified': emailVerified,
    };
  }

  static ParentAccount fromJson(Map<String, Object?> json) {
    return ParentAccount(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Orang Tua',
      email: json['email'] as String? ?? '',
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.statusCode, this.code);

  final int statusCode;
  final String code;
}

class ChildAccount {
  const ChildAccount({
    required this.id,
    required this.name,
    required this.age,
    required this.avatarAsset,
    this.studyStartTime,
    this.studyEndTime,
    this.studyDays = const [1, 2, 3, 4, 5],
    this.repeatFromPage = 1,
    this.repeatFromBook = 1,
  });

  final String id;
  final String name;
  final int age;
  final String avatarAsset;
  final String? studyStartTime;
  final String? studyEndTime;
  final List<int> studyDays;
  final int repeatFromPage;
  final int repeatFromBook;

  static ChildAccount fromJson(Map<String, Object?> json) {
    return ChildAccount(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Anak',
      age: (json['age'] as num?)?.toInt() ?? 7,
      avatarAsset:
          json['avatarAsset'] as String? ?? 'assets/brand/male-avatar.png',
      studyStartTime: json['studyStartTime'] as String?,
      studyEndTime: json['studyEndTime'] as String?,
      studyDays:
          (json['studyDays'] as List<Object?>?)?.cast<int>() ?? [1, 2, 3, 4, 5],
      repeatFromPage: (json['repeatFromPage'] as num?)?.toInt() ?? 1,
      repeatFromBook: (json['repeatFromBook'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'avatarAsset': avatarAsset,
      'studyStartTime': studyStartTime,
      'studyEndTime': studyEndTime,
      'studyDays': studyDays,
      'repeatFromPage': repeatFromPage,
      'repeatFromBook': repeatFromBook,
    };
  }
}
