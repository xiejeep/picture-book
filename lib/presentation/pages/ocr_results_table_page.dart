import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/constants.dart';
import '../../data/services/ai_service.dart';
import 'text_detection_page.dart';

class OcrResultsTablePage extends StatefulWidget {
  final List<TextBlockData> textBlocks;
  final File? imageFile;

  const OcrResultsTablePage({
    super.key,
    required this.textBlocks,
    this.imageFile,
  });

  @override
  State<OcrResultsTablePage> createState() => _OcrResultsTablePageState();
}

class _OcrResultsTablePageState extends State<OcrResultsTablePage> {
  late List<TextBlockData> _blocks;
  bool _isAiEnhancing = false;
  String _currentAiModel = AppConstants.defaultModel;

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
                      setState(() {
                        _blocks[realIndex].text = controller.text;
                      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置API Key'), backgroundColor: Colors.orange),
      );
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
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
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
                  const SizedBox(height: 8),
                  const Text(
                    '使用AI功能时，您的文本和图片将发送给第三方AI服务商（智谱AI）进行处理。',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '提示：AI识别结果可能不完全准确，建议手动检查和修改。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
      await _aiEnhanceBlock(visibleIndex);
    }
  }

  Future<void> _aiEnhanceBlock(int visibleIndex) async {
    final realIndex = _findRealIndex(visibleIndex);
    if (widget.imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有图片文件，无法进行AI强化'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isAiEnhancing = true;
    });

    try {
      final block = _blocks[realIndex];
      block.originalText ??= block.text;
      
      final blocksData = [{0: block.text}];
      
      final correctedBlocks = await AiService.instance.enhanceTextBlocks(
        widget.imageFile!,
        blocksData,
        _currentAiModel,
      );

      final correctedText = correctedBlocks[0];
      if (correctedText != null) {
        setState(() {
          _blocks[realIndex].aiEnhancedText = correctedText;
          _blocks[realIndex].text = correctedText;
          _isAiEnhancing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI强化完成'), backgroundColor: Colors.green),
        );
      } else {
        setState(() {
          _isAiEnhancing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI强化完成，无需修改'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      setState(() {
        _isAiEnhancing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI强化失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showAiEnhanceAllDialog() async {
    final hasApiKey = await AiService.instance.hasApiKey();
    if (!hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先在首页AI设置中配置API Key'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    if (visibleBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可优化的文字块')),
      );
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
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
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
                  const SizedBox(height: 8),
                  const Text(
                    '使用AI功能时，您的文本和图片将发送给第三方AI服务商（智谱AI）进行处理。',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '提示：AI识别结果可能不完全准确，建议手动检查和修改。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
      await _aiEnhanceAllBlocks();
    }
  }

  Future<void> _aiEnhanceAllBlocks() async {
    if (widget.imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有图片文件，无法进行AI强化'), backgroundColor: Colors.red),
      );
      return;
    }

    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    if (visibleBlocks.isEmpty) return;

    setState(() {
      _isAiEnhancing = true;
    });

    try {
      final blocksData = <Map<int, String>>[];
      for (int i = 0; i < visibleBlocks.length; i++) {
        visibleBlocks[i].originalText ??= visibleBlocks[i].text;
        blocksData.add({i: visibleBlocks[i].text});
      }

      final correctedBlocks = await AiService.instance.enhanceTextBlocks(
        widget.imageFile!,
        blocksData,
        _currentAiModel,
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI强化识别完成，已优化 $updatedCount 个文字块'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isAiEnhancing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI强化失败: ${e.toString().split('\n').first}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleBlocks = _blocks.where((b) => !b.isDeleted).toList();
    final hasAiResults = visibleBlocks.any((b) => b.aiEnhancedText != null);

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
          if (!_isAiEnhancing && visibleBlocks.isNotEmpty && widget.imageFile != null)
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              tooltip: 'AI强化全部',
              onPressed: _showAiEnhanceAllDialog,
            ),
        ],
      ),
      body: Stack(
        children: [
          visibleBlocks.isEmpty
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
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: visibleBlocks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final block = visibleBlocks[index];
                          final hasAi = block.aiEnhancedText != null;

                          return Card(
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
                                            ],
                                          ),
                                        ),
                                        if (!_isAiEnhancing && widget.imageFile != null)
                                          IconButton(
                                            icon: const Icon(Icons.auto_fix_high, size: 18),
                                            tooltip: 'AI强化此块',
                                            onPressed: () => _showAiEnhanceDialog(index),
                                            color: Colors.purple,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18),
                                          tooltip: '删除',
                                          onPressed: () => _deleteBlock(index),
                                          color: Colors.red,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (hasAi && block.originalText != null) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.blue.withOpacity(0.12)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                Icon(Icons.text_fields, size: 14, color: Colors.blue),
                                                SizedBox(width: 4),
                                                Text(
                                                  'OCR原始',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              block.originalText!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.black.withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: hasAi
                                            ? Colors.purple.withOpacity(0.04)
                                            : AppTheme.lightGray.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: hasAi
                                              ? Colors.purple.withOpacity(0.15)
                                              : Colors.grey.withOpacity(0.15),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                hasAi ? Icons.auto_fix_high : Icons.text_snippet,
                                                size: 14,
                                                color: hasAi ? Colors.purple : Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                hasAi ? 'AI优化结果' : '识别结果',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: hasAi ? Colors.purple : Colors.grey.shade600,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            block.text,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (hasAi) ...[
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
                          );
                        },
                      ),
                    ),
                  ],
                ),
          if (_isAiEnhancing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.9),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: const Row(
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
                    Text(
                      'AI正在优化识别结果...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context, _blocks),
        icon: const Icon(Icons.check),
        label: const Text('确认返回'),
        backgroundColor: AppTheme.gentleGreen,
      ),
    );
  }
}