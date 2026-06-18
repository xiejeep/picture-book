import 'package:book_app/core/theme/app_theme.dart';
import 'package:book_app/presentation/widgets/semantics_icon_button.dart';
import 'package:flutter/material.dart';

class ReaderTextEditSheet extends StatefulWidget {
  final String title;
  final String fieldLabel;
  final String initialText;
  final String aiButtonLabel;
  final IconData aiButtonIcon;
  final Color aiButtonColor;
  final Future<String?> Function() onAiFill;
  final ValueChanged<String> onSave;

  const ReaderTextEditSheet({
    super.key,
    required this.title,
    required this.fieldLabel,
    required this.initialText,
    required this.aiButtonLabel,
    required this.aiButtonIcon,
    required this.aiButtonColor,
    required this.onAiFill,
    required this.onSave,
  });

  @override
  State<ReaderTextEditSheet> createState() => _ReaderTextEditSheetState();
}

class _ReaderTextEditSheetState extends State<ReaderTextEditSheet> {
  late final TextEditingController _controller;
  bool _isAiLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurfaceColor = AppTheme.onSurfaceOf(context);

    return Container(
      color: AppTheme.surfaceOf(context),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceColor,
                  ),
                ),
                SemanticsIconButton(
                  icon: Icons.close,
                  label: '关闭',
                  hint: '关闭编辑窗口',
                  color: onSurfaceColor,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.fieldLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isAiLoading ? null : _fillWithAi,
                  icon: _isAiLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(widget.aiButtonIcon, size: 18),
                  label: Text(widget.aiButtonLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.aiButtonColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: onSurfaceColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onSave(_controller.text);
                    Navigator.pop(context);
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fillWithAi() async {
    setState(() => _isAiLoading = true);
    final text = await widget.onAiFill();
    if (!mounted) return;
    setState(() => _isAiLoading = false);
    if (text != null) {
      _controller.text = text;
    }
  }
}
