import '../../data/services/tts_service.dart';

enum PlayTextBlockPhase {
  started,
  completed,
  failed,
  cancelled,
}

class PlayTextBlockResult {
  final PlayTextBlockPhase phase;
  final String text;

  const PlayTextBlockResult({
    required this.phase,
    required this.text,
  });
}

class PlayTextBlockUseCase {
  PlayTextBlockUseCase(this._ttsService);

  final TtsService _ttsService;

  bool get isPlaying => _ttsService.isSpeaking;

  Future<void> stop() => _ttsService.stop();

  Future<PlayTextBlockResult> speak(String text) async {
    try {
      await _ttsService.speak(text);
      return PlayTextBlockResult(
          phase: PlayTextBlockPhase.completed, text: text);
    } catch (e) {
      return PlayTextBlockResult(phase: PlayTextBlockPhase.failed, text: text);
    }
  }
}
