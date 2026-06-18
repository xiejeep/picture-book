import 'package:book_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ReaderBlockActionsSheet extends StatelessWidget {
  final bool showNfcAction;
  final VoidCallback onEditText;
  final VoidCallback onEditTranslation;
  final VoidCallback onBindNfc;

  const ReaderBlockActionsSheet({
    super.key,
    required this.showNfcAction,
    required this.onEditText,
    required this.onEditTranslation,
    required this.onBindNfc,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: AppTheme.surfaceOf(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.mutedOf(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _ReaderActionTile(
              icon: Icons.edit,
              title: '编辑文字',
              subtitle: '修改此文字块的识别文本',
              color: AppTheme.primaryOf(context),
              onTap: onEditText,
            ),
            _ReaderActionTile(
              icon: Icons.translate,
              title: '编辑翻译',
              subtitle: '修改此文字块的翻译文本',
              color: AppTheme.accentOf(context),
              onTap: onEditTranslation,
            ),
            if (showNfcAction)
              _ReaderActionTile(
                icon: Icons.nfc,
                title: '绑定 NFC 标签',
                subtitle: '将此文字块绑定到 NFC 标签',
                color: Colors.teal,
                onTap: onBindNfc,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ReaderActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ReaderActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: AppTheme.onSurfaceOf(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
