import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/iqro_models.dart';

class IqroContentRepository {
  const IqroContentRepository({
    this.assetPath = 'assets/content/iqro_complete_jilid_1-6.json',
  });

  final String assetPath;

  Future<IqroContent> load() async {
    final payload = await rootBundle.loadString(assetPath);
    final json = jsonDecode(payload) as Map<String, Object?>;
    return IqroContent.fromJson(json);
  }
}
