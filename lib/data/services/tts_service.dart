import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'tts_cache_service.dart';
import 'storage_service.dart';
import 'supertonic_service.dart';
import 'supertonic_model_service.dart';
import '../../core/constants/app_log.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/platform_utils.dart';

enum TtsPlaybackPhase { idle, loading, playing, completed, error }

class TtsPlaybackState {
  final TtsPlaybackPhase phase;
  final String? text;
  final Object? error;

  const TtsPlaybackState({
    required this.phase,
    this.text,
    this.error,
  });
}

class TtsService {
  static final TtsService _instance = TtsService._internal();
  static TtsService get instance => _instance;
  TtsService._internal();

  final _stateController = StreamController<TtsPlaybackState>.broadcast();
  Stream<TtsPlaybackState> get stateStream => _stateController.stream;

  FlutterTts _flutterTts = FlutterTts();
  AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isLoading = false;
  String? _currentText;
  Completer<void>? _speakCompleter;

  VoidCallback? onLoadingStarted;
  VoidCallback? onPlayingStarted;
  VoidCallback? onPlayingComplete;

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('TTS已初始化');
      return;
    }

    debugPrint('开始初始化TTS');

    await TtsCacheService.instance.initialize();

    if (PlatformUtils.supportsSystemTts) {
      await _flutterTts.setSharedInstance(true);
      debugPrint('设置SharedInstance完成');

      await _flutterTts.setLanguage('en-US');
      debugPrint('设置语言完成');

      final settings = StorageService.instance.getAiSettings();
      final speechRate =
          settings?.speechRate ?? AppConstants.systemTtsDefaultSpeed;
      await _flutterTts.setSpeechRate(speechRate);
      debugPrint('设置系统TTS语速: ${(speechRate * 100).toInt()}% ($speechRate)');

      await _flutterTts.setVolume(1.0);

      await _flutterTts.setPitch(1.0);

      debugPrint('设置语音参数完成');

      _flutterTts.setStartHandler(() {
        debugPrint('开始播放');
        _isSpeaking = true;
        _stateController.add(TtsPlaybackState(
            phase: TtsPlaybackPhase.playing, text: _currentText));
      });

      _flutterTts.setCompletionHandler(() {
        debugPrint('播放完成');
        _isSpeaking = false;
        _currentText = null;
        _speakCompleter?.complete();
        _speakCompleter = null;
        onPlayingComplete?.call();
        _stateController
            .add(const TtsPlaybackState(phase: TtsPlaybackPhase.completed));
      });

      _flutterTts.setCancelHandler(() {
        debugPrint('播放取消');
        _isSpeaking = false;
        _currentText = null;
        _speakCompleter?.complete();
        _speakCompleter = null;
      });

      _flutterTts.setErrorHandler((message) {
        debugPrint('播放错误: $message');
        _isSpeaking = false;
        _currentText = null;
        _speakCompleter?.completeError(Exception(message));
        _speakCompleter = null;
        _stateController.add(TtsPlaybackState(
            phase: TtsPlaybackPhase.error, text: null, error: message));
      });
    } else {
      debugPrint('桌面平台，跳过FlutterTTS初始化');
    }

    _audioPlayer.onPlayerComplete.listen((event) {
      debugPrint('音频播放完成');
      _isSpeaking = false;
      _currentText = null;
      _speakCompleter?.complete();
      _speakCompleter = null;
      _cleanupAudioFile();
      onPlayingComplete?.call();
      _stateController
          .add(const TtsPlaybackState(phase: TtsPlaybackPhase.completed));
    });

    _audioPlayer.onLog.listen((message) {
      debugPrint('AudioPlayer log: $message');
    });

    _isInitialized = true;
    debugPrint('TTS初始化完成');
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      debugPrint('TTS未初始化，开始初始化');
      await initialize();
    }

    AppLog.content('准备播放: $text');

    if (_isSpeaking) {
      debugPrint('停止当前播放');
      await stop();
    }

    _currentText = text;
    _speakCompleter = Completer<void>();
    _stateController
        .add(TtsPlaybackState(phase: TtsPlaybackPhase.loading, text: text));

    final settings = StorageService.instance.getAiSettings();
    final ttsEngine = settings?.ttsEngine ?? 'system';
    final speechRate =
        settings?.speechRate ?? AppConstants.systemTtsDefaultSpeed;

    debugPrint('TTS引擎: $ttsEngine, 语速: $speechRate');

    if (ttsEngine == 'supertonic') {
      if (!PlatformUtils.supportsSupertonic) {
        debugPrint('Supertonic不支持当前平台，回退到系统TTS');
        await _speakWithFlutterTts(text);
        await _speakCompleter?.future;
        return;
      }

      final hasModels = await SupertonicModelService.instance.hasAllModels();
      if (!hasModels) {
        debugPrint('Supertonic模型未下载，回退到系统TTS');
        await _speakWithFlutterTts(text);
        await _speakCompleter?.future;
        return;
      }

      try {
        final voice =
            settings?.supertonicVoice ?? AppConstants.supertonicDefaultVoice;
        final steps =
            settings?.supertonicSteps ?? AppConstants.supertonicDefaultSteps;
        final lang = AppConstants.supertonicDefaultLang;
        await _speakWithSupertonic(text, lang, voice, steps, speechRate);
        await _speakCompleter?.future;
      } catch (e) {
        debugPrint('Supertonic播放错误: $e，回退到系统TTS');
        _speakCompleter = Completer<void>();
        await _speakWithFlutterTts(text);
        await _speakCompleter?.future;
      }
    } else {
      if (PlatformUtils.supportsSystemTts) {
        await _flutterTts.setSpeechRate(speechRate.clamp(
            AppConstants.systemTtsMinSpeed, AppConstants.systemTtsMaxSpeed));
        debugPrint('动态更新系统TTS语速: ${(speechRate * 100).toInt()}% ($speechRate)');
      }
      await _speakWithFlutterTts(text);
      await _speakCompleter?.future;
    }
  }

  Future<void> _speakWithFlutterTts(String text) async {
    if (!PlatformUtils.supportsSystemTts) {
      debugPrint('桌面平台不支持系统TTS');
      return;
    }
    debugPrint('使用Flutter TTS播放');
    try {
      await _flutterTts.speak(text);
      debugPrint('Flutter TTS speak方法调用成功');
    } catch (e) {
      debugPrint('Flutter TTS播放错误: $e');
      _isSpeaking = false;
      _currentText = null;
    }
  }

  Future<void> _speakWithSupertonic(
    String text,
    String lang,
    String voice,
    int steps,
    double speed,
  ) async {
    debugPrint('使用Supertonic播放: voice=$voice, steps=$steps, speed=$speed');

    _isLoading = true;
    _stateController.add(
        TtsPlaybackState(phase: TtsPlaybackPhase.loading, text: _currentText));
    onLoadingStarted?.call();

    try {
      final cachedPath = await TtsCacheService.instance
          .getCachedSupertonicAudio(text, voice, steps, speed);

      String? audioPath;

      if (cachedPath != null) {
        audioPath = cachedPath;
        _isLoading = false;
        debugPrint('使用缓存，跳过合成');
      } else {
        audioPath = await SupertonicService.instance.synthesize(
          text,
          lang,
          voice,
          steps,
          speed,
        );

        _isLoading = false;

        if (audioPath != null) {
          final cachePath = await TtsCacheService.instance
              .saveSupertonicToCache(audioPath, text, voice, steps, speed);
          audioPath = cachePath;
          debugPrint('音频已保存到缓存');
        }
      }

      if (audioPath != null) {
        _isSpeaking = true;
        onPlayingStarted?.call();
        _stateController.add(TtsPlaybackState(
            phase: TtsPlaybackPhase.playing, text: _currentText));
        await _audioPlayer.play(DeviceFileSource(audioPath));
        debugPrint('Supertonic开始播放');
      } else {
        debugPrint('Supertonic合成失败，回退到Flutter TTS');
        await _speakWithFlutterTts(text);
      }
    } catch (e) {
      _isLoading = false;
      debugPrint('Supertonic播放错误: $e');
      throw Exception('Supertonic合成失败: $e');
    }
  }

  Future<void> stop() async {
    if (_isSpeaking || _isLoading) {
      if (PlatformUtils.supportsSystemTts) {
        await _flutterTts.stop();
      }
      await _audioPlayer.stop();
      _isSpeaking = false;
      _isLoading = false;
      _currentText = null;
      _speakCompleter?.complete();
      _speakCompleter = null;
      await _cleanupAudioFile();
    }
  }

  Future<void> _cleanupAudioFile() async {}

  bool get isSpeaking => _isSpeaking;
  bool get isLoading => _isLoading;
  String? get currentText => _currentText;

  Future<void> setSpeechRate(double rate) async {
    if (PlatformUtils.supportsSystemTts) {
      await _flutterTts.setSpeechRate(rate.clamp(0.0, 1.0));
    }
  }

  Future<void> setVolume(double volume) async {
    if (PlatformUtils.supportsSystemTts) {
      await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
    }
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> setPitch(double pitch) async {
    if (PlatformUtils.supportsSystemTts) {
      await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
    }
  }

  Future<List<String>> getAvailableLanguages() async {
    if (!PlatformUtils.supportsSystemTts) return [];
    final languages = await _flutterTts.getLanguages;
    return languages.cast<String>();
  }

  Future<void> setLanguage(String language) async {
    if (PlatformUtils.supportsSystemTts) {
      await _flutterTts.setLanguage(language);
    }
  }

  void dispose() {
    if (PlatformUtils.supportsSystemTts) {
      _flutterTts.stop();
    }
    _audioPlayer.dispose();
    _cleanupAudioFile();
    _isInitialized = false;
    _isSpeaking = false;
    _isLoading = false;
    _currentText = null;
    _speakCompleter?.complete();
    _speakCompleter = null;
    _stateController.close();
    onLoadingStarted = null;
    onPlayingStarted = null;
    onPlayingComplete = null;
    _flutterTts = FlutterTts();
    _audioPlayer = AudioPlayer();
  }
}
