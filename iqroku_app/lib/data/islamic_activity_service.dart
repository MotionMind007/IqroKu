import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/prayer_models.dart';

class IslamicActivityService {
  const IslamicActivityService({
    this.baseUrl = 'https://api.aladhan.com/v1',
    this.latitude = -2.5489,
    this.longitude = 140.7197,
    this.locationLabel = 'Jayapura, Papua',
  });

  final String baseUrl;
  final double latitude;
  final double longitude;
  final String locationLabel;

  Future<PrayerSchedule> fetchPrayerSchedule() async {
    final location = await _resolveLocation();
    final response = await http.get(
      _uri('/timings', {
        'latitude': '${location.latitude}',
        'longitude': '${location.longitude}',
        'method': '20',
      }),
    ).timeout(const Duration(seconds: 15));
    final data = _decodeData(response) as Map<String, Object?>;
    final timings = data['timings'] as Map<String, Object?>? ?? {};
    final date = data['date'] as Map<String, Object?>? ?? {};
    final readableDate = date['readable'] as String? ?? '';
    final hijri = date['hijri'] as Map<String, Object?>? ?? {};
    final hijriDate = hijri['date'] as String? ?? '';
    final activeName = _nextPrayerName(timings);

    return PrayerSchedule(
      locationLabel: location.label,
      dateLabel: hijriDate.isEmpty
          ? readableDate
          : '$readableDate / $hijriDate H',
      latitude: location.latitude,
      longitude: location.longitude,
      locationSource: location.source,
      times: [
        _time('Imsak', timings, 'Imsak', activeName),
        _time('Subuh', timings, 'Fajr', activeName),
        _time('Terbit', timings, 'Sunrise', activeName),
        _time('Dzuhur', timings, 'Dhuhr', activeName),
        _time('Ashar', timings, 'Asr', activeName),
        _time('Maghrib', timings, 'Maghrib', activeName),
        _time('Isya', timings, 'Isha', activeName),
      ],
    );
  }

  Future<QiblaDirection> fetchQiblaDirection() async {
    final location = await _resolveLocation();
    final response = await http.get(
      _uri('/qibla/${location.latitude}/${location.longitude}'),
    ).timeout(const Duration(seconds: 15));
    final data = _decodeData(response) as Map<String, Object?>;
    return QiblaDirection(
      degrees: _doubleValue(data['direction']),
      latitude: location.latitude,
      longitude: location.longitude,
      locationLabel: location.label,
      locationSource: location.source,
    );
  }

  Future<_ResolvedLocation> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _fallbackLocation();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _fallbackLocation();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final label = await _labelForPosition(position);
      return _ResolvedLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        label: label,
        source: LocationSource.device,
      );
    } catch (_) {
      return _fallbackLocation();
    }
  }

  Future<String> _labelForPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 5));
      if (placemarks.isEmpty) {
        return _coordinateLabel(position.latitude, position.longitude);
      }
      final place = placemarks.first;
      final parts =
          [
                place.subLocality,
                place.locality,
                place.subAdministrativeArea,
                place.administrativeArea,
              ]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toSet()
              .take(2)
              .toList(growable: false);
      if (parts.isEmpty) {
        return _coordinateLabel(position.latitude, position.longitude);
      }
      return parts.join(', ');
    } catch (_) {
      return _coordinateLabel(position.latitude, position.longitude);
    }
  }

  String _coordinateLabel(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  _ResolvedLocation _fallbackLocation() {
    return _ResolvedLocation(
      latitude: latitude,
      longitude: longitude,
      label: '$locationLabel (fallback)',
      source: LocationSource.fallback,
    );
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path').replace(queryParameters: query);
  }

  Object? _decodeData(http.Response response) {
    final json = jsonDecode(response.body) as Map<String, Object?>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json['data'];
    }
    throw IslamicActivityException(
      json['data'] as String? ?? 'activity_failed',
    );
  }

  PrayerTime _time(
    String name,
    Map<String, Object?> timings,
    String apiKey,
    String activeName,
  ) {
    return PrayerTime(
      name: name,
      time: _cleanTime(timings[apiKey] as String? ?? '--:--'),
      active: name == activeName,
    );
  }

  String _cleanTime(String value) {
    return value.split(' ').first.trim();
  }

  String _nextPrayerName(Map<String, Object?> timings) {
    final now = DateTime.now();
    final entries = <MapEntry<String, String>>[
      MapEntry('Subuh', _cleanTime(timings['Fajr'] as String? ?? '00:00')),
      MapEntry('Dzuhur', _cleanTime(timings['Dhuhr'] as String? ?? '00:00')),
      MapEntry('Ashar', _cleanTime(timings['Asr'] as String? ?? '00:00')),
      MapEntry('Maghrib', _cleanTime(timings['Maghrib'] as String? ?? '00:00')),
      MapEntry('Isya', _cleanTime(timings['Isha'] as String? ?? '00:00')),
    ];

    for (final entry in entries) {
      final parts = entry.value.split(':');
      if (parts.length < 2) {
        continue;
      }
      final prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 0,
      );
      if (now.isBefore(prayerTime)) {
        return entry.key;
      }
    }
    return entries.first.key;
  }

  double _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }
}

class _ResolvedLocation {
  const _ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final String label;
  final LocationSource source;
}

class IslamicActivityException implements Exception {
  const IslamicActivityException(this.message);

  final String message;
}
