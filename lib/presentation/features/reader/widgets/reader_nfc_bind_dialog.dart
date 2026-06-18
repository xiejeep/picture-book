import 'package:book_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ReaderNfcBindDialog extends StatefulWidget {
  final String blockText;
  final Future<String?> Function() onBind;
  final VoidCallback onBound;

  const ReaderNfcBindDialog({
    super.key,
    required this.blockText,
    required this.onBind,
    required this.onBound,
  });

  @override
  State<ReaderNfcBindDialog> createState() => _ReaderNfcBindDialogState();
}

class _ReaderNfcBindDialogState extends State<ReaderNfcBindDialog> {
  bool _isWriting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryOf(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.nfc,
              color: AppTheme.primaryOf(context),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '绑定 NFC 标签',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceOf(context),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '将此文本块绑定到一张 NFC 标签：',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.blockText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurfaceOf(context),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatus(context),
        ],
      ),
      actions: [
        if (!_isWriting)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _errorMessage != null ? '关闭' : '取消',
              style: TextStyle(
                color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
              ),
            ),
          ),
        ElevatedButton(
          onPressed: _isWriting ? null : _bind,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                AppTheme.primaryOf(context).withValues(alpha: 0.85),
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(_errorMessage != null ? '重新绑定' : '开始绑定'),
        ),
      ],
    );
  }

  Widget _buildStatus(BuildContext context) {
    if (_isWriting) {
      return Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryOf(context),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '请将 NFC 标签贴近手机背面...',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.primaryOf(context),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return Text(
        _errorMessage!,
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.errorOf(context),
        ),
      );
    }

    return Text(
      '点击"开始绑定"后请将 NFC 标签贴近手机背面',
      style: TextStyle(
        fontSize: 13,
        color: AppTheme.primaryOf(context),
      ),
    );
  }

  Future<void> _bind() async {
    setState(() {
      _isWriting = true;
      _errorMessage = null;
    });

    final error = await widget.onBind();
    if (!mounted) return;

    if (error == null) {
      Navigator.pop(context);
      widget.onBound();
      return;
    }

    setState(() {
      _isWriting = false;
      _errorMessage = error;
    });
  }
}
