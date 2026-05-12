import 'dart:io';
import '../repositories/service_repositories.dart';
import '../services/ocr_service.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/image_service.dart';
import '../models/text_block_model.dart';

class OcrRepositoryImpl implements OcrRepository {
  final OcrService _ocrService;
  
  OcrRepositoryImpl(this._ocrService);
  
  @override
  Future<List<TextBlockModel>?> recognizeText(File imageFile) async {
    final result = await _ocrService.recognizeText(imageFile);
    if (result == null) return null;
    
    return result.blocks.map((block) {
      return TextBlockModel.fromData(
        boundingBox: block.boundingBox,
        text: block.text,
        isDeleted: false,
      );
    }).toList();
  }
}

class AiRepositoryImpl implements AiRepository {
  final AiService _aiService;
  
  AiRepositoryImpl(this._aiService);
  
  @override
  Future<String?> getApiKey() async {
    return await _aiService.getApiKey();
  }
  
  @override
  Future<void> saveApiKey(String apiKey) async {
    await _aiService.saveApiKey(apiKey);
  }
  
  @override
  Future<void> deleteApiKey() async {
    await _aiService.deleteApiKey();
  }
  
  @override
  Future<bool> hasApiKey() async {
    return await _aiService.hasApiKey();
  }
  
  @override
  String getSelectedModel() {
    return _aiService.getSelectedModel();
  }
  
  @override
  String getTtsVoice() {
    return _aiService.getTtsVoice();
  }
  
  @override
  Future<bool> testConnection(String apiKey, String model) async {
    return await _aiService.testConnection(apiKey, model);
  }
  
  @override
  Future<String?> synthesizeSpeech(
    String text,
    String voice,
    double speechRate,
  ) async {
    return await _aiService.synthesizeSpeech(
      text,
      voice: voice,
      speechRate: speechRate,
    );
  }
  
  @override
  Future<Map<int, String>> enhanceTextBlocks(
    File imageFile,
    List<Map<int, String>> blocks,
    String model,
  ) async {
    return await _aiService.enhanceTextBlocks(imageFile, blocks, model);
  }
}

class TtsRepositoryImpl implements TtsRepository {
  final TtsService _ttsService;
  
  TtsRepositoryImpl(this._ttsService);
  
  @override
  Future<void> initialize() async {
    await _ttsService.initialize();
  }
  
  @override
  Future<void> speak(String text) async {
    await _ttsService.speak(text);
  }
  
  @override
  Future<void> stop() async {
    await _ttsService.stop();
  }
  
  @override
  bool get isSpeaking => _ttsService.isSpeaking;
  
  @override
  String? get currentText => _ttsService.currentText;
  
  @override
  Future<void> setSpeechRate(double rate) async {
    await _ttsService.setSpeechRate(rate);
  }
  
  @override
  Future<void> setVolume(double volume) async {
    await _ttsService.setVolume(volume);
  }
  
  @override
  Future<void> setPitch(double pitch) async {
    await _ttsService.setPitch(pitch);
  }
  
  @override
  Future<List<String>> getAvailableLanguages() async {
    return await _ttsService.getAvailableLanguages();
  }
  
  @override
  Future<void> setLanguage(String language) async {
    await _ttsService.setLanguage(language);
  }
  
  @override
  void dispose() {
    _ttsService.dispose();
  }
}

class ImageRepositoryImpl implements ImageRepository {
  final ImageService _imageService;
  
  ImageRepositoryImpl(this._imageService);
  
  @override
  Future<void> initialize() async {
    await _imageService.initialize();
  }
  
  @override
  Future<String> saveImage(File imageFile, String bookId, String pageId) async {
    return await _imageService.saveImage(imageFile, bookId, pageId);
  }
  
  @override
  File? getImageFile(String imagePath) {
    return _imageService.getImageFile(imagePath);
  }
  
  @override
  Future<void> deleteImage(String imagePath) async {
    await _imageService.deleteImage(imagePath);
  }
  
  @override
  Future<void> deleteBookDirectory(String bookId) async {
    await _imageService.deleteBookDirectory(bookId);
  }
}