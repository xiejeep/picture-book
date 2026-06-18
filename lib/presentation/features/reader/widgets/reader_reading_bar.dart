import 'package:book_app/core/theme/app_theme.dart';
import 'package:book_app/data/models/text_block_model.dart';
import 'package:book_app/data/services/translation_service.dart';
import 'package:flutter/material.dart';

class ReaderReadingBar extends StatelessWidget {
  final TextBlockModel block;
  final bool isPlaying;
  final bool showTranslation;
  final bool isTranslating;
  final TranslationStatus translationStatus;
  final String? translatedText;
  final VoidCallback onStopPlaying;
  final VoidCallback onReplay;
  final VoidCallback onClose;

  const ReaderReadingBar({
    super.key,
    required this.block,
    required this.isPlaying,
    required this.showTranslation,
    required this.isTranslating,
    required this.translationStatus,
    required this.translatedText,
    required this.onStopPlaying,
    required this.onReplay,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 72,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.isDarkMode(context)
                ? AppTheme.darkCard
                : const Color(0xFF2D2D3A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      block.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ReaderBarIconButton(
                    label: isPlaying ? '停止朗读' : '重新播放',
                    hint: '控制朗读播放',
                    icon: isPlaying
                        ? Icons.stop_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    onTap: isPlaying ? onStopPlaying : onReplay,
                  ),
                  const SizedBox(width: 4),
                  _ReaderBarIconButton(
                    label: '关闭',
                    hint: '关闭阅读栏',
                    icon: Icons.close,
                    color: Colors.white70,
                    onTap: onClose,
                  ),
                ],
              ),
              if (showTranslation) _buildTranslationContent(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationContent(BuildContext context) {
    final statusText = _statusText;
    if (isTranslating) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (translatedText != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            translatedText!,
            style: TextStyle(
              color: AppTheme.accentOf(context),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    if (translationStatus == TranslationStatus.failed) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          statusText,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String get _statusText {
    if (translationStatus == TranslationStatus.downloadingModel) {
      return '正在下载翻译模型...';
    }
    if (isTranslating) return '翻译中...';
    if (translationStatus == TranslationStatus.failed) return '翻译失败';
    return '';
  }
}

class _ReaderBarIconButton extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReaderBarIconButton({
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: color),
        ),
      ),
    );
  }
}
