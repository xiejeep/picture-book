import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/reading/play_text_block_use_case.dart';
import '../../application/reading/translate_text_block_use_case.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/image_service.dart';
import '../../data/services/book_service.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/translation_service.dart';
import '../../data/services/nfc_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

final imageServiceProvider = Provider<ImageService>((ref) {
  return ImageService.instance;
});

final bookServiceProvider = Provider<BookService>((ref) {
  return BookService.instance;
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService.instance;
});

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService.instance;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService.instance;
});

final playTextBlockUseCaseProvider = Provider<PlayTextBlockUseCase>((ref) {
  return PlayTextBlockUseCase(ref.watch(ttsServiceProvider));
});

final ttsStateProvider = StreamProvider<TtsPlaybackState>((ref) {
  return TtsService.instance.stateStream;
});

final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService.instance;
});

final translateTextBlockUseCaseProvider =
    Provider<TranslateTextBlockUseCase>((ref) {
  return TranslateTextBlockUseCase(ref.watch(translationServiceProvider));
});

final nfcServiceProvider = Provider<NfcService>((ref) {
  return NfcService.instance;
});
