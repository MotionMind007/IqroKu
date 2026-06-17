import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/quran_models.dart';

class QuranApiService {
  const QuranApiService({
    this.baseUrl = 'https://equran.id/api/v2',
    this.reciterCode = '05',
  });

  final String baseUrl;
  final String reciterCode;

  Future<List<Surah>> fetchSurahs() async {
    final response = await http.get(_uri('/surat'))
        .timeout(const Duration(seconds: 15));
    final data = _decodeData(response) as List<Object?>;
    return data
        .cast<Map<String, Object?>>()
        .map(_surahFromJson)
        .toList(growable: false);
  }

  Future<SurahDetail> fetchSurahDetail(int surahId) async {
    final response = await http.get(_uri('/surat/$surahId'))
        .timeout(const Duration(seconds: 15));
    final data = _decodeData(response) as Map<String, Object?>;
    final surah = _surahFromJson(data);
    final ayahs = (data['ayat'] as List<Object?>? ?? [])
        .cast<Map<String, Object?>>()
        .map(_ayahFromJson)
        .toList(growable: false);
    return SurahDetail(
      surah: surah,
      ayahs: ayahs,
      audioUrl: _audioUrl(data['audioFull']),
    );
  }

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }

  Object? _decodeData(http.Response response) {
    final json = jsonDecode(response.body) as Map<String, Object?>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json['data'];
    }
    throw QuranApiException(json['message'] as String? ?? 'quran_failed');
  }

  Surah _surahFromJson(Map<String, Object?> json) {
    final id = _intValue(json['nomor']);
    return Surah(
      id: id,
      name: json['namaLatin'] as String? ?? 'Surat $id',
      meaning: json['arti'] as String? ?? '',
      arabicName: json['nama'] as String? ?? '',
      ayahCount: _intValue(json['jumlahAyat']),
      juz: _estimatedJuz(id),
    );
  }

  QuranAyah _ayahFromJson(Map<String, Object?> json) {
    return QuranAyah(
      number: _intValue(json['nomorAyat']),
      arabic: json['teksArab'] as String? ?? '',
      translation: json['teksIndonesia'] as String? ?? '',
      latin: json['teksLatin'] as String?,
      audioUrl: _audioUrl(json['audio']),
    );
  }

  String? _audioUrl(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    if (value is Map<String, Object?>) {
      final selected = value[reciterCode];
      if (selected is String && selected.isNotEmpty) {
        return selected;
      }
      for (final item in value.values) {
        if (item is String && item.isNotEmpty) {
          return item;
        }
      }
    }
    return null;
  }

  int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  int _estimatedJuz(int surahId) {
    // Accurate mapping of first surah in each Juz
    const juzStarts = [
      1, 2, 2, 3, 4, 4, 5, 6, 7, 8,
      9, 11, 12, 15, 17, 18, 21, 23, 25, 27,
      29, 33, 36, 39, 41, 46, 51, 58, 67, 78,
    ];
    for (int i = juzStarts.length - 1; i >= 0; i--) {
      if (surahId >= juzStarts[i]) {
        return i + 1;
      }
    }
    return 1;
  }
}

class QuranApiException implements Exception {
  const QuranApiException(this.message);

  final String message;
}
