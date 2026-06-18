import '../../core/utils/ai_block_helper.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/image_service.dart';
import '../../data/services/storage_service.dart';

class TextBlockAiResult {
  final bool changed;
  final bool isError;
  final String? text;
  final String? message;

  const TextBlockAiResult({
    required this.changed,
    this.isError = false,
    this.text,
    this.message,
  });
}

class TextBlockAiUseCase {
  Future<bool> checkApiKey() async {
    return await AiService.instance.hasApiKey();
  }

  Future<TextBlockAiResult> enhanceTextBlock({
    required String bookId,
    required int pageIndex,
    required int blockIndex,
  }) async {
    final book = StorageService.instance.getBook(bookId);
    if (book == null) {
      return const TextBlockAiResult(changed: false, message: '书籍不存在');
    }

    if (pageIndex < 0 || pageIndex >= book.pages.length) {
      return const TextBlockAiResult(changed: false, message: '页面不存在');
    }

    final page = book.pages[pageIndex];
    if (blockIndex < 0 || blockIndex >= page.textBlocks.length) {
      return const TextBlockAiResult(changed: false, message: '文字块不存在');
    }

    final block = page.textBlocks[blockIndex];
    final imageFile = ImageService.instance.getImageFile(page.imagePath);
    if (imageFile == null || !imageFile.existsSync()) {
      return const TextBlockAiResult(changed: false, message: '图片文件不存在');
    }

    final model = AiService.instance.getSelectedModel();

    try {
      final corrected = await AiBlockHelper.enhance(
        imageFile: imageFile,
        blocks: [
          {0: block.text}
        ],
        model: model,
      );

      if (corrected[0] != null && corrected[0] != block.text) {
        return TextBlockAiResult(changed: true, text: corrected[0]);
      }
      return const TextBlockAiResult(changed: false, message: '无需修改');
    } catch (e) {
      return TextBlockAiResult(
        changed: false,
        isError: true,
        message: 'AI 优化失败: $e',
      );
    }
  }

  Future<TextBlockAiResult> translateTextBlock({
    required String bookId,
    required int pageIndex,
    required int blockIndex,
  }) async {
    final book = StorageService.instance.getBook(bookId);
    if (book == null) {
      return const TextBlockAiResult(changed: false, message: '书籍不存在');
    }

    if (pageIndex < 0 || pageIndex >= book.pages.length) {
      return const TextBlockAiResult(changed: false, message: '页面不存在');
    }

    final page = book.pages[pageIndex];
    if (blockIndex < 0 || blockIndex >= page.textBlocks.length) {
      return const TextBlockAiResult(changed: false, message: '文字块不存在');
    }

    final block = page.textBlocks[blockIndex];
    final imageFile = ImageService.instance.getImageFile(page.imagePath);
    if (imageFile == null || !imageFile.existsSync()) {
      return const TextBlockAiResult(changed: false, message: '图片文件不存在');
    }

    final model = AiService.instance.getSelectedModel();

    try {
      final result = await AiBlockHelper.translate(
        imageFile: imageFile,
        blocks: [
          {0: block.text}
        ],
        model: model,
      );

      if (result[0] != null && result[0]!.isNotEmpty) {
        return TextBlockAiResult(changed: true, text: result[0]);
      }
      return const TextBlockAiResult(changed: false, message: 'AI 翻译无结果');
    } catch (e) {
      return TextBlockAiResult(
        changed: false,
        isError: true,
        message: 'AI 翻译失败: $e',
      );
    }
  }
}
