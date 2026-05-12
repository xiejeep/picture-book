import 'package:flutter/material.dart';
import '../../data/models/book_model.dart';
import '../../data/services/image_service.dart';
import '../../core/theme/app_theme.dart';

class BookCard extends StatefulWidget {
  final BookModel book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BookCard({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _shadowAnimation = Tween<double>(begin: 4.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    blurRadius: 12 + _shadowAnimation.value,
                    offset: Offset(0, 4 + _shadowAnimation.value / 2),
                  ),
                  BoxShadow(
                    color: AppTheme.warmBrown.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _buildCover(),
                        ),
                        _buildInfo(),
                      ],
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildPageBadge(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCover() {
    final coverPath = widget.book.coverImagePath;

    if (coverPath != null) {
      final imageFile = ImageService.instance.getImageFile(coverPath);
      if (imageFile != null) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppTheme.cardColor.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.calmBlue.withOpacity(0.3),
            AppTheme.gentleGreen.withOpacity(0.3),
            AppTheme.sweetPink.withOpacity(0.2),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 48,
              color: AppTheme.primaryColor.withOpacity(0.8),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.honeyYellow.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '点读本',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.warmBrown.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Text(
        widget.book.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.warmBrown,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPageBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.honeyYellow,
            AppTheme.softOrange,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.honeyYellow.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pages_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.book.pageCount}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}