import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/toast_util.dart';
import '../../../core/constants/constants.dart';
import '../../../data/services/ai_service.dart';
import '../../../data/services/translation_service.dart';
import '../../../core/utils/platform_utils.dart';
import '../../providers/tts_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/service_providers.dart';
import '../../features/text_detection/text_detection.dart';
import '../../widgets/semantics_icon_button.dart';
import './widgets/block_card.dart';
import './widgets/progress_overlay.dart';

class OcrResultsTablePage extends ConsumerStatefulWidget {
  final List<TextBlockData> textBlocks;
  final File? imageFile;

  const OcrResultsTablePage({
    super.key,
    required this.textBlocks,
    this.imageFile,
  });

  @override
  ConsumerState<OcrResultsTablePage> createState() =>
      _OcrResultsTablePageState();
}

class _OcrResultsTablePageState extends ConsumerState<OcrResultsTablePage> {
  late List<TextBlockData> _blocks;
  bool _isAiEnhancing = false;
  bool _isAiTranslating = false;
  String _progressText = 'AI正在优化识别结果...';
  String _currentAiModel = AppConstants.defaultModel;
  String? _cachedVisionDescription;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _blocks = widget.textBlocks;
    _loadCurrentModel();
  }

  void _loadCurrentModel() {
    final savedModel = ref.read(selectedModelProvider);
    final modelExists =
        AppConstants.availableModels.any((m) => m['name'] == savedModel);
    _currentAiModel = modelExists ? savedModel : AppConstants.defaultModel;
  }

  int _findRealIndex(int visibleIndex) {
    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    final targetBlock = visibleBlocks[visibleIndex];
    return _blocks.indexOf(targetBlock);
  }

  bool get _isBusy => _isAiEnhancing || _isAiTranslating;

  Future<String> _ensureVisionDescription() async {
    if (_cachedVisionDescription != null) return _cachedVisionDescription!;
    if (widget.imageFile == null) throw Exception('没有图片文件');

    setState(() => _progressText = 'AI正在理解图片内容...');
    _cachedVisionDescription = await AiService.instance.extractVisionText(
      widget.imageFile!,
      _currentAiModel,
    );
    return _cachedVisionDescription!;
  }

  void _editBlock(int visibleIndex) {
    final realIndex = _findRealIndex(visibleIndex);
    final block = _blocks[realIndex];
    final controller = TextEditingController(text: block.text);
    final onSurfaceColor = AppTheme.onSurfaceOf(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        color: AppTheme.surfaceOf(context),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '编辑文字块 #${visibleIndex + 1}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceColor),
                  ),
                  SemanticsIconButton(
                      icon: Icons.close,
                      label: '关闭',
                      hint: '关闭编辑窗口',
                      color: onSurfaceColor,
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              if (block.originalText != null)
                _buildEditInfoBox(
                    Icons.text_fields, 'OCR原始识别', block.originalText!),
              if (block.aiEnhancedText != null)
                _buildEditInfoBox(
                    Icons.auto_fix_high, 'AI优化结果', block.aiEnhancedText!),
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '最终文本', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text != block.text) {
                        setState(() {
                          _blocks[realIndex] = _blocks[realIndex].copyWith(
                              text: controller.text,
                              clearTranslatedText: true,
                              clearAiTranslatedText: true);
                          _hasChanges = true;
                        });
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editTranslation(int visibleIndex) {
    final realIndex = _findRealIndex(visibleIndex);
    final block = _blocks[realIndex];
    final currentTranslation =
        block.aiTranslatedText ?? block.translatedText ?? '';
    final controller = TextEditingController(text: currentTranslation);
    final onSurfaceColor = AppTheme.onSurfaceOf(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        color: AppTheme.surfaceOf(context),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '编辑翻译 #${visibleIndex + 1}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceColor),
                  ),
                  SemanticsIconButton(
                      icon: Icons.close,
                      label: '关闭',
                      hint: '关闭翻译编辑窗口',
                      color: onSurfaceColor,
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              _buildEditInfoBox(Icons.text_snippet, '原文', block.text),
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '翻译文本', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (block.aiTranslatedText != null) {
                          _blocks[realIndex] = _blocks[realIndex]
                              .copyWith(aiTranslatedText: controller.text);
                        } else {
                          _blocks[realIndex] = _blocks[realIndex]
                              .copyWith(translatedText: controller.text);
                        }
                        _hasChanges = true;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditInfoBox(IconData icon, String label, String text) {
    final onSurfaceColor = AppTheme.onSurfaceOf(context);
    final mutedColor = AppTheme.mutedOf(context);
    final surfaceColor = AppTheme.surfaceOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: mutedColor),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mutedColor))
          ]),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(fontSize: 14, color: onSurfaceColor)),
        ],
      ),
    );
  }

  void _useAiText(int visibleIndex) {
    final realIndex = _findRealIndex(visibleIndex);
    if (_blocks[realIndex].aiEnhancedText != null) {
      setState(() {
        _blocks[realIndex] = _blocks[realIndex]
            .copyWith(text: _blocks[realIndex].aiEnhancedText!);
        _hasChanges = true;
      });
    }
  }

  void _useOriginalText(int visibleIndex) {
    final realIndex = _findRealIndex(visibleIndex);
    if (_blocks[realIndex].originalText != null) {
      setState(() {
        _blocks[realIndex] =
            _blocks[realIndex].copyWith(text: _blocks[realIndex].originalText!);
        _hasChanges = true;
      });
    }
  }

  void _deleteBlock(int visibleIndex) {
    final realIndex = _findRealIndex(visibleIndex);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除'),
        content: const Text('确定要删除此文字块吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _blocks[realIndex] =
                    _blocks[realIndex].copyWith(isDeleted: true);
                _hasChanges = true;
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAiEnhanceDialog(int visibleIndex) async {
    if (!await _checkApiKey()) return;
    final confirm = await _showConfirmDialog('AI强化识别', '确定要对此文字块进行AI强化识别吗？');
    if (confirm == true) await _aiEnhanceBlock(visibleIndex);
  }

  Future<void> _showAiEnhanceAllDialog() async {
    if (!await _checkApiKey()) return;
    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    if (visibleBlocks.isEmpty) {
      ToastUtil.warning('没有可优化的文字块');
      return;
    }
    final confirm = await _showConfirmDialog(
        'AI强化全部', '确定要对所有${visibleBlocks.length}个文字块进行AI强化识别吗？');
    if (confirm == true) await _aiEnhanceAllBlocks();
  }

  Future<void> _showAiTranslateDialog() async {
    if (!await _checkApiKey()) return;
    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    if (visibleBlocks.isEmpty) {
      ToastUtil.warning('没有可翻译的文字块');
      return;
    }
    final confirm =
        await _showConfirmDialog('AI强化翻译', '将对${visibleBlocks.length}个文字块进行翻译');
    if (confirm == true) await _aiTranslateAllBlocks();
  }

  Future<bool> _checkApiKey() async {
    final hasKey = await ref.read(aiRepositoryProvider).hasApiKey();
    if (!hasKey) ToastUtil.warning('请先在设置中配置API Key');
    return hasKey;
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存更改'),
        content: const Text('您有未保存的更改，是否保存？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('不保存'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      if (mounted) Navigator.pop(context, _blocks);
      return false;
    } else if (result == 'discard') {
      return true;
    }
    return false;
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrivacyNotice(),
              const SizedBox(height: 12),
              Text(content)
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定')),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('提示：AI识别结果可能不完全准确，建议手动检查和修改。',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _aiEnhanceBlock(int visibleIndex) async {
    if (widget.imageFile == null) {
      ToastUtil.error('没有图片文件');
      return;
    }
    final realIndex = _findRealIndex(visibleIndex);

    setState(() {
      _isAiEnhancing = true;
      _progressText = 'AI正在优化识别结果...';
    });

    try {
      final vision = await _ensureVisionDescription();
      var block = _blocks[realIndex];
      if (block.originalText == null) {
        _blocks[realIndex] = block.copyWith(originalText: block.text);
        block = _blocks[realIndex];
      }

      final correctedBlocks = await AiService.instance.enhanceTextBlocks(
        widget.imageFile!,
        [
          {0: block.text}
        ],
        _currentAiModel,
        onProgress: (msg) => setState(() => _progressText = msg),
        visionDescription: vision,
      );

      if (correctedBlocks[0] != null) {
        setState(() {
          _blocks[realIndex] = _blocks[realIndex].copyWith(
              aiEnhancedText: correctedBlocks[0]!, text: correctedBlocks[0]!);
          _isAiEnhancing = false;
          _hasChanges = true;
        });
        ToastUtil.success('AI强化完成');
      } else {
        setState(() => _isAiEnhancing = false);
        ToastUtil.info('AI强化完成，无需修改');
      }
    } catch (e) {
      setState(() => _isAiEnhancing = false);
      ToastUtil.error('AI强化失败: $e');
    }
  }

  Future<void> _aiEnhanceAllBlocks() async {
    if (widget.imageFile == null) {
      ToastUtil.error('没有图片文件');
      return;
    }
    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    if (visibleBlocks.isEmpty) return;

    setState(() {
      _isAiEnhancing = true;
      _progressText = 'AI正在优化识别结果...';
    });

    try {
      final vision = await _ensureVisionDescription();
      final blocksData = <Map<int, String>>[];
      for (int i = 0; i < visibleBlocks.length; i++) {
        if (visibleBlocks[i].originalText == null) {
          visibleBlocks[i] =
              visibleBlocks[i].copyWith(originalText: visibleBlocks[i].text);
        }
        blocksData.add({i: visibleBlocks[i].text});
      }

      final correctedBlocks = await AiService.instance.enhanceTextBlocks(
        widget.imageFile!,
        blocksData,
        _currentAiModel,
        onProgress: (msg) => setState(() => _progressText = msg),
        visionDescription: vision,
      );

      int updatedCount = 0;
      for (int i = 0; i < visibleBlocks.length; i++) {
        if (correctedBlocks[i] != null) {
          visibleBlocks[i] = visibleBlocks[i].copyWith(
              aiEnhancedText: correctedBlocks[i]!, text: correctedBlocks[i]!);
          updatedCount++;
        }
      }

      setState(() {
        _blocks = _blocks.map((b) {
          final idx = visibleBlocks.indexWhere((v) => v.id == b.id);
          return idx != -1 ? visibleBlocks[idx] : b;
        }).toList();
        _isAiEnhancing = false;
        if (updatedCount > 0) _hasChanges = true;
      });
      ToastUtil.success('AI强化识别完成，已优化 $updatedCount 个文字块');
    } catch (e) {
      setState(() => _isAiEnhancing = false);
      ToastUtil.error('AI强化失败: ${e.toString().split('\n').first}');
    }
  }

  Future<void> _aiTranslateAllBlocks() async {
    if (widget.imageFile == null) {
      ToastUtil.error('没有图片文件');
      return;
    }
    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    if (visibleBlocks.isEmpty) return;

    setState(() {
      _isAiTranslating = true;
      _progressText = '正在翻译文本...';
    });

    try {
      if (PlatformUtils.supportsMlKit) {
        for (int i = 0; i < visibleBlocks.length; i++) {
          if (!mounted) break;
          final block = visibleBlocks[i];
          if (block.text.trim().isEmpty) continue;

          setState(() =>
              _progressText = '正在翻译第 ${i + 1}/${visibleBlocks.length} 个文本块...');
          final result = await ref
              .read(translationServiceProvider)
              .translateWithStatus(block.text);
          if (result.status == TranslationStatus.done &&
              result.translatedText != null) {
            visibleBlocks[i] =
                visibleBlocks[i].copyWith(translatedText: result.translatedText);
          }
        }
      } else {
        setState(() => _progressText = '正在准备AI翻译...');
      }

      final vision = await _ensureVisionDescription();
      final blocksWithDraft = <Map<int, String>>[];
      for (int i = 0; i < visibleBlocks.length; i++) {
        final draft = visibleBlocks[i].translatedText ?? '';
        blocksWithDraft.add({i: '${visibleBlocks[i].text}|||$draft'});
      }

      final aiTranslations = await AiService.instance.enhanceTranslation(
        widget.imageFile!,
        blocksWithDraft,
        _currentAiModel,
        onProgress: (msg) => setState(() => _progressText = msg),
        visionDescription: vision,
      );

      int translatedCount = 0;
      for (int i = 0; i < visibleBlocks.length; i++) {
        final aiTranslation = aiTranslations[i];
        if (aiTranslation != null && aiTranslation.isNotEmpty) {
          visibleBlocks[i] =
              visibleBlocks[i].copyWith(aiTranslatedText: aiTranslation);
          translatedCount++;
        }
      }

      setState(() {
        _blocks = _blocks.map((b) {
          final idx = visibleBlocks.indexWhere((v) => v.id == b.id);
          return idx != -1 ? visibleBlocks[idx] : b;
        }).toList();
        _isAiTranslating = false;
        if (translatedCount > 0) _hasChanges = true;
      });
      ToastUtil.success('AI强化翻译完成，已翻译 $translatedCount 个文字块');
    } catch (e) {
      setState(() => _isAiTranslating = false);
      ToastUtil.error('AI翻译失败: ${e.toString().split('\n').first}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OCR识别结果'),
          flexibleSpace: Container(
            decoration:
                BoxDecoration(gradient: AppTheme.appBarGradientOf(context)),
          ),
          actions: [
            if (!_isBusy &&
                visibleBlocks.isNotEmpty &&
                widget.imageFile != null) ...[
              SemanticsIconButton(
                  icon: Icons.auto_fix_high,
                  label: 'AI强化全部',
                  hint: '对所有文字块进行AI强化识别',
                  onPressed: _showAiEnhanceAllDialog),
              SemanticsIconButton(
                  icon: Icons.translate,
                  label: 'AI强化翻译',
                  hint: '对所有文字块进行AI强化翻译',
                  onPressed: _showAiTranslateDialog),
            ],
          ],
        ),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isBusy,
              child: Opacity(
                opacity: _isBusy ? 0.6 : 1.0,
                child: visibleBlocks.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: visibleBlocks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) => BlockCard(
                          block: visibleBlocks[index],
                          index: index,
                          isBusy: _isBusy,
                          hasImageFile: widget.imageFile != null,
                          onEdit: () => _editBlock(index),
                          onDelete: () => _deleteBlock(index),
                          onAiEnhance: () => _showAiEnhanceDialog(index),
                          onPlay: () => ref
                              .read(ttsProvider.notifier)
                              .speak(visibleBlocks[index].text),
                          onUseOriginal: () => _useOriginalText(index),
                          onUseAiText: () => _useAiText(index),
                          onEditTranslation: () => _editTranslation(index),
                        ),
                      ),
              ),
            ),
            if (_isBusy)
              ProgressOverlay(
                  text: _progressText, color: AppTheme.primaryOf(context)),
          ],
        ),
        floatingActionButton: Semantics(
          label: '确认返回',
          hint: '确认结果并返回上一页',
          button: true,
          child: FloatingActionButton.extended(
            onPressed: _isBusy ? null : () => Navigator.pop(context, _blocks),
            icon: const Icon(Icons.check),
            label: const Text('确认返回'),
            backgroundColor: AppTheme.primaryOf(context),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final mutedColor = AppTheme.mutedOf(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.text_fields,
              size: 64, color: mutedColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('没有识别到文字块', style: TextStyle(fontSize: 16, color: mutedColor)),
        ],
      ),
    );
  }
}
