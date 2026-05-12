import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/book_model.dart';
import '../providers/books_provider.dart';
import '../widgets/book_card.dart';
import '../../core/utils/toast_util.dart';
import '../../core/theme/app_theme.dart';
import 'book_detail_page.dart';
import 'book_manage_page.dart';
import 'text_detection_page.dart';
import 'settings_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Future<void> _createNewBook() async {
    final title = await _showCreateBookDialog();
    if (title == null) return;

    final book = await ref.read(booksProvider.notifier).createBook(title);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextDetectionPage(
          onSave: (textBlocks, imageFile) async {
            await ref.read(booksProvider.notifier).addPageToBook(
                  book.id,
                  imageFile,
                  textBlocks,
                );
            Navigator.pop(context);
          },
        ),
      ),
    );
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
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '创建新点读本',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warmBrown,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: '点读本名称',
                  hintText: '给点读本起个名字',
                  prefixIcon: Icon(
                    Icons.edit_note_rounded,
                    color: AppTheme.primaryColor.withOpacity(0.7),
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
                      style: TextStyle(color: AppTheme.softGray),
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
                '删除点读本',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warmBrown,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '确定删除 "${book.title}" 吗？',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.warmBrown.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFFFF6B6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '包含 ${book.pageCount} 个页面',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFF6B6B),
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
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.honeyYellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: AppTheme.honeyYellow,
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
                  color: Color(0xFFFF6B6B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_rounded,
                  color: Color(0xFFFF6B6B),
                ),
              ),
              title: const Text('删除点读本'),
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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text('我的点读本'),
            if (booksState.books.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.honeyYellow.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${booksState.books.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.settings_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            onPressed: _openSettings,
            tooltip: '设置',
          ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppTheme.softOrange,
                Color(0xFFFF8C42),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.warmGradientBox,
        child: SafeArea(
          left: false,
          right: false,
          child: booksState.isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '正在加载...',
                        style: TextStyle(
                          color: AppTheme.warmBrown.withOpacity(0.6),
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
          : FloatingActionButton(
              onPressed: _createNewBook,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.softOrange,
                      Color(0xFFFF8C42),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
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
                  AppTheme.calmBlue.withOpacity(0.2),
                  AppTheme.gentleGreen.withOpacity(0.2),
                  AppTheme.sweetPink.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              size: 64,
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '还没有点读本',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.warmBrown,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '创建一个点读本，开始互动阅读吧！',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.warmBrown.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createNewBook,
            icon: const Icon(Icons.add_rounded),
            label: const Text('创建第一个点读本'),
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