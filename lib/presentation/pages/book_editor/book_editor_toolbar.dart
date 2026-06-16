import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class BookEditorToolbar extends StatelessWidget {
  final bool hasSelection;
  final bool isDrawing;
  final bool hasBlocks;
  final VoidCallback onEditText;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onAiEnhance;
  final VoidCallback onNewBlock;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final VoidCallback onReOcr;

  const BookEditorToolbar({
    super.key,
    required this.hasSelection,
    required this.isDrawing,
    required this.hasBlocks,
    required this.onEditText,
    required this.onPlay,
    required this.onDelete,
    required this.onAiEnhance,
    required this.onNewBlock,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onReOcr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildZoomRow(context),
            const SizedBox(height: 6),
            if (hasSelection)
              _buildSelectionActions(context)
            else
              _buildDefaultActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomRow(BuildContext context) {
    return Row(
      children: [
        _buildCircleIcon(Icons.add, '放大', onZoomIn),
        const SizedBox(width: 4),
        _buildCircleIcon(Icons.remove, '缩小', onZoomOut),
        const SizedBox(width: 4),
        _buildPill(
            const Text('适应',
                style: TextStyle(fontSize: 12, color: Colors.white)),
            onResetZoom),
        const Spacer(),
        if (isDrawing)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.draw, size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              const Text(
                '在画布上拖动绘制文字区域',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSelectionActions(BuildContext context) {
    return Row(
      children: [
        _buildIconLabel(Icons.edit, '编辑', onEditText, AppTheme.softOrange),
        const SizedBox(width: 4),
        _buildIconLabel(Icons.volume_up, '试听', onPlay, AppTheme.gentleGreen),
        const SizedBox(width: 4),
        _buildIconLabel(Icons.delete, '删除', onDelete, Colors.redAccent),
        const Spacer(),
        _buildIconLabel(
            Icons.auto_fix_high, 'AI强化', onAiEnhance, Colors.purpleAccent),
      ],
    );
  }

  Widget _buildDefaultActions(BuildContext context) {
    return Row(
      children: [
        _buildIconLabel(
          Icons.draw,
          isDrawing ? '取消绘制' : '新建块',
          onNewBlock,
          isDrawing ? Colors.white70 : Colors.blueAccent,
        ),
        const SizedBox(width: 4),
        _buildIconLabel(
          Icons.document_scanner,
          '重新OCR',
          onReOcr,
          Colors.cyanAccent,
        ),
        const Spacer(),
        if (hasBlocks)
          _buildIconLabel(
            Icons.auto_fix_high,
            '全部AI强化',
            onAiEnhance,
            Colors.purpleAccent,
          ),
      ],
    );
  }

  Widget _buildCircleIcon(IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildPill(Widget child, VoidCallback onTap) {
    return Semantics(
      label: '适应',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildIconLabel(
      IconData icon, String label, VoidCallback onTap, Color color) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                    fontSize: 11, color: color.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
