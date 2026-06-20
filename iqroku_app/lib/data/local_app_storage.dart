import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_api_service.dart';
import '../models/learning_status.dart';
import '../models/profile_models.dart';

class LocalAppStorage {
  LocalAppStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _key = 'iqroku.local_state.v1';
  static const _secureStateKey = 'iqroku.secure_state.v1';
  static const _authTokenKey = 'iqroku.auth_token';
  static const _parentAccountKey = 'iqroku.parent_account';

  final FlutterSecureStorage _secureStorage;

  Future<StoredIqrokuState?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final secureRaw = await _secureStorage.read(key: _secureStateKey);
    final raw = secureRaw ?? preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final data = jsonDecode(raw) as Map<String, Object?>;

    // Compatibility path for versions that stored only auth fields securely.
    final authToken =
        data['authToken'] as String? ??
        await _secureStorage.read(key: _authTokenKey);
    final parentAccountJson = data['parentAccount'] == null
        ? await _secureStorage.read(key: _parentAccountKey)
        : null;
    ParentAccount? parentAccount;
    if (data['parentAccount'] is Map<String, Object?>) {
      parentAccount = ParentAccount.fromJson(
        data['parentAccount'] as Map<String, Object?>,
      );
    } else if (parentAccountJson != null && parentAccountJson.isNotEmpty) {
      parentAccount = ParentAccount.fromJson(
        jsonDecode(parentAccountJson) as Map<String, Object?>,
      );
    }

    return StoredIqrokuState.fromJson(
      data,
      authToken: authToken,
      parentAccount: parentAccount,
    );
  }

  Future<void> save(StoredIqrokuState state) async {
    final preferences = await SharedPreferences.getInstance();
    await _secureStorage.write(
      key: _secureStateKey,
      value: jsonEncode(state.toJson()),
    );
    await _secureStorage.delete(key: _authTokenKey);
    await _secureStorage.delete(key: _parentAccountKey);
    await preferences.remove(_key);
  }

  Future<void> clearSecureData() async {
    final preferences = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _secureStateKey);
    await _secureStorage.delete(key: _authTokenKey);
    await _secureStorage.delete(key: _parentAccountKey);
    await preferences.remove(_key);
  }
}

class StoredIqrokuState {
  const StoredIqrokuState({
    required this.childProfiles,
    required this.iqroProgress,
    required this.learningNotes,
    required this.learningAttempts,
    required this.selectedChildId,
    required this.familyPlusActive,
    required this.childSetupCompleted,
    required this.selectedIqroBook,
    required this.selectedIqroPage,
    this.adzanReminderEnabled = false,
    this.parentAccount,
    this.authToken,
    this.subscriptionActivatedAt,
    this.subscriptionActiveUntil,
    this.pendingDokuInvoiceNumber,
  });

  final List<ChildProfile> childProfiles;
  final Map<String, Map<int, Map<int, LearningStatus>>> iqroProgress;
  final List<LearningNote> learningNotes;
  final List<LearningAttempt> learningAttempts;
  final String selectedChildId;
  final bool familyPlusActive;
  final bool childSetupCompleted;
  final int selectedIqroBook;
  final int selectedIqroPage;
  final bool adzanReminderEnabled;
  final ParentAccount? parentAccount;
  final String? authToken;
  final DateTime? subscriptionActivatedAt;
  final DateTime? subscriptionActiveUntil;
  final String? pendingDokuInvoiceNumber;

  Map<String, Object?> toJson({bool excludeSensitive = false}) {
    return {
      'childProfiles': childProfiles.map((child) => child.toJson()).toList(),
      'iqroProgress': _encodeProgress(iqroProgress),
      'learningNotes': learningNotes.map((note) => note.toJson()).toList(),
      'learningAttempts': learningAttempts
          .map((attempt) => attempt.toJson())
          .toList(),
      'selectedChildId': selectedChildId,
      'familyPlusActive': familyPlusActive,
      'childSetupCompleted': childSetupCompleted,
      'selectedIqroBook': selectedIqroBook,
      'selectedIqroPage': selectedIqroPage,
      'adzanReminderEnabled': adzanReminderEnabled,
      if (!excludeSensitive) 'parentAccount': parentAccount?.toJson(),
      if (!excludeSensitive) 'authToken': authToken,
      'subscriptionActivatedAt': subscriptionActivatedAt?.toIso8601String(),
      'subscriptionActiveUntil': subscriptionActiveUntil?.toIso8601String(),
      'pendingDokuInvoiceNumber': pendingDokuInvoiceNumber,
    };
  }

  static StoredIqrokuState fromJson(
    Map<String, Object?> json, {
    String? authToken,
    ParentAccount? parentAccount,
  }) {
    final children = (json['childProfiles'] as List<Object?>? ?? [])
        .cast<Map<String, Object?>>()
        .map(ChildProfile.fromJson)
        .toList();
    final notes = (json['learningNotes'] as List<Object?>? ?? [])
        .cast<Map<String, Object?>>()
        .map(LearningNote.fromJson)
        .toList();
    final attempts = (json['learningAttempts'] as List<Object?>? ?? [])
        .cast<Map<String, Object?>>()
        .map(LearningAttempt.fromJson)
        .toList();

    return StoredIqrokuState(
      childProfiles: children,
      iqroProgress: _decodeProgress(
        json['iqroProgress'] as Map<String, Object?>? ?? {},
      ),
      learningNotes: notes,
      learningAttempts: attempts,
      selectedChildId: json['selectedChildId'] as String? ?? '',
      familyPlusActive: json['familyPlusActive'] as bool? ?? false,
      childSetupCompleted: json['childSetupCompleted'] as bool? ?? false,
      selectedIqroBook: json['selectedIqroBook'] as int? ?? 1,
      selectedIqroPage: json['selectedIqroPage'] as int? ?? 1,
      adzanReminderEnabled: json['adzanReminderEnabled'] as bool? ?? false,
      parentAccount: parentAccount ?? _decodeParent(json['parentAccount']),
      authToken: authToken ?? json['authToken'] as String?,
      subscriptionActivatedAt: _decodeDateTime(
        json['subscriptionActivatedAt'] as String?,
      ),
      subscriptionActiveUntil: _decodeDateTime(
        json['subscriptionActiveUntil'] as String?,
      ),
      pendingDokuInvoiceNumber: json['pendingDokuInvoiceNumber'] as String?,
    );
  }

  static DateTime? _decodeDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static ParentAccount? _decodeParent(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }
    return ParentAccount.fromJson(value);
  }

  static Map<String, Object?> _encodeProgress(
    Map<String, Map<int, Map<int, LearningStatus>>> progress,
  ) {
    return progress.map((childId, books) {
      return MapEntry(
        childId,
        books.map((bookId, pages) {
          return MapEntry(
            '$bookId',
            pages.map((page, status) => MapEntry('$page', status.name)),
          );
        }),
      );
    });
  }

  static Map<String, Map<int, Map<int, LearningStatus>>> _decodeProgress(
    Map<String, Object?> json,
  ) {
    return json.map((childId, booksRaw) {
      final books = (booksRaw as Map<String, Object?>).map((bookId, pagesRaw) {
        final pages = (pagesRaw as Map<String, Object?>).map((page, status) {
          return MapEntry(
            int.parse(page),
            LearningStatus.values.byName(status as String),
          );
        });
        return MapEntry(int.parse(bookId), pages);
      });
      return MapEntry(childId, books);
    });
  }
}
