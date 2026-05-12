import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'ai_service.dart';
import 'tts_cache_service.dart';
import 'storage_service.dart';
import '../../core/constants/constants.dart';

class GlmTtsException implements Exception {
  final int statusCode;
  final String message;

  GlmTtsException(this.statusCode, this.message);

  bool isBalanceInsufficient() => statusCode == 429;

  String get userMessage {
    if (isBalanceInsufficient()) {
      return 'GLM-TTS余额不足，已切换为系统语音';
    }
    return 'GLM-TTS播放失败: $message';
  }
}

class TtsService {
  static final TtsService _instance = TtsService._internal();
  static TtsService get instance => _instance;
  TtsService._internal();

  FlutterTts _flutterTts = FlutterTts();
  AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String? _currentText;

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('TTS已初始化');
      return;
    }

    debugPrint('开始初始化TTS');
    
    await TtsCacheService.instance.initialize();
    
    await _flutterTts.setSharedInstance(true);
    debugPrint('设置SharedInstance完成');
    
    await _flutterTts.setLanguage('en-US');
    debugPrint('设置语言完成');
    
    final settings = StorageService.instance.getAiSettings();
    final speechRate = settings?.speechRate ?? AppConstants.systemTtsDefaultSpeed;
    await _flutterTts.setSpeechRate(speechRate);
    debugPrint('设置系统TTS语速: ${(speechRate * 100).toInt()}% ($speechRate)');
    
    await _flutterTts.setVolume(1.0);
    
    await _flutterTts.setPitch(1.0);
    
    debugPrint('设置语音参数完成');
    
    _flutterTts.setStartHandler(() {
      debugPrint('开始播放');
      _isSpeaking = true;
    });
    
    _flutterTts.setCompletionHandler(() {
      debugPrint('播放完成');
      _isSpeaking = false;
      _currentText = null;
    });
    
    _flutterTts.setCancelHandler(() {
      debugPrint('播放取消');
      _isSpeaking = false;
      _currentText = null;
    });
    
    _flutterTts.setErrorHandler((message) {
      debugPrint('播放错误: $message');
      _isSpeaking = false;
      _currentText = null;
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      debugPrint('GLM-TTS播放完成');
      _isSpeaking = false;
      _currentText = null;
      _cleanupAudioFile();
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

    debugPrint('准备播放: $text');
    
    if (_isSpeaking) {
      debugPrint('停止当前播放');
      await stop();
    }

    _currentText = text;
    
    final settings = StorageService.instance.getAiSettings();
    final speechRate = settings?.speechRate ?? AppConstants.systemTtsDefaultSpeed;
    await _flutterTts.setSpeechRate(speechRate);
    debugPrint('动态更新系统TTS语速: ${(speechRate * 100).toInt()}% ($speechRate)');

    if (settings?.useGlmTts ?? false) {
      try {
        await _speakWithGlmTts(text, speechRate);
      } catch (e) {
        if (e is GlmTtsException) {
          debugPrint('GLM-TTS失败，自动回退到Flutter TTS');
          await _speakWithFlutterTts(text);
          rethrow;
        }
        debugPrint('GLM-TTS播放错误: $e，回退到Flutter TTS');
        await _speakWithFlutterTts(text);
      }
    } else {
      await _speakWithFlutterTts(text);
    }
  }

  Future<void> _speakWithFlutterTts(String text) async {
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

  Future<void> _speakWithGlmTts(String text, double speechRate) async {
    debugPrint('使用GLM-TTS播放');
    try {
      final audioPath = await AiService.instance.synthesizeSpeech(
        text,
        speechRate: speechRate,
      );
      if (audioPath != null) {
        _isSpeaking = true;
        await _audioPlayer.play(DeviceFileSource(audioPath));
        debugPrint('GLM-TTS开始播放');
      } else {
        debugPrint('GLM-TTS合成失败，回退到Flutter TTS');
        await _speakWithFlutterTts(text);
      }
    } catch (e) {
      final statusCode = _extractStatusCode(e);
      final errorMsg = _extractErrorMessage(e);
      
      debugPrint('GLM-TTS播放错误: statusCode=$statusCode, error=$errorMsg');
      
      throw GlmTtsException(statusCode, errorMsg);
    }
  }

  int _extractStatusCode(dynamic error) {
    if (error is Exception) {
      final message = error.toString();
      final match = RegExp(r'statusCode:\s*(\d+)').firstMatch(message);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
      final statusMatch = RegExp(r'failed:\s*(\d+)').firstMatch(message);
      if (statusMatch != null) {
        return int.parse(statusMatch.group(1)!);
      }
    }
    return -1;
  }

  String _extractErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString();
    }
    return 'Unknown error';
  }

  Future<void> stop() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      await _audioPlayer.stop();
      _isSpeaking = false;
      _currentText = null;
      await _cleanupAudioFile();
    }
  }

  Future<void> _cleanupAudioFile() async {
  }

  bool get isSpeaking => _isSpeaking;
  String? get currentText => _currentText;

  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
  }

  Future<List<String>> getAvailableLanguages() async {
    final languages = await _flutterTts.getLanguages;
    return languages.cast<String>();
  }

  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  void dispose() {
    _flutterTts.stop();
    _audioPlayer.dispose();
    _cleanupAudioFile();
    _isInitialized = false;
    _isSpeaking = false;
    _currentText = null;
    _flutterTts = FlutterTts();
    _audioPlayer = AudioPlayer();
  }
}