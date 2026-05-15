import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class InfoContainer extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final VoidCallback? onEdit;

  const InfoContainer({
    super.key,
    required this.icon,
    required this.label,
    required this.text,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final onSurfaceColor = AppTheme.onSurfaceOf(context);
    final mutedColor = AppTheme.mutedOf(context);
    final surfaceColor = AppTheme.surfaceOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: mutedColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onEdit != null) ...[
                const Spacer(),
                Semantics(
                  label: '编辑',
                  hint: '编辑此内容',
                  button: true,
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Icon(Icons.edit,
                        size: 16, color: mutedColor.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: onSurfaceColor,
            ),
          ),
        ],
      ),
    );
  }
}

class OcrOriginalContainer extends StatelessWidget {
  final String text;

  const OcrOriginalContainer({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return InfoContainer(
      icon: Icons.text_fields,
      label: 'OCR原始',
      text: text,
    );
  }
}

class AiResultContainer extends StatelessWidget {
  final String text;
  final bool isAiEnhanced;

  const AiResultContainer({
    super.key,
    required this.text,
    this.isAiEnhanced = false,
  });

  @override
  Widget build(BuildContext context) {
    return InfoContainer(
      icon: isAiEnhanced ? Icons.auto_fix_high : Icons.text_snippet,
      label: isAiEnhanced ? 'AI优化结果' : '识别结果',
      text: text,
    );
  }
}

class AiTranslationContainer extends StatelessWidget {
  final String text;
  final VoidCallback? onEdit;

  const AiTranslationContainer({super.key, required this.text, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return InfoContainer(
      icon: Icons.auto_awesome,
      label: 'AI优化翻译',
      text: text,
      onEdit: onEdit,
    );
  }
}

class DraftTranslationContainer extends StatelessWidget {
  final String text;
  final VoidCallback? onEdit;

  const DraftTranslationContainer({super.key, required this.text, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return InfoContainer(
      icon: Icons.translate,
      label: '翻译草稿',
      text: text,
      onEdit: onEdit,
    );
  }
}
