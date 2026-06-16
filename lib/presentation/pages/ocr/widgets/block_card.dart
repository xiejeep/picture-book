import 'package:flutter/material.dart';
import '../../../features/text_detection/text_detection.dart';
import '../../../widgets/semantics_icon_button.dart';
import '../../../../core/theme/app_theme.dart';
import 'info_container.dart';

class BlockCard extends StatelessWidget {
  final TextBlockData block;
  final int index;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPlay;
  final VoidCallback? onEditTranslation;

  const BlockCard({
    super.key,
    required this.block,
    required this.index,
    this.onEdit,
    this.onDelete,
    this.onPlay,
    this.onEditTranslation,
  });

  bool get hasDraft => block.translatedText != null;
  bool get hasAiTrans => block.aiTranslatedText != null;

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryOf(context);
    final cardColor = AppTheme.cardOf(context);
    final onSurfaceColor = AppTheme.onSurfaceOf(context);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: onSurfaceColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 10),
              _buildContent(context),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final primaryColor = AppTheme.primaryOf(context);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              if (hasAiTrans)
                _buildBadge(Icons.translate, AppTheme.accentOf(context), 'AI翻译',
                    margin: const EdgeInsets.only(left: 6)),
            ],
          ),
        ),
        SemanticsIconButton(
          icon: Icons.volume_up,
          label: '播放',
          hint: '朗读此文字块',
          size: 20,
          color: primaryColor,
          onPressed: onPlay,
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, Color color, String label,
      {EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final onSurfaceColor = AppTheme.onSurfaceOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(block.text,
            style: TextStyle(fontSize: 14, color: onSurfaceColor)),
        if (hasAiTrans) ...[
          const SizedBox(height: 8),
          AiTranslationContainer(text: block.aiTranslatedText!),
        ] else if (hasDraft) ...[
          const SizedBox(height: 8),
          DraftTranslationContainer(text: block.translatedText!),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final primaryColor = AppTheme.primaryOf(context);
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: onEdit,
              style: ElevatedButton.styleFrom(
                foregroundColor: onPrimaryColor,
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('编辑文字'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: onEditTranslation,
              style: ElevatedButton.styleFrom(
                foregroundColor: onPrimaryColor,
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('编辑翻译'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: onDelete,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('删除'),
            ),
          ),
        ],
      ),
    );
  }
}
