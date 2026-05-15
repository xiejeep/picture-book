import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../features/text_detection/text_detection.dart';
import '../../../widgets/semantics_icon_button.dart';
import '../../../../core/theme/app_theme.dart';
import 'info_container.dart';

class BlockCard extends StatelessWidget {
  final TextBlockData block;
  final int index;
  final bool isBusy;
  final bool hasImageFile;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAiEnhance;
  final VoidCallback? onPlay;
  final VoidCallback? onUseOriginal;
  final VoidCallback? onUseAiText;
  final VoidCallback? onEditTranslation;

  const BlockCard({
    super.key,
    required this.block,
    required this.index,
    required this.isBusy,
    required this.hasImageFile,
    this.onEdit,
    this.onDelete,
    this.onAiEnhance,
    this.onPlay,
    this.onUseOriginal,
    this.onUseAiText,
    this.onEditTranslation,
  });

  bool get hasAi => block.aiEnhancedText != null;
  bool get hasDraft => block.translatedText != null;
  bool get hasAiTrans => block.aiTranslatedText != null;
  bool get canUseOriginal =>
      block.originalText != null && block.text != block.originalText;
  bool get canUseAiText =>
      block.aiEnhancedText != null && block.text != block.aiEnhancedText;
  bool get hasOverflowItems =>
      (hasImageFile && !isBusy) || canUseOriginal || canUseAiText;

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryOf(context);
    final cardColor = AppTheme.cardOf(context);
    final onSurfaceColor = AppTheme.onSurfaceOf(context);

    return Slidable(
      key: ValueKey(block.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete?.call(),
            backgroundColor: AppTheme.errorOf(context),
            foregroundColor: Theme.of(context).colorScheme.onError,
            icon: Icons.delete_rounded,
            label: '删除',
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: hasAi ? 0.15 : 0.08),
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
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 10),
                  _buildContent(context),
                  if (hasAi || hasDraft || hasAiTrans) _buildActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final primaryColor = AppTheme.primaryOf(context);
    final onSurfaceColor = AppTheme.onSurfaceOf(context);

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
              if (hasAi) _buildBadge(Icons.auto_fix_high, primaryColor, 'AI优化'),
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
        if (hasOverflowItems) ...[
          const SizedBox(width: 12),
          SemanticsIconButton(
            icon: Icons.more_vert,
            label: '更多操作',
            hint: '打开更多操作菜单',
            size: 20,
            color: onSurfaceColor.withValues(alpha: 0.6),
            onPressed: () => _showOverflowMenu(context),
          ),
        ],
      ],
    );
  }

  void _showOverflowMenu(BuildContext context) {
    final primaryColor = AppTheme.primaryOf(context);
    final mutedColor = AppTheme.mutedOf(context);
    final surfaceColor = AppTheme.surfaceOf(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          color: surfaceColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: mutedColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (hasImageFile && !isBusy)
                ListTile(
                  leading: Icon(Icons.auto_fix_high, color: primaryColor),
                  title: const Text('AI强化此块'),
                  subtitle: const Text('使用AI优化识别结果'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onAiEnhance?.call();
                  },
                ),
              if (canUseOriginal)
                ListTile(
                  leading: Icon(Icons.undo, color: mutedColor),
                  title: const Text('使用原文'),
                  subtitle: const Text('恢复OCR原始识别'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onUseOriginal?.call();
                  },
                ),
              if (canUseAiText)
                ListTile(
                  leading: Icon(Icons.auto_fix_high,
                      color: primaryColor.withValues(alpha: 0.7)),
                  title: const Text('使用AI结果'),
                  subtitle: const Text('切换到AI优化版本'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onUseAiText?.call();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasAi && block.originalText != null) ...[
          OcrOriginalContainer(text: block.originalText!),
          const SizedBox(height: 8),
        ],
        AiResultContainer(text: block.text, isAiEnhanced: hasAi),
        if (hasAiTrans) ...[
          const SizedBox(height: 8),
          AiTranslationContainer(
              text: block.aiTranslatedText!, onEdit: onEditTranslation),
        ] else if (hasDraft) ...[
          const SizedBox(height: 8),
          DraftTranslationContainer(
              text: block.translatedText!, onEdit: onEditTranslation),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final primaryColor = AppTheme.primaryOf(context);
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('编辑文字'),
          onPressed: onEdit,
          style: ElevatedButton.styleFrom(
            foregroundColor: onPrimaryColor,
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
