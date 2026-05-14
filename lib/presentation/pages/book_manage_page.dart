import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../data/models/book_model.dart';
import '../../data/models/page_model.dart';
import '../../data/models/text_block_model.dart';
import '../../data/services/book_service.dart';
import '../../data/services/image_service.dart';
import '../../core/utils/toast_util.dart';
import '../../core/theme/app_theme.dart';
import '../features/text_detection/text_detection.dart';

class BookManagePage extends StatefulWidget {
  final BookModel book;

  const BookManagePage({
    super.key,
    required this.book,
  });

  @override
  State<BookManagePage> createState() => _BookManagePageState();
}

class _BookManagePageState extends State<BookManagePage> {
  late TextEditingController _titleController;
  late List<PageModel> _pages;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book.title);
    _pages = List.from(widget.book.pages);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveTitle() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await BookService.instance.updateBookTitle(widget.book.id, _titleController.text);

      ToastUtil.success('点读本名称已更新');
    } catch (e) {
      ToastUtil.error('保存失败: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deletePage(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFF6B6B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.delete_rounded,
                  size: 32,
                  color: Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '删除页面',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warmBrown,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '确定删除第${index + 1}页吗？',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.warmBrown.withOpacity(0.7),
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
                      style: TextStyle(color: AppTheme.softGray),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF6B6B),
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
      await BookService.instance.removePageFromBook(widget.book.id, index);
      setState(() {
        _pages.removeAt(index);
      });

      ToastUtil.info('页面已删除');
    }
  }

  void _reorderPages(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;

    final page = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, page);

    setState(() {});

    BookService.instance.reorderPages(widget.book.id, oldIndex, newIndex);

    ToastUtil.success('页面顺序已更新');
  }

  Future<void> _editPage(int index) async {
    final page = _pages[index];
    final imageFile = ImageService.instance.getImageFile(page.imagePath);

    if (imageFile == null) {
      ToastUtil.error('图片文件不存在');
      return;
    }

    debugPrint('=== _editPage 开始 ===');
    debugPrint('编辑第${index}页');
    debugPrint('当前页textBlocks数: ${page.textBlocks.length}');
    for (int i = 0; i < page.textBlocks.length; i++) {
      debugPrint('  page.textBlocks[$i]: text="${page.textBlocks[i].text}", isDeleted=${page.textBlocks[i].isDeleted}');
    }

    final initialBlocks = page.textBlocks.map((b) {
      return {
        'boundingBox': b.boundingBox,
        'text': b.text,
        'isDeleted': b.isDeleted,
        'originalText': b.originalText,
        'aiEnhancedText': b.aiEnhancedText,
        'translatedText': b.translatedText,
        'aiTranslatedText': b.aiTranslatedText,
      };
    }).toList();

    debugPrint('传递给TextDetectionPage的initialTextBlocks:');
    for (int i = 0; i < initialBlocks.length; i++) {
      debugPrint('  initial[$i]: ${initialBlocks[i]}');
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => TextDetectionPage(
          initialImageFile: imageFile,
          initialTextBlocks: initialBlocks,
          onSave: (textBlocks, newImageFile) async {
            debugPrint('=== onSave 回调 ===');
            debugPrint('接收的textBlocks数: ${textBlocks.length}');
            for (int i = 0; i < textBlocks.length; i++) {
              final tb = textBlocks[i];
              debugPrint('  接收[$i]: text="${tb.text}", isDeleted=${tb.isDeleted}, rect=${tb.boundingBox}');
            }
            Navigator.pop(context, {
              'textBlocks': textBlocks,
            });
          },
        ),
      ),
    );

    if (result != null) {
      debugPrint('=== 返回结果处理 ===');
      final receivedBlocks = result['textBlocks'] as List;
      debugPrint('result中textBlocks数: ${receivedBlocks.length}');
      for (int i = 0; i < receivedBlocks.length; i++) {
        final block = receivedBlocks[i];
        debugPrint('  result[$i]: text="${block.text}", isDeleted=${block.isDeleted}, rect=${block.boundingBox}');
      }

      final blocks = receivedBlocks.map((block) {
        return TextBlockModel.fromData(
          boundingBox: block.boundingBox,
          text: block.text,
          isDeleted: block.isDeleted ?? false,
          translatedText: block.translatedText,
          aiTranslatedText: block.aiTranslatedText,
          originalText: block.originalText,
          aiEnhancedText: block.aiEnhancedText,
        );
      }).toList();

      debugPrint('转换后的TextBlockModel:');
      for (int i = 0; i < blocks.length; i++) {
        debugPrint('  blocks[$i]: text="${blocks[i].text}", isDeleted=${blocks[i].isDeleted}');
      }

      await BookService.instance.updatePageTextBlocks(widget.book.id, index, blocks);

      setState(() {
        _pages[index] = _pages[index].copyWith(textBlocks: blocks);
      });

      ToastUtil.success('页面已更新');
    }
  }

  Future<void> _addNewPage() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => TextDetectionPage(
          onSave: (textBlocks, imageFile) async {
            Navigator.pop(context, {
              'textBlocks': textBlocks,
              'imageFile': imageFile,
            });
          },
        ),
      ),
    );

    if (result != null) {
      final imageFile = result['imageFile'] as File;
      final blocks = (result['textBlocks'] as List).map((block) {
        return TextBlockModel.fromData(
          boundingBox: block.boundingBox,
          text: block.text,
          isDeleted: block.isDeleted ?? false,
          translatedText: block.translatedText,
          aiTranslatedText: block.aiTranslatedText,
          originalText: block.originalText,
          aiEnhancedText: block.aiEnhancedText,
        );
      }).toList();

      await BookService.instance.addPageToBook(widget.book.id, imageFile, blocks);

      final updatedBook = BookService.instance.getBook(widget.book.id);
      if (updatedBook != null) {
        setState(() {
          _pages = List.from(updatedBook.pages);
        });
      }

      ToastUtil.success('页面已添加');
    }
  }

  Future<void> _editCover() async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.softGray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '选择封面',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.warmBrown,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.calmBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.pages_rounded,
                  color: AppTheme.calmBlue,
                ),
              ),
              title: const Text('使用第一页'),
              subtitle: const Text('默认使用第一页作为封面'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onTap: () => Navigator.pop(context, 'default'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.gentleGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_photo_alternate_rounded,
                  color: AppTheme.gentleGreen,
                ),
              ),
              title: const Text('自定义封面'),
              subtitle: const Text('选择图片作为封面'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onTap: () => Navigator.pop(context, 'custom'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (result == null) return;

    if (result == 'default') {
      await BookService.instance.updateBookCover(widget.book.id, null);
      setState(() {});
      ToastUtil.success('已设置为第一页作为封面');
    } else if (result == 'custom') {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final File imageFile = File(pickedFile.path);
      
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '编辑封面',
            toolbarColor: AppTheme.honeyYellow,
            toolbarWidgetColor: Colors.white,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: '编辑封面',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
            rotateButtonsHidden: false,
            resetButtonHidden: false,
          ),
        ],
      );

      if (croppedFile == null) return;

      final coverPath = await BookService.instance.saveCoverImage(File(croppedFile.path), widget.book.id);
      await BookService.instance.updateBookCover(widget.book.id, coverPath);
      setState(() {});
      ToastUtil.success('封面已更新');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑点读本'),
        actions: [
          const SizedBox(width: 8),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppTheme.honeyYellow,
                AppTheme.softOrange,
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.warmGradientBox,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.playfulShadow,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: '点读本名称',
                                hintText: '输入点读本名称',
                                prefixIcon: Icon(
                                  Icons.edit_note_rounded,
                                  color: AppTheme.primaryColor.withOpacity(0.7),
                                ),
                              ),
                              onSubmitted: (_) => _saveTitle(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Material(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _isSaving ? null : _saveTitle,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.save_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            '保存',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _editCover,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.honeyYellow.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.honeyYellow.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.warmBrown.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildCoverPreview(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '封面图片',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.warmBrown,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.book.customCoverPath != null 
                                          ? '自定义封面'
                                          : (_pages.isEmpty ? '暂无页面' : '使用第一页'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.warmBrown.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.honeyYellow.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: AppTheme.honeyYellow,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.gentleGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.pages_rounded,
                        size: 16,
                        color: AppTheme.gentleGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '页面列表 (${_pages.length} 页)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warmBrown,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _addNewPage,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('添加页面'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gentleGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _pages.isEmpty
                    ? _buildEmptyState()
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _pages.length,
                        onReorder: _reorderPages,
                        itemBuilder: (context, index) {
                          final page = _pages[index];
                          return Slidable(
                            key: ValueKey(page.id),
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _deletePage(index),
                                  backgroundColor: const Color(0xFFFF6B6B),
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_rounded,
                                  label: '删除',
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                ),
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: AppTheme.playfulShadow,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: _buildThumbnail(page),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.honeyYellow.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.warmBrown,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '第 ${index + 1} 页',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.warmBrown,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.calmBlue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${page.textBlocks.where((b) => !b.isDeleted).length} 个文字块',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.warmBrown.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.drag_handle_rounded,
                                  color: AppTheme.softGray,
                                ),
                                onTap: () => _editPage(index),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
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
                  AppTheme.sweetPink.withOpacity(0.2),
                  AppTheme.lavender.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              Icons.pages_outlined,
              size: 64,
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '点读本还没有页面',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.warmBrown,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addNewPage,
            icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
            label: const Text('添加第一页'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gentleGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(PageModel page) {
    final imageFile = ImageService.instance.getImageFile(page.imagePath);

    if (imageFile != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.warmBrown.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            imageFile,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.lightGray,
            AppTheme.softGray.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.image_not_supported_rounded,
        size: 24,
        color: AppTheme.softGray,
      ),
    );
  }

  Widget _buildCoverPreview() {
    if (widget.book.customCoverPath != null) {
      final imageFile = ImageService.instance.getImageFile(widget.book.customCoverPath!);
      if (imageFile != null) {
        return Image.file(
          imageFile,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        );
      }
    }

    if (_pages.isNotEmpty) {
      final imageFile = ImageService.instance.getImageFile(_pages.first.imagePath);
      if (imageFile != null) {
        return Image.file(
          imageFile,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        );
      }
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.calmBlue.withOpacity(0.3),
            AppTheme.gentleGreen.withOpacity(0.3),
          ],
        ),
      ),
      child: Icon(
        Icons.book_rounded,
        size: 24,
        color: AppTheme.warmBrown.withOpacity(0.5),
      ),
    );
  }
}