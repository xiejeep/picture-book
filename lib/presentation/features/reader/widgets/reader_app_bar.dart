import 'package:book_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showTranslation;
  final bool showBorders;
  final bool supportsTranslation;
  final bool showNfcScan;
  final VoidCallback onVoiceSettings;
  final VoidCallback onToggleAppBar;
  final VoidCallback onToggleTranslation;
  final VoidCallback onToggleBorders;
  final VoidCallback onScanNfc;

  const ReaderAppBar({
    super.key,
    required this.title,
    required this.showTranslation,
    required this.showBorders,
    required this.supportsTranslation,
    required this.showNfcScan,
    required this.onVoiceSettings,
    required this.onToggleAppBar,
    required this.onToggleTranslation,
    required this.onToggleBorders,
    required this.onScanNfc,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.isDarkMode(context)
          ? AppTheme.darkSurface.withValues(alpha: 0.85)
          : AppTheme.softOrange.withValues(alpha: 0.85),
      elevation: 0,
      title: Text(title),
      actions: [
        _ReaderAppBarButton(
          label: '语音设置',
          hint: '调整朗读语速和语音',
          icon: Icons.record_voice_over_rounded,
          tooltip: '语音设置',
          onPressed: onVoiceSettings,
        ),
        _ReaderAppBarButton(
          label: '隐藏导航栏',
          hint: '双击页面可重新显示',
          icon: Icons.visibility_off_rounded,
          tooltip: '隐藏导航栏',
          onPressed: onToggleAppBar,
        ),
        if (supportsTranslation)
          _ReaderAppBarButton(
            label: showTranslation ? '隐藏翻译' : '显示翻译',
            hint: '切换翻译显示状态',
            icon: showTranslation
                ? Icons.translate_rounded
                : Icons.translate_outlined,
            iconColor: showTranslation
                ? Colors.white
                : Colors.white.withValues(alpha: 0.6),
            tooltip: showTranslation ? '隐藏翻译' : '显示翻译',
            onPressed: onToggleTranslation,
          ),
        _ReaderAppBarButton(
          label: showBorders ? '隐藏边框' : '显示边框',
          hint: '切换文字块边框显示',
          icon: showBorders
              ? Icons.border_color_rounded
              : Icons.border_clear_rounded,
          tooltip: showBorders ? '隐藏边框' : '显示边框',
          onPressed: onToggleBorders,
        ),
        if (showNfcScan)
          _ReaderAppBarButton(
            label: '扫描NFC标签',
            hint: '靠近NFC标签自动识别并播放',
            icon: Icons.nfc,
            tooltip: '扫描NFC标签',
            onPressed: onScanNfc,
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.appBarGradientOf(context),
        ),
      ),
    );
  }
}

class _ReaderAppBarButton extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color iconColor;

  const _ReaderAppBarButton({
    required this.label,
    required this.hint,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
