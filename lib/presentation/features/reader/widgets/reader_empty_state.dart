import 'package:book_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ReaderEmptyState extends StatelessWidget {
  final String bookTitle;
  final VoidCallback onEditBook;

  const ReaderEmptyState({
    super.key,
    required this.bookTitle,
    required this.onEditBook,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                '读本还没有页面',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceOf(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '「$bookTitle」中还没有任何页面，\n先去添加一些页面吧',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onEditBook,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('去编辑读本'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
