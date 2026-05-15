import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/book_repository_impl.dart';
import '../../data/repositories/service_repositories.dart';
import '../../data/repositories/service_repositories_impl.dart';
import 'service_providers.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepositoryImpl(
    ref.read(storageServiceProvider),
    ref.read(imageServiceProvider),
    ref.read(bookServiceProvider),
  );
});

final ocrRepositoryProvider = Provider<OcrRepository>((ref) {
  return OcrRepositoryImpl(ref.read(ocrServiceProvider));
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepositoryImpl(ref.read(aiServiceProvider));
});

final ttsRepositoryProvider = Provider<TtsRepository>((ref) {
  return TtsRepositoryImpl(ref.read(ttsServiceProvider));
});

final imageRepositoryProvider = Provider<ImageRepository>((ref) {
  return ImageRepositoryImpl(ref.read(imageServiceProvider));
});
