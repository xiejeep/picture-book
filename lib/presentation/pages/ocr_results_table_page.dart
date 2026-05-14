import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/toast_util.dart';
import '../../core/constants/constants.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/translation_service.dart';
import '../features/text_detection/text_detection.dart';
import '../providers/tts_provider.dart';

class OcrResultsTablePage extends ConsumerStatefulWidget {
  final List<TextBlockData> textBlocks;
  final File? imageFile;

  const OcrResultsTablePage({
    super.key,
    required this.textBlocks,
    this.imageFile,
  });

  @override
  ConsumerState<OcrResultsTablePage> createState() => _OcrResultsTablePageState();
}

class _OcrResultsTablePageState extends ConsumerState<OcrResultsTablePage> {
  late List<TextBlockData> _blocks;
  bool _isAiEnhancing = false;
  bool _isAiTranslating = false;
  String _progressText = 'AI正在优化识别结果...';
  String _currentAiModel = AppConstants.defaultModel;
  String? _cachedVisionDescription;

  @override
  void initState() {
    super.initState();
    _blocks = widget.textBlocks;
    _loadCurrentModel();
  }

  void _loadCurrentModel() {
    final savedModel = AiService.instance.getSelectedModel();
    final modelExists = AppConstants.availableModels.any((m) => m['name'] == savedModel);
    _currentAiModel = modelExists ? savedModel : AppConstants.defaultModel;
  }

  int _findRealIndex(int visibleIndex) {
    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    final targetBlock = visibleBlocks[visibleIndex];
    return _blocks.indexOf(targetBlock);
  }

  bool get _isBusy => _isAiEnhancing || _isAiTranslating;

  Future<String> _ensureVisionDescription() async {
    if (_cachedVisionDescription != null) {
      debugPrint('复用已缓存的视觉描述');
      return _cachedVisionDescription!;
    }
    if (widget.imageFile == null) {
      throw Exception('没有图片文件');
    }
    setState(() {
      _progressText = 'AI正在理解图片内容...';
    });
    _cachedVisionDescription = await AiService.instance.extractVisionText(
      widget.imageFile!, _currentAiModel,
    );
    debugPrint('视觉描述已缓存');
    return _cachedVisionDescription!;
  }

  void _editBlock(int visibleIndex) {
    final realIndex = _findRealIndex(visibleIndex);
    final block = _blocks[realIndex];
    final controller = TextEditingController(text: block.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
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
                    '编辑文字块 #${visibleIndex + 1}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warmBrown,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (block.originalText != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.text_fields, size: 16, color: Colors.blue),
                          SizedBox(width: 6),
                          Text(
                            'OCR原始识别',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        block.originalText!,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (block.aiEnhancedText != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_fix_high, size: 16, color: Colors.purple),
                          SizedBox(width: 6),
                          Text(
                            'AI优化结果',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        block.aiEnhancedText!,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '最终文本',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final newText = controller.text;
                      if (newText != block.text) {
                        setState(() {
                          _blocks[realIndex].text = newText;
                          _blocks[realIndex].translatedText = null;
                          _blocks[realIndex].aiTranslatedText = null;
                        });
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _useAiText(int visibleIndex) {
    final realIndex = _findRealIndex(visibleIndex);
    final block = _blocks[realIndex];
    if (block.aiEnhancedText != null) {
      setState(() {
        _blocks[realIndex].text = block.aiEnhancedText!;
      });
    }
  }

  void _useOriginalText(int visibleIndex) {
    final realIndex = _findRealIndex(visibleIndex);
    final block = _blocks[realIndex];
    if (block.originalText != null) {
      setState(() {
        _blocks[realIndex].text = block.originalText!;
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
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _blocks[realIndex].isDeleted = true;
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
    final hasApiKey = await AiService.instance.hasApiKey();
    if (!hasApiKey) {
      ToastUtil.warning('请先在设置中配置API Key');
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
            _buildPrivacyNotice(),
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
      await _aiEnhanceBlock(visibleIndex);
    }
  }

  Future<void> _showAiEnhanceAllDialog() async {
    final hasApiKey = await AiService.instance.hasApiKey();
    if (!hasApiKey) {
      ToastUtil.warning('请先在首页AI设置中配置API Key');
      return;
    }

    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
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
            _buildPrivacyNotice(),
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
      await _aiEnhanceAllBlocks();
    }
  }

  Future<void> _showAiTranslateDialog() async {
    final hasApiKey = await AiService.instance.hasApiKey();
    if (!hasApiKey) {
      ToastUtil.warning('请先在首页AI设置中配置API Key');
      return;
    }

    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    if (visibleBlocks.isEmpty) {
      ToastUtil.warning('没有可翻译的文字块');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI强化翻译'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrivacyNotice(),
            const SizedBox(height: 12),
            Text('将对${visibleBlocks.length}个文字块进行翻译：\n\n'
                '1. 使用ML Kit生成草稿翻译\n'
                '2. 由AI结合图片语境优化翻译'),
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
      await _aiTranslateAllBlocks();
    }
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                '隐私提示',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '使用AI功能时，您的文本和图片将发送给第三方AI服务商（智谱AI）进行处理。',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          SizedBox(height: 4),
          Text(
            '提示：AI识别结果可能不完全准确，建议手动检查和修改。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _aiEnhanceBlock(int visibleIndex) async {
    final realIndex = _findRealIndex(visibleIndex);
    if (widget.imageFile == null) {
      ToastUtil.error('没有图片文件，无法进行AI强化');
      return;
    }

    setState(() {
      _isAiEnhancing = true;
      _progressText = 'AI正在优化识别结果...';
    });

    try {
      final vision = await _ensureVisionDescription();

      final block = _blocks[realIndex];
      block.originalText ??= block.text;

      final blocksData = [{0: block.text}];

      final correctedBlocks = await AiService.instance.enhanceTextBlocks(
        widget.imageFile!,
        blocksData,
        _currentAiModel,
        onProgress: (msg) {
          setState(() => _progressText = msg);
        },
        visionDescription: vision,
      );

      final correctedText = correctedBlocks[0];
      if (correctedText != null) {
        setState(() {
          _blocks[realIndex].aiEnhancedText = correctedText;
          _blocks[realIndex].text = correctedText;
          _isAiEnhancing = false;
        });
        ToastUtil.success('AI强化完成');
      } else {
        setState(() {
          _isAiEnhancing = false;
        });
        ToastUtil.info('AI强化完成，无需修改');
      }
    } catch (e) {
      setState(() {
        _isAiEnhancing = false;
      });
      ToastUtil.error('AI强化失败: $e');
    }
  }

  Future<void> _aiEnhanceAllBlocks() async {
    if (widget.imageFile == null) {
      ToastUtil.error('没有图片文件，无法进行AI强化');
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
        visibleBlocks[i].originalText ??= visibleBlocks[i].text;
        blocksData.add({i: visibleBlocks[i].text});
      }

      final correctedBlocks = await AiService.instance.enhanceTextBlocks(
        widget.imageFile!,
        blocksData,
        _currentAiModel,
        onProgress: (msg) {
          setState(() => _progressText = msg);
        },
        visionDescription: vision,
      );

      int updatedCount = 0;
      for (int i = 0; i < visibleBlocks.length; i++) {
        final correctedText = correctedBlocks[i];
        if (correctedText != null) {
          visibleBlocks[i].aiEnhancedText = correctedText;
          visibleBlocks[i].text = correctedText;
          updatedCount++;
        }
      }

      setState(() {
        _isAiEnhancing = false;
      });

      ToastUtil.success('AI强化识别完成，已优化 $updatedCount 个文字块');
    } catch (e) {
      setState(() {
        _isAiEnhancing = false;
      });
      ToastUtil.error('AI强化失败: ${e.toString().split('\n').first}');
    }
  }

  Future<void> _aiTranslateAllBlocks() async {
    if (widget.imageFile == null) {
      ToastUtil.error('没有图片文件，无法进行AI翻译');
      return;
    }

    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    if (visibleBlocks.isEmpty) return;

    setState(() {
      _isAiTranslating = true;
      _progressText = '正在翻译文本...';
    });

    try {
      for (int i = 0; i < visibleBlocks.length; i++) {
        if (!mounted) break;
        final block = visibleBlocks[i];
        if (block.text.trim().isEmpty) continue;

        setState(() {
          _progressText = '正在翻译第 ${i + 1}/${visibleBlocks.length} 个文本块...';
        });

        final result = await TranslationService.instance.translateWithStatus(block.text);

        if (result.status == TranslationStatus.downloadingModel) {
          setState(() {
            _progressText = '正在下载翻译模型...';
          });
        }

        if (result.status == TranslationStatus.done && result.translatedText != null) {
          visibleBlocks[i].translatedText = result.translatedText;
        }
      }

      final vision = await _ensureVisionDescription();

      final blocksWithDraft = <Map<int, String>>[];
      for (int i = 0; i < visibleBlocks.length; i++) {
        final block = visibleBlocks[i];
        final draft = block.translatedText ?? '';
        blocksWithDraft.add({i: '${block.text}|||$draft'});
      }

      final aiTranslations = await AiService.instance.enhanceTranslation(
        widget.imageFile!,
        blocksWithDraft,
        _currentAiModel,
        onProgress: (msg) {
          setState(() => _progressText = msg);
        },
        visionDescription: vision,
      );

      int translatedCount = 0;
      for (int i = 0; i < visibleBlocks.length; i++) {
        final aiTranslation = aiTranslations[i];
        if (aiTranslation != null && aiTranslation.isNotEmpty) {
          visibleBlocks[i].aiTranslatedText = aiTranslation;
          translatedCount++;
        }
      }

      setState(() {
        _isAiTranslating = false;
      });

      ToastUtil.success('AI强化翻译完成，已翻译 $translatedCount 个文字块');
    } catch (e) {
      setState(() {
        _isAiTranslating = false;
      });
      ToastUtil.error('AI翻译失败: ${e.toString().split('\n').first}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    final hasAiResults = visibleBlocks.any((b) => b.aiEnhancedText != null);
    final hasTranslations = visibleBlocks.any((b) => b.translatedText != null || b.aiTranslatedText != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR识别结果'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppTheme.calmBlue,
                AppTheme.gentleGreen,
              ],
            ),
          ),
        ),
        actions: [
          if (!_isBusy && visibleBlocks.isNotEmpty && widget.imageFile != null) ...[
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              tooltip: 'AI强化全部',
              onPressed: _showAiEnhanceAllDialog,
            ),
            IconButton(
              icon: const Icon(Icons.translate),
              tooltip: 'AI强化翻译',
              onPressed: _showAiTranslateDialog,
            ),
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.text_fields, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        '没有识别到文字块',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (hasAiResults)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.08),
                          border: Border(
                            bottom: BorderSide(color: Colors.purple.withOpacity(0.15)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_fix_high, size: 18, color: Colors.purple),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${visibleBlocks.where((b) => b.aiEnhancedText != null).length} 个文字块已使用AI优化',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.purple,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasTranslations)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.08),
                          border: Border(
                            bottom: BorderSide(color: Colors.teal.withOpacity(0.15)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.translate, size: 18, color: Colors.teal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${visibleBlocks.where((b) => b.aiTranslatedText != null || b.translatedText != null).length} 个文字块已翻译',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: visibleBlocks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final block = visibleBlocks[index];
                          final hasAi = block.aiEnhancedText != null;
                          final hasDraft = block.translatedText != null;
                          final hasAiTrans = block.aiTranslatedText != null;

                          return Slidable(
                            key: ValueKey(block.id),
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _deleteBlock(index),
                                  backgroundColor: const Color(0xFFFF6B6B),
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_rounded,
                                  label: '删除',
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ],
                            ),
                            child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: hasAi
                                  ? BorderSide(color: Colors.purple.withOpacity(0.3), width: 1.5)
                                  : BorderSide.none,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _editBlock(index),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              if (hasAi)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.purple.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.auto_fix_high, size: 12, color: Colors.purple),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'AI优化',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.purple,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (hasAiTrans)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 4),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.translate, size: 12, color: Colors.amber),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'AI翻译',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.amber,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (!_isBusy && widget.imageFile != null)
                                          IconButton(
                                            icon: const Icon(Icons.auto_fix_high, size: 18),
                                            tooltip: 'AI强化此块',
                                            onPressed: () => _showAiEnhanceDialog(index),
                                            color: Colors.purple,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.volume_up, size: 18),
                                          tooltip: '播放',
                                          onPressed: () => ref.read(ttsProvider.notifier).speak(block.text),
                                          color: AppTheme.primaryColor,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (hasAi && block.originalText != null) ...[
                                      _buildInfoContainer(
                                        icon: Icons.text_fields,
                                        iconColor: Colors.blue,
                                        label: 'OCR原始',
                                        text: block.originalText!,
                                        bgColor: Colors.blue.withOpacity(0.06),
                                        borderColor: Colors.blue.withOpacity(0.12),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    _buildInfoContainer(
                                      icon: hasAi ? Icons.auto_fix_high : Icons.text_snippet,
                                      iconColor: hasAi ? Colors.purple : Colors.grey.shade600,
                                      label: hasAi ? 'AI优化结果' : '识别结果',
                                      text: block.text,
                                      bgColor: hasAi
                                          ? Colors.purple.withOpacity(0.04)
                                          : AppTheme.lightGray.withOpacity(0.5),
                                      borderColor: hasAi
                                          ? Colors.purple.withOpacity(0.15)
                                          : Colors.grey.withOpacity(0.15),
                                    ),
                                    if (hasAiTrans) ...[
                                      const SizedBox(height: 8),
                                      _buildInfoContainer(
                                        icon: Icons.auto_awesome,
                                        iconColor: Colors.amber.shade700,
                                        label: 'AI优化翻译',
                                        text: block.aiTranslatedText!,
                                        bgColor: Colors.amber.withOpacity(0.06),
                                        borderColor: Colors.amber.withOpacity(0.12),
                                      ),
                                    ] else if (hasDraft) ...[
                                      const SizedBox(height: 8),
                                      _buildInfoContainer(
                                        icon: Icons.translate,
                                        iconColor: Colors.teal,
                                        label: '翻译草稿',
                                        text: block.translatedText!,
                                        bgColor: Colors.teal.withOpacity(0.06),
                                        borderColor: Colors.teal.withOpacity(0.12),
                                      ),
                                    ],
                                    if (hasAi || hasDraft || hasAiTrans) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (block.originalText != null && block.text != block.originalText)
                                            TextButton.icon(
                                              icon: const Icon(Icons.undo, size: 16),
                                              label: const Text('使用原文', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _useOriginalText(index),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.blue,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              ),
                                            ),
                                          if (block.aiEnhancedText != null && block.text != block.aiEnhancedText)
                                            TextButton.icon(
                                              icon: const Icon(Icons.auto_fix_high, size: 16),
                                              label: const Text('使用AI结果', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _useAiText(index),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.purple,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              ),
                                            ),
                                          TextButton.icon(
                                            icon: const Icon(Icons.edit, size: 16),
                                            label: const Text('编辑', style: TextStyle(fontSize: 12)),
                                            onPressed: () => _editBlock(index),
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppTheme.primaryColor,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          ),
          ),
          if (_isBusy)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: (_isAiTranslating ? Colors.teal : Colors.purple).withOpacity(0.9),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _progressText,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBusy ? null : () => Navigator.pop(context, _blocks),
        icon: const Icon(Icons.check),
        label: const Text('确认返回'),
        backgroundColor: AppTheme.gentleGreen,
      ),
    );
  }

  Widget _buildInfoContainer({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String text,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
