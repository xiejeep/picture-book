import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/canvas_mode.dart';
import '../models/text_detection_state.dart';
import '../view_models/text_detection_viewmodel.dart';

class BottomToolbar extends StatelessWidget {
  final TextDetectionNotifier notifier;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAiEnhanceAll;
  final VoidCallback onReRecognizeAll;

  const BottomToolbar({
    super.key,
    required this.notifier,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
    required this.onAiEnhanceAll,
    required this.onReRecognizeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(textDetectionProvider);

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: _buildContent(state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(TextDetectionState state) {
    final hasSelection =
        state.selectedBlockId != null && state.mode == CanvasMode.edit;
    final isDrawMode = state.mode == CanvasMode.draw;
    final visibleBlocks = state.getVisibleBlocks();

    if (hasSelection) {
      return _buildSelectedBlockContent(state);
    }
    if (isDrawMode) {
      return _buildDrawModeContent(state);
    }
    return _buildDefaultContent(state, visibleBlocks);
  }

  Widget _buildDefaultContent(
    TextDetectionState state,
    List visibleBlocks,
  ) {
    return Row(
      children: [
        _buildModeSegment(state),
        const Spacer(),
        if (visibleBlocks.isNotEmpty && !state.isAiEnhancing) ...[
          _buildCompactButton(
            icon: Icons.auto_fix_high,
            label: 'AI强化',
            onTap: onAiEnhanceAll,
            color: Colors.purpleAccent,
          ),
          const SizedBox(width: 6),
        ],
        _buildCompactButton(
          icon: Icons.refresh,
          label: '重识别',
          onTap: onReRecognizeAll,
        ),
      ],
    );
  }

  Widget _buildDrawModeContent(TextDetectionState state) {
    return Row(
      children: [
        _buildModeSegment(state),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.draw, size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              const Text(
                '拖动绘制文字区域',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedBlockContent(TextDetectionState state) {
    final isResize = state.editSubMode == EditSubMode.resize;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _buildModeSegment(state),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildSubModeButton(
              icon: Icons.open_in_full,
              label: '调整大小',
              isActive: isResize,
              activeColor: AppTheme.calmBlue,
              onTap: isResize ? null : () => notifier.toggleEditSubMode(),
            ),
            const SizedBox(width: 4),
            _buildSubModeButton(
              icon: Icons.open_with,
              label: '移动位置',
              isActive: !isResize,
              activeColor: AppTheme.softOrange,
              onTap: isResize ? () => notifier.toggleEditSubMode() : null,
            ),
            const Spacer(),
            _buildIconLabelButton(
              icon: Icons.volume_up,
              label: '试听',
              onTap: onPlay,
              color: AppTheme.gentleGreen,
            ),
            _buildIconLabelButton(
              icon: Icons.edit,
              label: '编辑',
              onTap: onEdit,
              color: AppTheme.softOrange,
            ),
            _buildIconLabelButton(
              icon: Icons.delete,
              label: '删除',
              onTap: onDelete,
              color: Colors.redAccent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeSegment(TextDetectionState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton(
            Icons.visibility,
            '查看',
            CanvasMode.view,
            state,
          ),
          _buildModeButton(
            Icons.draw,
            '绘制',
            CanvasMode.draw,
            state,
          ),
          _buildModeButton(
            Icons.edit,
            '编辑',
            CanvasMode.edit,
            state,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    IconData icon,
    String label,
    CanvasMode mode,
    TextDetectionState state,
  ) {
    final isActive = state.mode == mode;

    return GestureDetector(
      onTap: () => notifier.setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.calmBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubModeButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.8) : Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconLabelButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final iconColor = color ?? Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
