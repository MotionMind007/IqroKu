import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

abstract class AudioPlaybackService {
  Stream<void> get onComplete;

  Future<void> play(String path);

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
  Future<void> play(String path) async {
    _completeSubscription ??= _player.onPlayerComplete.listen((_) {
      if (!_completeController.isClosed) {
        _completeController.add(null);
      }
    });
    await _player.stop();
    await _player.play(DeviceFileSource(path));
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
