import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

abstract class VoiceRecordingService {
  Future<String> start({
    required String childId,
    required int bookId,
    required int pageNumber,
  });

  Future<String?> stop();
  Future<void> cancel();
  void dispose();
}

class LocalVoiceRecordingService implements VoiceRecordingService {
  LocalVoiceRecordingService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _activePath;

  @override
  Future<String> start({
    required String childId,
    required int bookId,
    required int pageNumber,
  }) async {
    if (!await _recorder.hasPermission()) {
      throw const VoiceRecordingPermissionDenied();
    }

    final directory = await getApplicationDocumentsDirectory();
    final recordingsDirectory = Directory('${directory.path}/voice_attempts');
    if (!recordingsDirectory.existsSync()) {
      recordingsDirectory.createSync(recursive: true);
    }

    final safeChildId = childId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        '${recordingsDirectory.path}/${safeChildId}_j${bookId}_p${pageNumber}_$timestamp.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
      ),
      path: path,
    );
    _activePath = path;
    return path;
  }

  @override
  Future<String?> stop() async {
    final path = await _recorder.stop();
    _activePath = null;
    return path;
  }

  @override
  Future<void> cancel() async {
    await _recorder.cancel();
    final path = _activePath;
    _activePath = null;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
  }
}

class VoiceRecordingPermissionDenied implements Exception {
  const VoiceRecordingPermissionDenied();
}
