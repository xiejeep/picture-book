part of 'text_detection_view.dart';

mixin _TextDetectionDialogs on ConsumerState<TextDetectionView> {
  void editSelectedBlock(TextDetectionState state) {
    final block = state.selectedBlock;
    if (block == null) return;

    final notifier = ref.read(textDetectionProvider.notifier);

    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: block.text);
        bool isRecognizing = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('编辑文字'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: null,
                    decoration: const InputDecoration(
                      labelText: '文字内容',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  if (isRecognizing)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('正在识别...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isRecognizing ? null : () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                if (state.imageFile != null && !isRecognizing)
                  TextButton(
                    onPressed: () async {
                      setDialogState(() {
                        isRecognizing = true;
                        errorMessage = null;
                      });

                      final recognizedText =
                          await OcrService.instance.recognizeTextInRegion(
                        state.imageFile!,
                        block.boundingBox,
                      );

                      setDialogState(() {
                        isRecognizing = false;
                        if (recognizedText != null &&
                            recognizedText.isNotEmpty) {
                          controller.text = recognizedText;
                        } else {
                          errorMessage = '该区域未识别到文字，请手动输入';
                        }
                      });
                    },
                    child: const Text('识别此区域'),
                  ),
                TextButton(
                  onPressed: isRecognizing
                      ? null
                      : () {
                          notifier.updateBlockText(block.id, controller.text);
                          Navigator.pop(context);
                        },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void confirmDeleteBlock(
      TextDetectionState state, TextDetectionNotifier notifier) {
    if (state.selectedBlockId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除'),
        content: const Text('确定要删除此文字块吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.deleteSelectedBlock();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> showAiEnhanceAllDialog(TextDetectionNotifier notifier) async {
    final hasApiKey = await AiService.instance.hasApiKey();
    if (!hasApiKey) {
      ToastUtil.warning('请先在设置中配置API Key');
      return;
    }

    final state = ref.read(textDetectionProvider);
    final visibleBlocks = state.textBlocks.where((b) => !b.isDeleted).toList();
    if (visibleBlocks.isEmpty) {
      ToastUtil.warning('没有可优化的文字块');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI强化全部'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppPrompts.aiUsageNotice,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppPrompts.aiAccuracyNotice,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('确定要对所有${visibleBlocks.length}个文字块进行AI强化识别吗？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final count = await notifier.aiEnhanceAll();
        if (!mounted) return;
        ToastUtil.success('AI强化识别完成，已优化 $count 个文字块');
      } catch (e) {
        if (!mounted) return;
        ToastUtil.error(
            'AI强化失败: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  Future<void> showAiEnhanceSelectedDialog(
    TextDetectionState state,
    TextDetectionNotifier notifier,
  ) async {
    if (state.selectedBlockId == null) return;

    final hasApiKey = await AiService.instance.hasApiKey();
    if (!hasApiKey) {
      ToastUtil.warning('请先在设置中配置API Key');
      return;
    }

    if (state.imageFile == null) {
      ToastUtil.error('没有图片文件，无法进行AI强化');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI强化识别'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppPrompts.aiUsageNotice,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppPrompts.aiAccuracyNotice,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('确定要对此文字块进行AI强化识别吗？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final hasChanges = await notifier.aiEnhanceSelectedBlock();
        if (!mounted) return;
        if (hasChanges) {
          ToastUtil.success('AI强化完成');
        } else {
          ToastUtil.info('AI强化完成，无需修改');
        }
      } catch (e) {
        if (!mounted) return;
        ToastUtil.error(
            'AI强化失败: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  Future<void> showModelSelectionDialog(
      TextDetectionState state, TextDetectionNotifier notifier) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择AI强化模型'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppConstants.availableModels.map((model) {
              final isSelected = state.currentAiModel == model['name'];
              final isFree = model['free'] == 'true';

              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? AppTheme.primaryOf(context) : Colors.grey,
                ),
                title: Text(model['label']!),
                subtitle: isFree
                    ? const Text('免费大模型', style: TextStyle(fontSize: 12))
                    : const Text('付费大模型',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                selected: isSelected,
                onTap: () => Navigator.pop(context, model['name']),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (result != null) {
      notifier.setAiModel(result);
    }
  }

  Future<void> showReRecognizeAllDialog(TextDetectionNotifier notifier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新识别全部'),
        content: const Text('确定要重新识别图片中的所有文字吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await notifier.recognizeText();
    }
  }

  Future<void> showReRecognizeSelectedBlock(
    TextDetectionState state,
    TextDetectionNotifier notifier,
  ) async {
    if (state.selectedBlockId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新识别'),
        content: const Text('确定要重新识别选中区域的文字吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await notifier.reRecognizeBlock(state.selectedBlockId!);
    }
  }

  Future<Map<String, dynamic>?> showUnsavedDialog(
    TextDetectionState state,
    TextDetectionNotifier notifier,
  ) async {
    if (widget.onSave != null && state.imageFile != null) {
      final visibleBlocks = notifier.getBlocksForSave();
      if (visibleBlocks.isNotEmpty) {
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('未保存的更改'),
            content: const Text('你有未保存的更改，是否保存？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'discard'),
                child: const Text('不保存'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'save'),
                child: const Text('保存'),
              ),
            ],
          ),
        );
        if (action == 'save') {
          notifier.clearChanges();
          return {
            'textBlocks': visibleBlocks,
            'imageFile': state.imageFile,
          };
        }
        if (action == 'discard') {
          notifier.clearChanges();
          return null;
        }
        return null;
      }
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的更改'),
        content: const Text('你有未保存的更改，确定要退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (discard == true) {
      notifier.clearChanges();
      return null;
    }
    return null;
  }

  void showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('操作指南'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('• 双指缩放：放大/缩小图片'),
              Text('• 单指平移：查看模式下拖动移动图片'),
              Text('• 绘制模式：拖动绘制新的文字区域'),
              Text('• 编辑模式：选中后可移动或调整大小'),
              Text('• 点击文字块选中，点击空白区域取消'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
