import 'dart:io';
import '../models/text_block_model.dart';

abstract class OcrRepository {
  Future<List<TextBlockModel>?> recognizeText(File imageFile);
}

abstract class AiRepository {
  Future<String?> getApiKey();

  Future<void> saveApiKey(String apiKey);

  Future<void> deleteApiKey();

  Future<bool> hasApiKey();

  String getSelectedModel();

  Future<bool> testConnection(String apiKey, String model);

  Future<Map<int, String>> enhanceTextBlocks(
    File imageFile,
    List<Map<int, String>> blocks,
    String model,
  );
}

abstract class TtsRepository {
  Future<void> initialize();

  Future<void> speak(String text);

  Future<void> stop();

  bool get isSpeaking;

  String? get currentText;

  Future<void> setSpeechRate(double rate);

  Future<void> setVolume(double volume);

  Future<void> setPitch(double pitch);

  Future<List<String>> getAvailableLanguages();

  Future<void> setLanguage(String language);

  void dispose();
}

abstract class ImageRepository {
  Future<void> initialize();

  Future<String> saveImage(File imageFile, String bookId, String pageId);

  File? getImageFile(String imagePath);

  Future<void> deleteImage(String imagePath);

  Future<void> deleteBookDirectory(String bookId);
}
