import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/prayer_models.dart';

class DailyPrayerApiService {
  const DailyPrayerApiService({
    this.baseUrl = const String.fromEnvironment(
      'IQROKU_API_BASE',
      defaultValue: 'http://127.0.0.1:8787',
    ),
  });

  final String baseUrl;

  Future<List<DailyPrayer>> fetchDailyPrayers() async {
    final response = await http.get(_uri('/daily-prayers'));
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DailyPrayerApiException(response.statusCode);
    }
    return (body as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(DailyPrayer.fromJson)
        .toList(growable: false);
  }

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }
}

class DailyPrayerApiException implements Exception {
  const DailyPrayerApiException(this.statusCode);

  final int statusCode;
}
