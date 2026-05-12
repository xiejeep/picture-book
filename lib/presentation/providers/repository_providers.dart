import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/book_repository_impl.dart';
import '../../data/repositories/service_repositories.dart';
import '../../data/repositories/service_repositories_impl.dart';
import 'service_providers.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepositoryImpl(
    ref.watch(storageServiceProvider),
    ref.watch(imageServiceProvider),
    ref.watch(bookServiceProvider),
  );
});

final ocrRepositoryProvider = Provider<OcrRepository>((ref) {
  return OcrRepositoryImpl(ref.watch(ocrServiceProvider));
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepositoryImpl(ref.watch(aiServiceProvider));
});

final ttsRepositoryProvider = Provider<TtsRepository>((ref) {
  return TtsRepositoryImpl(ref.watch(ttsServiceProvider));
});

final imageRepositoryProvider = Provider<ImageRepository>((ref) {
  return ImageRepositoryImpl(ref.watch(imageServiceProvider));
});