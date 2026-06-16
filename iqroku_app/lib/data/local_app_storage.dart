import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/learning_status.dart';
import '../models/profile_models.dart';

class LocalAppStorage {
  const LocalAppStorage();

  static const _key = 'iqroku.local_state.v1';

  Future<StoredIqrokuState?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final data = jsonDecode(raw) as Map<String, Object?>;
    return StoredIqrokuState.fromJson(data);
  }

  Future<void> save(StoredIqrokuState state) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, jsonEncode(state.toJson()));
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
    this.subscriptionActivatedAt,
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
  final DateTime? subscriptionActivatedAt;

  Map<String, Object?> toJson() {
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
      'subscriptionActivatedAt': subscriptionActivatedAt?.toIso8601String(),
    };
  }

  static StoredIqrokuState fromJson(Map<String, Object?> json) {
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
      subscriptionActivatedAt: _decodeDateTime(
        json['subscriptionActivatedAt'] as String?,
      ),
    );
  }

  static DateTime? _decodeDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
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
