import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

abstract class AudioPlaybackService {
  Stream<void> get onComplete;

  Future<void> play(String path, {Map<String, String>? headers});

  Future<void> stop();

  void dispose();
}

class LocalAudioPlaybackService implements AudioPlaybackService {
  LocalAudioPlaybackService({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final StreamController<void> _completeController =
      StreamController<void>.broadcast();
  StreamSubscription<void>? _completeSubscription;

  @override
  Stream<void> get onComplete => _completeController.stream;

  @override
  Future<void> play(String path, {Map<String, String>? headers}) async {
    _completeSubscription ??= _player.onPlayerComplete.listen((_) {
      if (!_completeController.isClosed) {
        _completeController.add(null);
      }
    });
    await _player.stop();
    final isRemote = path.startsWith('http://') || path.startsWith('https://');
    final source = headers != null && headers.isNotEmpty && isRemote
        ? await _authenticatedSource(path, headers)
        : isRemote
        ? UrlSource(path)
        : DeviceFileSource(path);
    await _player.play(source);
  }

  Future<Source> _authenticatedSource(
    String path,
    Map<String, String> headers,
  ) async {
    final response = await http
        .get(Uri.parse(path), headers: headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('audio_download_failed');
    }
    return BytesSource(
      response.bodyBytes,
      mimeType: response.headers['content-type'],
    );
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  @override
  void dispose() {
    unawaited(_completeSubscription?.cancel());
    _completeController.close();
    unawaited(_player.dispose());
  }
}
