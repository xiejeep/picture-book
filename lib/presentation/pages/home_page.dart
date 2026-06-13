import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/book_model.dart';
import '../../data/models/text_block_model.dart';
import '../../data/services/import_export_service.dart';
import '../../data/services/file_intent_service.dart';
import '../providers/books_provider.dart';
import '../widgets/book_card.dart';
import '../../core/utils/toast_util.dart';
import '../../core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'book_editor/book_editor_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    FileIntentService.register((path) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _importFile(File(path));
        }
      });
    });
  }

  @override
  void dispose() {
    FileIntentService.unregister();
    super.dispose();
  }

  Future<void> _createNewBook() async {
    final title = await _showCreateBookDialog();
    if (title == null) return;

    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile == null) return;
    if (!mounted) return;

    final imageFile = File(pickedFile.path);
    final result = await Navigator.push<List<TextBlockModel>>(
      context,
      MaterialPageRoute(
        builder: (_) => BookEditorPage(
          bookId: '',
          pageIndex: 0,
          imageFile: imageFile,
          initialBlocks: const [],
        ),
      ),
    );

    if (result != null && mounted) {
      final book =
          await ref.read(booksProvider.notifier).createBook(title);
      if (!mounted) return;
      await ref.read(booksProvider.notifier).addPageToBook(
            book.id,
            imageFile,
            result,
          );
      if (mounted) Navigator.pop(context);
    }
  }

  Future<String?> _showCreateBookDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '创建新读本',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceOf(context),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: '读本名称',
                  hintText: '给读本起个名字',
                  prefixIcon: Icon(
                    Icons.edit_note_rounded,
                    color: AppTheme.primaryOf(context).withValues(alpha: 0.7),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '取消',
                      style: TextStyle(
                          color: AppTheme.onSurfaceOf(context)
                              .withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: const Text('创建'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBook(BookModel book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorOf(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.delete_rounded,
                  size: 32,
                  color: AppTheme.errorOf(context),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '删除读本',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceOf(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '确定删除 "${book.title}" 吗？',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.errorOf(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '包含 ${book.pageCount} 个页面',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.errorOf(context),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      '取消',
                      style: TextStyle(
                          color: AppTheme.onSurfaceOf(context)
                              .withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorOf(context),
                    ),
                    child: const Text('删除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await ref.read(booksProvider.notifier).deleteBook(book.id);
      ToastUtil.show('已删除 "${book.title}"');
    }
  }

  void _openBook(BookModel book) {
    context.push('/book/${book.id}', extra: book).then((_) {
      ref.read(booksProvider.notifier).refresh();
    });
  }

  void _showModeSelection(BookModel book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.mutedOf(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accentOf(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: AppTheme.accentOf(context),
                  ),
                ),
                title: const Text('编辑'),
                subtitle: const Text('修改文字块、AI强化识别'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openBookInEditMode(book);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOf(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.file_upload_rounded,
                    color: AppTheme.primaryOf(context),
                  ),
                ),
                title: const Text('分享'),
                subtitle: Text('分享 "${book.title}"'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _exportBook(book);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryOf(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.save_alt_rounded,
                    color: AppTheme.secondaryOf(context),
                  ),
                ),
                title: const Text('保存到手机'),
                subtitle: Text('保存 "${book.title}" 到下载目录'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _saveBookToPhone(book);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.errorOf(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.delete_rounded,
                    color: AppTheme.errorOf(context),
                  ),
                ),
                title: const Text('删除读本'),
                subtitle: Text('删除 "${book.title}"'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteBook(book);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openBookInEditMode(BookModel book) {
    context.push('/book/${book.id}/manage', extra: book).then((_) {
      ref.read(booksProvider.notifier).refresh();
    });
  }

  void _openSettings() {
    context.push('/settings');
  }

  Future<void> _importBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    final ext = path.split('.').last.toLowerCase();
    if (ext != 'ddb' && ext != 'zip') {
      ToastUtil.error('仅支持 .ddb 或 .zip 格式的导入文件');
      return;
    }

    await _importFile(File(path));
  }

  Future<void> _importFile(File file) async {
    try {
      final metadata = await ImportExportService.instance.parseMetadata(file);
      if (!mounted) return;
      if (metadata == null) {
        ToastUtil.error('无效的导入文件');
        return;
      }

      final title = ImportExportService.instance.getTitleFromMetadata(metadata);
      if (title == null) {
        ToastUtil.error('无效的导入文件：缺少书名');
        return;
      }

      String? overrideTitle;

      if (ImportExportService.instance.hasTitleConflict(title)) {
        final choice = await _showImportConflictDialog(title);
        if (!mounted) return;
        if (choice == null) return;

        if (choice) {
          final books = ref.read(booksProvider).books;
          final conflicting = books.where((b) => b.title == title).toList();
          for (final b in conflicting) {
            await ref.read(booksProvider.notifier).deleteBook(b.id);
            if (!mounted) return;
          }
        } else {
          overrideTitle = '$title (导入)';
        }
      } else {
        final confirmed = await _showImportConfirmDialog(title);
        if (!mounted) return;
        if (confirmed != true) return;
      }

      final book = await ImportExportService.instance
          .importBook(file, overrideTitle: overrideTitle);
      if (!mounted) return;
      ref.read(booksProvider.notifier).refresh();
      ToastUtil.success('"${book.title}" 导入成功');
    } catch (e) {
      if (!mounted) return;
      ToastUtil.error('导入失败: $e');
    }
  }

  Future<void> _exportBook(BookModel book) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    try {
      final exportFile = await ImportExportService.instance.exportBook(book);
      await Share.shareXFiles(
        [XFile(exportFile.path)],
        subject: book.title,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      ToastUtil.error('导出失败: $e');
    }
  }

  Future<void> _saveBookToPhone(BookModel book) async {
    try {
      final exportFile = await ImportExportService.instance.exportBook(book);
      final bytes = await exportFile.readAsBytes();
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存读本',
        fileName: '${book.title}.ddb',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['ddb'],
      );
      if (result != null) {
        ToastUtil.success('保存成功');
      }
    } catch (e) {
      ToastUtil.error('保存失败: $e');
    }
  }

  Future<bool?> _showImportConflictDialog(String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentOf(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 32,
                  color: AppTheme.accentOf(context),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '导入冲突',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceOf(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '读本"$title"已存在，如何处理？',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      '保留两者',
                      style: TextStyle(
                        color: AppTheme.onSurfaceOf(context)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorOf(context),
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    child: const Text('覆盖已有读本'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showImportConfirmDialog(String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOf(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.file_open_rounded,
                  size: 32,
                  color: AppTheme.primaryOf(context),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '导入读本',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceOf(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '确定导入 "$title" 吗？',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: AppTheme.onSurfaceOf(context)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text('导入'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booksState = ref.watch(booksProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 22,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
            const Text('我的读本'),
          ],
        ),
        actions: [
          Semantics(
            label: '导入读本',
            hint: '从文件导入读本',
            button: true,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.file_open_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              onPressed: _importBook,
              tooltip: '导入读本',
            ),
          ),
          Semantics(
            label: '设置',
            hint: '打开应用设置页面',
            button: true,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              onPressed: _openSettings,
              tooltip: '设置',
            ),
          ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.appBarGradientOf(context),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.gradientBoxOf(context),
        child: SafeArea(
          left: false,
          right: false,
          child: booksState.isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: AppTheme.primaryOf(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '正在加载...',
                        style: TextStyle(
                          color: AppTheme.onSurfaceOf(context)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : booksState.books.isEmpty
                  ? _buildEmptyState()
                  : _buildBooksGrid(booksState.books),
        ),
      ),
      floatingActionButton: booksState.books.isEmpty
          ? null
          : Semantics(
              label: '创建新读本',
              hint: '点击创建一个新的读本',
              button: true,
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: _createNewBook,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppTheme.appBarGradientOf(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppTheme.primaryOf(context).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.calmBlue.withValues(alpha: 0.2),
                  AppTheme.gentleGreen.withValues(alpha: 0.2),
                  AppTheme.sweetPink.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              size: 64,
              color: AppTheme.primaryOf(context).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '还没有读本',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceOf(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '创建一个读本，开始互动阅读吧！',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createNewBook,
            icon: const Icon(Icons.add_rounded),
            label: const Text('创建第一个读本'),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksGrid(List<BookModel> books) {
    const double largeScreenMinWidth = 600.0;
    const double maxCardWidth = 200.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > largeScreenMinWidth;
        final crossAxisCount = isLargeScreen
            ? (constraints.maxWidth / maxCardWidth).floor().clamp(2, 6)
            : 2;
        final childAspectRatio = isLargeScreen ? 0.75 : 0.75;

        return GridView.builder(
          padding: EdgeInsets.only(
            left: MediaQuery.of(context).padding.left + 20,
            right: MediaQuery.of(context).padding.right + 20,
            top: 20,
            bottom: 80,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return BookCard(
              book: book,
              onTap: () => _openBook(book),
              onLongPress: () => _showModeSelection(book),
            );
          },
        );
      },
    );
  }
}
