import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/book_model.dart';
import '../models/page_model.dart';
import '../models/text_block_model.dart';
import 'storage_service.dart';
import 'image_service.dart';
import '../../core/constants/constants.dart';

class ImportExportService {
  static final ImportExportService _instance = ImportExportService._internal();
  static ImportExportService get instance => _instance;
  ImportExportService._internal();

  final _uuid = const Uuid();

  Future<File> exportBook(BookModel book) async {
    final archive = Archive();

    final metadata = _buildExportMetadata(book);
    final metadataBytes = utf8.encode(jsonEncode(metadata));
    archive.addFile(
        ArchiveFile('metadata.json', metadataBytes.length, metadataBytes));

    for (final page in book.pages) {
      final imageFile = ImageService.instance.getImageFile(page.imagePath);
      if (imageFile != null) {
        final filename = page.imagePath.split('/').last;
        final bytes = await imageFile.readAsBytes();
        archive.addFile(ArchiveFile(filename, bytes.length, bytes));
      }
    }

    if (book.customCoverPath != null) {
      final coverFile =
          ImageService.instance.getImageFile(book.customCoverPath!);
      if (coverFile != null) {
        final filename = 'cover${_extensionOf(book.customCoverPath!)}';
        final bytes = await coverFile.readAsBytes();
        archive.addFile(ArchiveFile(filename, bytes.length, bytes));
      }
    }

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) throw Exception('导出失败：压缩数据为空');
    final tempDir = await getTemporaryDirectory();
    final safeTitle = _sanitizeFilename(book.title);
    final exportPath = '${tempDir.path}/$safeTitle.ddb';
    final exportFile = File(exportPath);
    await exportFile.writeAsBytes(zipData);

    return exportFile;
  }

  Future<Map<String, dynamic>?> parseMetadata(File zipFile) async {
    try {
      final file = await _findMetadataInZip(zipFile);
      if (file == null) return null;
      final bytes = _contentOf(file);
      if (bytes == null) return null;
      final content = utf8.decode(bytes);
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String? getTitleFromMetadata(Map<String, dynamic> metadata) {
    final bookData = metadata['book'] as Map<String, dynamic>?;
    return bookData?['title'] as String?;
  }

  bool hasTitleConflict(String title) {
    final books = StorageService.instance.getAllBooks();
    return books.any((b) => b.title == title);
  }

  Future<BookModel> importBook(File zipFile, {String? overrideTitle}) async {
    final archiveBytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(archiveBytes);

    final metadataFile = _findMetadataInArchive(archive);
    if (metadataFile == null) {
      throw Exception('无效的导出文件：缺少metadata.json');
    }
    final metadataBytes = _contentOf(metadataFile);
    if (metadataBytes == null) {
      throw Exception('无效的导出文件：metadata.json为空');
    }

    final content = utf8.decode(metadataBytes);
    final metadata = jsonDecode(content) as Map<String, dynamic>;
    final bookData = metadata['book'] as Map<String, dynamic>;

    if (bookData['title'] == null) {
      throw Exception('无效的导出文件：缺少书名');
    }

    final newBookId = _uuid.v4();
    final title = overrideTitle ?? bookData['title'] as String;

    final bookDir = Directory(
        '${ImageService.instance.appPath}/${AppConstants.booksDirectoryName}/$newBookId');
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }

    final pages = <PageModel>[];
    final pagesData = bookData['pages'] as List<dynamic>? ?? [];

    for (final pageData in pagesData) {
      final pageMap = pageData as Map<String, dynamic>;
      final newPageId = _uuid.v4();
      final imageFilename = pageMap['imageFile'] as String?;

      String? newImagePath;
      if (imageFilename != null) {
        final imageEntry = _findFile(archive, imageFilename);
        final imgBytes = _contentOf(imageEntry);
        if (imgBytes != null) {
          final extension = _extensionOf(imageFilename);
          final newFilename = '$newPageId$extension';
          final destPath = '${bookDir.path}/$newFilename';
          await File(destPath).writeAsBytes(imgBytes);
          newImagePath =
              '${AppConstants.booksDirectoryName}/$newBookId/$newFilename';
        }
      }

      final textBlocks = <TextBlockModel>[];
      final blocksData = pageMap['textBlocks'] as List<dynamic>? ?? [];

      for (final blockData in blocksData) {
        final blockMap = blockData as Map<String, dynamic>;
        textBlocks.add(TextBlockModel(
          left: (blockMap['left'] as num).toDouble(),
          top: (blockMap['top'] as num).toDouble(),
          right: (blockMap['right'] as num).toDouble(),
          bottom: (blockMap['bottom'] as num).toDouble(),
          text: blockMap['text'] as String,
          isDeleted: blockMap['isDeleted'] as bool? ?? false,
          translatedText: blockMap['translatedText'] as String?,
          aiTranslatedText: blockMap['aiTranslatedText'] as String?,
          originalText: blockMap['originalText'] as String?,
          aiEnhancedText: blockMap['aiEnhancedText'] as String?,
        ));
      }

      pages.add(PageModel(
        id: newPageId,
        imagePath: newImagePath ?? '',
        textBlocks: textBlocks,
        pageIndex: pageMap['pageIndex'] as int? ?? pages.length,
        createdAt: pageMap['createdAt'] != null
            ? DateTime.parse(pageMap['createdAt'] as String)
            : DateTime.now(),
        imageWidth: (pageMap['imageWidth'] as num?)?.toDouble() ?? 0.0,
        imageHeight: (pageMap['imageHeight'] as num?)?.toDouble() ?? 0.0,
      ));
    }

    String? customCoverPath;
    final originalCover = bookData['customCoverPath'] as String?;
    if (originalCover != null) {
      final coverEntry = _findFile(archive, originalCover);
      final coverBytes = _contentOf(coverEntry);
      if (coverBytes != null) {
        final extension = _extensionOf(originalCover);
        final newFilename = 'cover_$newBookId$extension';
        final destPath = '${bookDir.path}/$newFilename';
        await File(destPath).writeAsBytes(coverBytes);
        customCoverPath =
            '${AppConstants.booksDirectoryName}/$newBookId/$newFilename';
      }
    }

    final book = BookModel(
      id: newBookId,
      title: title,
      createdAt: bookData['createdAt'] != null
          ? DateTime.parse(bookData['createdAt'] as String)
          : DateTime.now(),
      updatedAt: bookData['updatedAt'] != null
          ? DateTime.parse(bookData['updatedAt'] as String)
          : DateTime.now(),
      pages: pages,
      currentPageIndex: bookData['currentPageIndex'] as int? ?? 0,
      customCoverPath: customCoverPath,
    );

    await StorageService.instance.saveBook(book);
    return book;
  }

  Map<String, dynamic> _buildExportMetadata(BookModel book) {
    return {
      'version': 1,
      'type': 'dianduya_book',
      'book': {
        'title': book.title,
        'createdAt': book.createdAt.toIso8601String(),
        'updatedAt': book.updatedAt.toIso8601String(),
        'currentPageIndex': book.currentPageIndex,
        'customCoverPath': book.customCoverPath != null
            ? 'cover${_extensionOf(book.customCoverPath!)}'
            : null,
        'pages': book.pages
            .map((page) => {
                  'imageFile': page.imagePath.split('/').last,
                  'pageIndex': page.pageIndex,
                  'createdAt': page.createdAt.toIso8601String(),
                  'imageWidth': page.imageWidth,
                  'imageHeight': page.imageHeight,
                  'textBlocks': page.textBlocks
                      .map((block) => {
                            'left': block.left,
                            'top': block.top,
                            'right': block.right,
                            'bottom': block.bottom,
                            'text': block.text,
                            'isDeleted': block.isDeleted,
                            'translatedText': block.translatedText,
                            'aiTranslatedText': block.aiTranslatedText,
                            'originalText': block.originalText,
                            'aiEnhancedText': block.aiEnhancedText,
                          })
                      .toList(),
                })
            .toList(),
      },
    };
  }

  Future<ArchiveFile?> _findMetadataInZip(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    return _findMetadataInArchive(archive);
  }

  ArchiveFile? _findMetadataInArchive(Archive archive) {
    return _findFile(archive, 'metadata.json');
  }

  ArchiveFile? _findFile(Archive archive, String name) {
    for (final file in archive) {
      if (file.name == name) return file;
    }
    return null;
  }

  List<int>? _contentOf(ArchiveFile? file) {
    return file?.content;
  }

  String _extensionOf(String path) {
    final dotIndex = path.lastIndexOf('.');
    return dotIndex >= 0 ? path.substring(dotIndex) : '.jpg';
  }

  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }
}
