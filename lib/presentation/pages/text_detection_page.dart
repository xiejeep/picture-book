import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/ai_settings_model.dart';
import '../../core/constants/constants.dart';
import '../../core/theme/app_theme.dart';
import 'ocr_results_table_page.dart';
import 'voice_settings_page.dart';

enum HandlePosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

class TextBlockData {
  Rect boundingBox;
  String text;
  bool isDeleted;
  String? originalText;
  String? aiEnhancedText;

  TextBlockData({
    required this.boundingBox,
    required this.text,
    this.isDeleted = false,
    this.originalText,
    this.aiEnhancedText,
  });
}

class TextDetectionPage extends StatefulWidget {
  final Function(List<TextBlockData>, File)? onSave;
  final File? initialImageFile;
  final List<dynamic>? initialTextBlocks;
  
  const TextDetectionPage({
    super.key,
    this.onSave,
    this.initialImageFile,
    this.initialTextBlocks,
  });

  @override
  State<TextDetectionPage> createState() => _TextDetectionPageState();
}

class _TextDetectionPageState extends State<TextDetectionPage> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService.instance;
  
  Size _imageSize = Size.zero;
  Size _displaySize = Size.zero;
  final List<TextBlockData> _textBlocks = [];
  int? _selectedIndex;
  bool _isProcessing = false;
  String? _errorMessage;

  bool _isAiEnhancing = false;
  bool _showAiBanner = false;
  String _currentAiModel = AppConstants.defaultModel;

  final TransformationController _controller = TransformationController();
  final GlobalKey _interactiveViewerKey = GlobalKey();

  bool _isDragging = false;
  bool _isResizing = false;
  HandlePosition? _resizeHandle;
  Offset? _dragStartPoint;
  Rect? _dragStartRect;

  bool _editModeResize = true;

  bool _isTwoFingerPan = false;
  Offset? _panStartFocalPoint;
  Matrix4? _panStartMatrix;

  bool _drawMode = false;
  Rect? _tempRect;
  Offset? _drawStartPoint;

  bool _hasChanges = false;
  double _currentSpeechRate = AppConstants.systemTtsDefaultSpeed;
  bool _currentUseGlmTts = false;

  static const double _handleSize = 40.0;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    final File imageFile = File(pickedFile.path);
    
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '编辑图片',
          toolbarColor: AppTheme.calmBlue,
          toolbarWidgetColor: Colors.white,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: '编辑图片',
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
          rotateButtonsHidden: false,
          resetButtonHidden: false,
        ),
      ],
    );

    if (croppedFile == null) return;

    final croppedImageFile = File(croppedFile.path);
    final decodedImage = await decodeImageFromList(croppedImageFile.readAsBytesSync());
    
    setState(() {
      _imageFile = croppedImageFile;
      _imageSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
      _textBlocks.clear();
      _selectedIndex = null;
      _errorMessage = null;
      _controller.value = Matrix4.identity();
    });

    await _recognizeText();
  }

  bool _isEnglishText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    
    for (final char in trimmed.split('')) {
      final codeUnit = char.codeUnitAt(0);
      if (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) {
        return false;
      }
    }
    return true;
  }

  Future<void> _showReRecognizeAllDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新识别全部'),
        content: const Text('确定要重新识别图片中的所有文字吗？\n这将覆盖当前所有的识别结果。'),
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
      await _recognizeText();
    }
  }

  Future<void> _recognizeText() async {
    if (_imageFile == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await _ocrService.recognizeText(_imageFile!);
      
      if (result == null) {
        setState(() {
          _errorMessage = '文字识别失败: 无法识别';
          _isProcessing = false;
        });
        return;
      }
      
      final blocks = result.blocks.map((block) {
        return TextBlockData(
          boundingBox: block.boundingBox,
          text: block.text,
        );
      }).toList();
      
      setState(() {
        _textBlocks.clear();
        _textBlocks.addAll(blocks);
        _selectedIndex = null;
        _isProcessing = false;
        _hasChanges = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('识别到 ${blocks.length} 个英文文字区域'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = '文字识别失败: $e';
        _isProcessing = false;
      });
    }
  }

  void _updateDisplaySize(Size containerSize) {
    if (_imageSize.isEmpty) return;
    
    final double imageAspect = _imageSize.width / _imageSize.height;
    final double containerAspect = containerSize.width / containerSize.height;
    
    if (imageAspect > containerAspect) {
      _displaySize = Size(containerSize.width, containerSize.width / imageAspect);
    } else {
      _displaySize = Size(containerSize.height * imageAspect, containerSize.height);
    }
  }

  double _getScale() {
    if (_imageSize.isEmpty || _displaySize.isEmpty) return 1.0;
    return _displaySize.width / _imageSize.width;
  }

  void _zoomIn() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.3).clamp(0.5, 4.0);
    final scaleRatio = newScale / currentScale;
    final newMatrix = _controller.value.clone();
    final renderBox =
        _interactiveViewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final centerX = renderBox.size.width / 2;
    final centerY = renderBox.size.height / 2;
    newMatrix.translate(centerX, centerY);
    newMatrix.scale(scaleRatio, scaleRatio);
    newMatrix.translate(-centerX, -centerY);
    _controller.value = newMatrix;
    setState(() {});
  }

  void _zoomOut() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.3).clamp(0.5, 4.0);
    final scaleRatio = newScale / currentScale;
    final newMatrix = _controller.value.clone();
    final renderBox =
        _interactiveViewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final centerX = renderBox.size.width / 2;
    final centerY = renderBox.size.height / 2;
    newMatrix.translate(centerX, centerY);
    newMatrix.scale(scaleRatio, scaleRatio);
    newMatrix.translate(-centerX, -centerY);
    _controller.value = newMatrix;
    setState(() {});
  }

  void _resetZoom() {
    _controller.value = Matrix4.identity();
    setState(() {});
  }

  Offset _toImagePoint(Offset screenPoint) {
    final RenderBox? renderBox =
        _interactiveViewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;

    final Offset localPoint = renderBox.globalToLocal(screenPoint);
    final Matrix4 inverse = Matrix4.inverted(_controller.value);
    final Offset transformedPoint = MatrixUtils.transformPoint(inverse, localPoint);
    
    final double scale = _getScale();
    return Offset(transformedPoint.dx / scale, transformedPoint.dy / scale);
  }

  HandlePosition? _getHandleAtPoint(Offset point, Rect rect) {
    if (!_editModeResize) return null;

    final double handleThreshold = _handleSize / _getScale();
    
    final positions = {
      HandlePosition.topLeft: rect.topLeft,
      HandlePosition.topRight: rect.topRight,
      HandlePosition.bottomLeft: rect.bottomLeft,
      HandlePosition.bottomRight: rect.bottomRight,
      HandlePosition.top: Offset(rect.center.dx, rect.top),
      HandlePosition.bottom: Offset(rect.center.dx, rect.bottom),
      HandlePosition.left: Offset(rect.left, rect.center.dy),
      HandlePosition.right: Offset(rect.right, rect.center.dy),
    };

    HandlePosition? closest;
    double closestDist = double.infinity;
    for (final entry in positions.entries) {
      final dist = (entry.value - point).distance;
      if (dist <= handleThreshold && dist < closestDist) {
        closestDist = dist;
        closest = entry.key;
      }
    }
    return closest;
  }

  bool _isDeleteButtonAtPoint(Offset point, Rect rect) {
    final double scale = _getScale();
    final double buttonSize = 24.0 / scale;
    final Offset deletePos = Offset(rect.right + buttonSize / 2, rect.top - buttonSize / 2);
    return (point - deletePos).distance <= buttonSize;
  }

  int? _findBlockAtPoint(Offset point) {
    for (int i = _textBlocks.length - 1; i >= 0; i--) {
      final block = _textBlocks[i];
      if (block.isDeleted) continue;
      if (!_isEnglishText(block.text)) continue;
      if (block.boundingBox.contains(point)) {
        return i;
      }
    }
    return null;
  }

  List<TextBlockData> _getVisibleBlocks() {
    final result = _textBlocks.where((block) {
      if (block.isDeleted) return false;
      if (!_isEnglishText(block.text)) return false;
      return true;
    }).toList();
    return result;
  }

  void _handleTapDown(TapDownDetails details) {
    if (_drawMode) return;
    
    final imagePoint = _toImagePoint(details.globalPosition);
    
    if (_selectedIndex != null && _selectedIndex! < _textBlocks.length) {
      final selectedBlock = _textBlocks[_selectedIndex!];
      
      if (_isDeleteButtonAtPoint(imagePoint, selectedBlock.boundingBox)) {
        _deleteSelectedBlock();
        return;
      }
      
      if (_editModeResize) {
        final handle = _getHandleAtPoint(imagePoint, selectedBlock.boundingBox);
        if (handle != null) {
          return;
        }
      }
    }
    
    final blockIndex = _findBlockAtPoint(imagePoint);
    setState(() {
      if (blockIndex != _selectedIndex) {
        _editModeResize = true;
      }
      _selectedIndex = blockIndex;
    });
  }

  void _toggleEditMode() {
    setState(() {
      _editModeResize = !_editModeResize;
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (details.pointerCount >= 2) {
      setState(() {
        _isTwoFingerPan = true;
        _panStartFocalPoint = details.focalPoint;
        _panStartMatrix = _controller.value.clone();
      });
      return;
    }

    _isTwoFingerPan = false;

    if (_drawMode) {
      final imagePoint = _toImagePoint(details.focalPoint);
      setState(() {
        _drawStartPoint = imagePoint;
        _tempRect = null;
      });
      return;
    }

    if (_selectedIndex == null || _selectedIndex! >= _textBlocks.length) return;
    
    final imagePoint = _toImagePoint(details.focalPoint);
    final selectedBlock = _textBlocks[_selectedIndex!];

    if (_editModeResize) {
      final handle = _getHandleAtPoint(imagePoint, selectedBlock.boundingBox);
      if (handle != null) {
        setState(() {
          _isResizing = true;
          _resizeHandle = handle;
          _dragStartPoint = imagePoint;
          _dragStartRect = selectedBlock.boundingBox;
        });
        return;
      }
    }

    if (selectedBlock.boundingBox.contains(imagePoint)) {
      setState(() {
        _isDragging = true;
        _dragStartPoint = imagePoint;
        _dragStartRect = selectedBlock.boundingBox;
      });
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isTwoFingerPan && _panStartFocalPoint != null && _panStartMatrix != null) {
      final delta = details.focalPoint - _panStartFocalPoint!;
      final currentScale = _controller.value.getMaxScaleOnAxis();
      final newMatrix = _panStartMatrix!.clone();
      newMatrix.translate(delta.dx / currentScale, delta.dy / currentScale);
      _controller.value = newMatrix;
      return;
    }

    if (_drawMode && _drawStartPoint != null) {
      final imagePoint = _toImagePoint(details.focalPoint);
      final rect = Rect.fromLTRB(
        _drawStartPoint!.dx.clamp(0.0, _imageSize.width),
        _drawStartPoint!.dy.clamp(0.0, _imageSize.height),
        imagePoint.dx.clamp(0.0, _imageSize.width),
        imagePoint.dy.clamp(0.0, _imageSize.height),
      );
      setState(() {
        _tempRect = rect;
      });
      return;
    }

    if (_selectedIndex == null || _selectedIndex! >= _textBlocks.length) return;
    
    final imagePoint = _toImagePoint(details.focalPoint);

    if (_isResizing && _resizeHandle != null && _dragStartRect != null) {
      final delta = imagePoint - _dragStartPoint!;
      final original = _dragStartRect!;
      
      Rect newRect;
      switch (_resizeHandle!) {
        case HandlePosition.topLeft:
          newRect = Rect.fromLTRB(
            original.left + delta.dx,
            original.top + delta.dy,
            original.right,
            original.bottom,
          );
          break;
        case HandlePosition.topRight:
          newRect = Rect.fromLTRB(
            original.left,
            original.top + delta.dy,
            original.right + delta.dx,
            original.bottom,
          );
          break;
        case HandlePosition.bottomLeft:
          newRect = Rect.fromLTRB(
            original.left + delta.dx,
            original.top,
            original.right,
            original.bottom + delta.dy,
          );
          break;
        case HandlePosition.bottomRight:
          newRect = Rect.fromLTRB(
            original.left,
            original.top,
            original.right + delta.dx,
            original.bottom + delta.dy,
          );
          break;
        case HandlePosition.top:
          newRect = Rect.fromLTRB(
            original.left,
            original.top + delta.dy,
            original.right,
            original.bottom,
          );
          break;
        case HandlePosition.bottom:
          newRect = Rect.fromLTRB(
            original.left,
            original.top,
            original.right,
            original.bottom + delta.dy,
          );
          break;
        case HandlePosition.left:
          newRect = Rect.fromLTRB(
            original.left + delta.dx,
            original.top,
            original.right,
            original.bottom,
          );
          break;
        case HandlePosition.right:
          newRect = Rect.fromLTRB(
            original.left,
            original.top,
            original.right + delta.dx,
            original.bottom,
          );
          break;
      }

      final clampedRect = Rect.fromLTRB(
        newRect.left.clamp(0.0, _imageSize.width),
        newRect.top.clamp(0.0, _imageSize.height),
        newRect.right.clamp(0.0, _imageSize.width),
        newRect.bottom.clamp(0.0, _imageSize.height),
      );

      setState(() {
        _textBlocks[_selectedIndex!].boundingBox = clampedRect;
      });
    } else if (_isDragging && _dragStartRect != null) {
      final delta = imagePoint - _dragStartPoint!;
      final original = _dragStartRect!;

      double newLeft = original.left + delta.dx;
      double newTop = original.top + delta.dy;

      newLeft = newLeft.clamp(0.0, _imageSize.width - original.width);
      newTop = newTop.clamp(0.0, _imageSize.height - original.height);

      final newRect = Rect.fromLTWH(newLeft, newTop, original.width, original.height);

      setState(() {
        _textBlocks[_selectedIndex!].boundingBox = newRect;
      });
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isTwoFingerPan) {
      setState(() {
        _isTwoFingerPan = false;
        _panStartFocalPoint = null;
        _panStartMatrix = null;
      });
      return;
    }

    if (_drawMode && _tempRect != null) {
      final rect = _tempRect!;
      if (rect.width > 10 && rect.height > 10) {
        final newBlock = TextBlockData(
          boundingBox: rect,
          text: '',
          isDeleted: false,
        );
        setState(() {
          _textBlocks.add(newBlock);
          _selectedIndex = _textBlocks.length - 1;
          _tempRect = null;
          _drawStartPoint = null;
          _drawMode = false;
        });
        _editSelectedBlock();
      } else {
        setState(() {
          _tempRect = null;
          _drawStartPoint = null;
        });
      }
      return;
    }

    setState(() {
      _isDragging = false;
      _isResizing = false;
      _resizeHandle = null;
      _dragStartPoint = null;
      _dragStartRect = null;
    });
  }

  void _toggleDrawMode() {
    setState(() {
      _drawMode = !_drawMode;
      if (_drawMode) {
        _selectedIndex = null;
        _tempRect = null;
        _drawStartPoint = null;
      }
    });
  }

  void _deleteSelectedBlock() {
    if (_selectedIndex == null || _selectedIndex! >= _textBlocks.length) return;

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
                _textBlocks[_selectedIndex!].isDeleted = true;
                _hasChanges = true;
                _selectedIndex = null;
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _editSelectedBlock() {
    if (_selectedIndex == null || _selectedIndex! >= _textBlocks.length) return;
    
    final block = _textBlocks[_selectedIndex!];
    
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController controller = TextEditingController(text: block.text);
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
                  onPressed: isRecognizing ? null : () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                if (_imageFile != null && !isRecognizing)
                  TextButton(
                    onPressed: () async {
                      setDialogState(() {
                        isRecognizing = true;
                        errorMessage = null;
                      });
                      
                      final recognizedText = await _ocrService.recognizeTextInRegion(
                        _imageFile!,
                        block.boundingBox,
                      );
                      
                      setDialogState(() {
                        isRecognizing = false;
                        if (recognizedText != null && recognizedText.isNotEmpty) {
                          controller.text = recognizedText;
                        } else {
                          errorMessage = '该区域未识别到文字，请手动输入';
                        }
                      });
                    },
                    child: const Text('识别此区域'),
                  ),
                TextButton(
                  onPressed: isRecognizing ? null : () {
                    setState(() {
                      _textBlocks[_selectedIndex!].text = controller.text;
                      _hasChanges = true;
                    });
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('操作指南'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                icon: Icons.zoom_in,
                color: Colors.blue,
                title: '缩放图片',
                items: [
                  '点击左侧 +/- 按钮放大/缩小',
                  '双指拖动：平移图片位置',
                  '点击适配按钮恢复原始大小',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                icon: Icons.open_with,
                color: Colors.orange,
                title: '移动文字块',
                items: [
                  '点击选中文字块',
                  '切换到"拖动"模式',
                  '单指在文字块内拖动即可移动',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                icon: Icons.open_in_full,
                color: Colors.green,
                title: '调整文字块大小',
                items: [
                  '选中文字块后默认为调整模式',
                  '拖动边角的控制点调整大小',
                  '拖动边缘中点调整单边',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                icon: Icons.edit,
                color: Colors.purple,
                title: '编辑文字',
                items: [
                  '点击右下角编辑按钮修改文字',
                  '使用菜单可重新识别或AI强化',
                  '点击删除按钮移除文字块',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                icon: Icons.draw,
                color: Colors.red,
                title: '添加新文字块',
                items: [
                  '点击顶部绘制按钮进入绘制模式',
                  '在图片上拖动绘制矩形区域',
                  '松开后输入文字内容',
                ],
              ),
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

  void _showVoiceSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.gentleGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.record_voice_over_rounded,
                          color: AppTheme.gentleGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '语音设置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warmBrown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '当前语速',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '${(_currentSpeechRate * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.gentleGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _currentSpeechRate,
                    min: _currentUseGlmTts ? AppConstants.glmTtsMinSpeed : AppConstants.systemTtsMinSpeed,
                    max: _currentUseGlmTts ? AppConstants.glmTtsMaxSpeed : AppConstants.systemTtsMaxSpeed,
                    divisions: _currentUseGlmTts ? AppConstants.glmTtsSpeedDivisions : AppConstants.systemTtsSpeedDivisions,
                    activeColor: AppTheme.gentleGreen,
                    onChanged: (value) {
                      setDialogState(() {
                        _currentSpeechRate = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currentUseGlmTts ? '慢速' : '最慢',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        _currentUseGlmTts ? '快速' : '最快',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const VoiceSettingsPage()),
                            ).then((_) {
                              _loadVoiceSettings();
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            '更多设置',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final currentSettings = StorageService.instance.getAiSettings();
                            final settings = AiSettingsModel(
                              selectedModel: currentSettings?.selectedModel ?? AppConstants.defaultModel,
                              useGlmTts: _currentUseGlmTts,
                              ttsVoice: currentSettings?.ttsVoice ?? AppConstants.defaultTtsVoice,
                              speechRate: _currentSpeechRate,
                            );
                            await StorageService.instance.saveAiSettings(settings);
                            
                            setState(() {});
                            Navigator.pop(context);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('语速已调整'),
                                backgroundColor: AppTheme.gentleGreen,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gentleGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('确定'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHelpSection({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(left: 28, top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }



  Future<void> _showReRecognizeDialog() async {
    if (_selectedIndex == null || _selectedIndex! >= _textBlocks.length) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新识别'),
        content: const Text('确定要重新识别选中区域的文字吗？\n这将覆盖当前的文字内容。'),
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
      await _reRecognizeSelectedBlock();
    }
  }

  Future<void> _reRecognizeSelectedBlock() async {
    if (_selectedIndex == null || _selectedIndex! >= _textBlocks.length || _imageFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _ocrService.recognizeText(_imageFile!);
      
      if (result == null) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('重新识别失败'), backgroundColor: Colors.red),
        );
        return;
      }
      
      final selectedRect = _textBlocks[_selectedIndex!].boundingBox;
      String bestMatch = '';
      double bestOverlap = 0;
      
      for (final block in result.blocks) {
        final intersect = selectedRect.intersect(block.boundingBox);
        if (!intersect.isEmpty) {
          final overlap = (intersect.width * intersect.height) / 
              ((selectedRect.width * selectedRect.height + block.boundingBox.width * block.boundingBox.height) / 2);
          if (overlap > bestOverlap) {
            bestOverlap = overlap;
            bestMatch = block.text;
          }
        }
      }
      
      if (bestMatch.isNotEmpty && bestOverlap > 0.3) {
        setState(() {
          _textBlocks[_selectedIndex!].text = bestMatch;
          _hasChanges = true;
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('重新识别完成'), backgroundColor: Colors.green),
        );
      } else {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到匹配的文字'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重新识别失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showAiEnhanceSelectedDialog() async {
    if (_selectedIndex == null || _selectedIndex! >= _textBlocks.length) return;
    
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
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Text(
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
                    '💡 提示：AI识别结果可能不完全准确，建议手动检查和修改。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
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
      await _aiEnhanceSelectedBlock();
    }
  }

  Future<void> _aiEnhanceSelectedBlock() async {
    if (_selectedIndex == null || _selectedIndex! >= _textBlocks.length || _imageFile == null) return;

    setState(() {
      _isAiEnhancing = true;
      _showAiBanner = true;
    });

    try {
      final block = _textBlocks[_selectedIndex!];
      final blocksData = [{0: block.text}];

      final correctedBlocks = await AiService.instance.enhanceTextBlocks(
        _imageFile!,
        blocksData,
        _currentAiModel,
      );

      final correctedText = correctedBlocks[0];
      if (correctedText != null) {
        setState(() {
          _textBlocks[_selectedIndex!].originalText ??= _textBlocks[_selectedIndex!].text;
          _textBlocks[_selectedIndex!].aiEnhancedText = correctedText;
          _textBlocks[_selectedIndex!].text = correctedText;
          _hasChanges = true;
          _isAiEnhancing = false;
          _showAiBanner = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI强化完成（如需修改请点击编辑按钮）'), backgroundColor: Colors.green),
        );
      } else {
        setState(() {
          _isAiEnhancing = false;
          _showAiBanner = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI强化完成，无需修改'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      setState(() {
        _isAiEnhancing = false;
        _showAiBanner = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI强化失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的修改'),
        content: const Text('您有未保存的修改，确定要退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    return confirm ?? false;
  }

  void _copySelectedText() {
    if (_selectedIndex == null) return;
    
    final block = _textBlocks[_selectedIndex!];
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制: ${block.text.length > 50 ? '${block.text.substring(0, 50)}...' : block.text}'),
        action: SnackBarAction(
          label: '查看全部',
          onPressed: () => _showFullText(block.text),
        ),
      ),
    );
  }

  void _copyAllText() {
    final visibleBlocks = _getVisibleBlocks();
    if (visibleBlocks.isEmpty) return;
    
    final allText = visibleBlocks.map((block) => block.text).join('\n');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制 ${visibleBlocks.length} 个文字块'),
        action: SnackBarAction(
          label: '查看全部',
          onPressed: () => _showFullText(allText),
        ),
      ),
    );
  }

  void _showFullText(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('识别的文字'),
        content: SingleChildScrollView(
          child: SelectableText(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _saveToBook() {
    if (widget.onSave == null || _imageFile == null) return;
    
    final visibleBlocks = _getVisibleBlocks();
    if (visibleBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可保存的文字块')),
      );
      return;
    }
    
    debugPrint('=== _saveToBook ===');
    debugPrint('准备保存的块数: ${visibleBlocks.length}');
    for (int i = 0; i < visibleBlocks.length; i++) {
      debugPrint('  保存[$i]: text="${visibleBlocks[i].text}", rect=${visibleBlocks[i].boundingBox}');
    }
    
    setState(() {
      _hasChanges = false;
    });
    
    widget.onSave!(visibleBlocks, _imageFile!);
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

    final visibleBlocks = _getVisibleBlocks();
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
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Text(
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
                    '💡 提示：AI识别结果可能不完全准确，建议手动检查和修改。',
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
      await _aiEnhanceBlocks();
    }
  }

  Future<void> _aiEnhanceBlocks() async {
    final visibleBlocks = _getVisibleBlocks();
    if (visibleBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可优化的文字块')),
      );
      return;
    }

    debugPrint('=== _aiEnhanceBlocks 开始 ===');
    debugPrint('visibleBlocks数量: ${visibleBlocks.length}');
    for (int i = 0; i < visibleBlocks.length; i++) {
      debugPrint('  visibleBlocks[$i] 原文: "${visibleBlocks[i].text}"');
    }

    setState(() {
      _isAiEnhancing = true;
      _showAiBanner = true;
    });

    try {
      final blocksData = <Map<int, String>>[];
      for (int i = 0; i < visibleBlocks.length; i++) {
        blocksData.add({i: visibleBlocks[i].text});
        debugPrint('  blocksData添加: {$i: "${visibleBlocks[i].text}"}');
      }

      debugPrint('调用AI服务...');
      final correctedBlocks = await AiService.instance.enhanceTextBlocks(
        _imageFile!,
        blocksData,
        _currentAiModel,
      );
      
      debugPrint('=== AI返回结果 ===');
      correctedBlocks.forEach((key, value) {
        debugPrint('  AI返回[$key]: "$value"');
      });
      
      int updatedCount = 0;
      for (int i = 0; i < visibleBlocks.length; i++) {
        final correctedText = correctedBlocks[i];
        debugPrint('处理visibleBlocks[$i]: 原文="${visibleBlocks[i].text}", AI修正="$correctedText"');
        if (correctedText != null) {
          visibleBlocks[i].originalText ??= visibleBlocks[i].text;
          visibleBlocks[i].aiEnhancedText = correctedText;
          if (correctedText != visibleBlocks[i].text) {
            visibleBlocks[i].text = correctedText;
            updatedCount++;
          }
        }
      }

      debugPrint('=== _aiEnhanceBlocks 结束，更新了 $updatedCount 个块 ===');
      debugPrint('原始_blocks当前状态:');
      for (int i = 0; i < _textBlocks.length; i++) {
        debugPrint('  _textBlocks[$i]: text="${_textBlocks[i].text}", isDeleted=${_textBlocks[i].isDeleted}');
      }

      setState(() {
        _isAiEnhancing = false;
        _showAiBanner = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI强化识别完成，已优化 $updatedCount 个文字块（可手动编辑修改）'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
debugPrint('=== _aiEnhanceBlocks 异常: $e ===');
setState(() {
_isAiEnhancing = false;
_showAiBanner = false;
});

final errorMsg = e.toString();
final isCountMismatch = errorMsg.contains('AI返回') && errorMsg.contains('缺失的index');

if (isCountMismatch) {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: const Row(
children: [
Icon(Icons.error, color: Colors.red),
SizedBox(width: 8),
Text('AI强化失败'),
],
),
content: SingleChildScrollView(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
const Text(
'⚠️ 数量不匹配错误',
style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
),
const SizedBox(height: 12),
const Text('可能原因：', style: TextStyle(fontWeight: FontWeight.bold)),
const Text('• AI错误合并了多行文本块'),
const Text('• AI跳过了某些index'),
const SizedBox(height: 12),
const Text('错误详情：', style: TextStyle(fontWeight: FontWeight.bold)),
const SizedBox(height: 4),
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: Colors.grey.shade200,
borderRadius: BorderRadius.circular(4),
),
child: Text(
errorMsg,
style: const TextStyle(fontSize: 12),
),
),
const SizedBox(height: 12),
const Text('💡 解决方法：', style: TextStyle(fontWeight: FontWeight.bold)),
const Text('1. 点击"重试"重新处理'),
const Text('2. 或手动编辑缺失的文本块'),
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('取消'),
),
ElevatedButton.icon(
icon: const Icon(Icons.refresh),
label: const Text('重试'),
style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
onPressed: () {
Navigator.pop(context);
_aiEnhanceBlocks();
},
),
],
),
);
} else {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('AI强化失败: ${errorMsg.split('\n').first}'),
backgroundColor: Colors.red,
duration: const Duration(seconds: 4),
action: SnackBarAction(
label: '详情',
onPressed: () {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: const Text('错误详情'),
content: SingleChildScrollView(child: Text(errorMsg)),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('关闭'),
),
],
),
);
},
),
),
);
}
}
  }

@override
  void initState() {
    super.initState();
    TtsService.instance.initialize();
    _loadVoiceSettings();
    if (widget.initialImageFile != null) {
      _loadInitialData();
    }
    _loadCurrentModel();
  }

  void _loadVoiceSettings() {
    final settings = StorageService.instance.getAiSettings();
    setState(() {
      _currentUseGlmTts = settings?.useGlmTts ?? false;
      if (settings?.speechRate != null && settings!.speechRate > 0) {
        _currentSpeechRate = settings.speechRate;
      } else {
        _currentSpeechRate = _currentUseGlmTts
            ? AppConstants.glmTtsDefaultSpeed
            : AppConstants.systemTtsDefaultSpeed;
      }
    });
  }

  Future<void> _navigateToResultsTable() async {
    final visibleBlocks = _getVisibleBlocks();
    if (visibleBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可展示的文字块')),
      );
      return;
    }

    final result = await Navigator.push<List<TextBlockData>>(
      context,
      MaterialPageRoute(
        builder: (context) => OcrResultsTablePage(
          textBlocks: visibleBlocks,
          imageFile: _imageFile,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        for (final updated in result) {
          final idx = _textBlocks.indexWhere((b) =>
              !b.isDeleted &&
              b.boundingBox == updated.boundingBox);
          if (idx != -1) {
            _textBlocks[idx].text = updated.text;
            _textBlocks[idx].originalText = updated.originalText;
            _textBlocks[idx].aiEnhancedText = updated.aiEnhancedText;
            _textBlocks[idx].isDeleted = updated.isDeleted;
          }
        }
        _hasChanges = true;
      });
    }
  }

  void _loadCurrentModel() {
    final savedModel = AiService.instance.getSelectedModel();
    final modelExists = AppConstants.availableModels.any((m) => m['name'] == savedModel);
    setState(() {
      _currentAiModel = modelExists ? savedModel : AppConstants.defaultModel;
    });
  }

  Future<void> _showModelSelectionDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择AI强化模型'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppConstants.availableModels.map((model) {
              final isSelected = _currentAiModel == model['name'];
              final isFree = model['free'] == 'true';
              
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Colors.green : Colors.grey,
                ),
                title: Text(model['label']!),
                subtitle: isFree 
                    ? const Text('免费大模型', style: TextStyle(fontSize: 12))
                    : const Text('付费大模型', style: TextStyle(fontSize: 12, color: Colors.grey)),
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

    if (result != null && result != _currentAiModel) {
      setState(() {
        _currentAiModel = result;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已切换到 ${AppConstants.availableModels.firstWhere(
            (m) => m['name'] == result,
            orElse: () => AppConstants.availableModels.first,
          )['label']}'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _playSelectedBlock() async {
    if (_selectedIndex == null || _selectedIndex! >= _textBlocks.length) return;
    
    final block = _textBlocks[_selectedIndex!];
    if (block.isDeleted) return;
    
    debugPrint('播放选中文字块: "${block.text}"');
    await TtsService.instance.speak(block.text);
  }

  Future<void> _loadInitialData() async {
    final imageFile = widget.initialImageFile!;
    final decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());
    
    setState(() {
      _imageFile = imageFile;
      _imageSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
      _controller.value = Matrix4.identity();
    });

    debugPrint('=== _loadInitialData ===');
    if (widget.initialTextBlocks != null) {
      debugPrint('加载初始块数: ${widget.initialTextBlocks!.length}');
      for (int i = 0; i < widget.initialTextBlocks!.length; i++) {
        final blockMap = widget.initialTextBlocks![i] as Map<String, dynamic>;
        debugPrint('  初始[$i]: text="${blockMap['text']}", isDeleted=${blockMap['isDeleted']}, rect=${blockMap['boundingBox']}');
      }
      
      for (final block in widget.initialTextBlocks!) {
        final blockMap = block as Map<String, dynamic>;
        _textBlocks.add(TextBlockData(
          boundingBox: blockMap['boundingBox'] as Rect,
          text: blockMap['text'] as String,
          isDeleted: blockMap['isDeleted'] as bool? ?? false,
        ));
      }
      
      debugPrint('加载后_textBlocks状态:');
      for (int i = 0; i < _textBlocks.length; i++) {
        debugPrint('  _textBlocks[$i]: text="${_textBlocks[i].text}", isDeleted=${_textBlocks[i].isDeleted}');
      }
      
      setState(() {});
    } else {
      debugPrint('无初始块数据，执行识别');
      await _recognizeText();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleBlocks = _getVisibleBlocks();
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('识别'),
              if (_drawMode)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.honeyYellow.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '绘制模式',
                    style: TextStyle(color: AppTheme.honeyYellow, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
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
            if (_imageFile != null)
              IconButton(
                icon: const Icon(Icons.record_voice_over_rounded),
                onPressed: _showVoiceSettingsDialog,
                tooltip: '语音设置',
              ),
            if (_imageFile != null)
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: _showHelpDialog,
                tooltip: '操作指南',
              ),
            if (_imageFile != null && visibleBlocks.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.table_chart),
                onPressed: _navigateToResultsTable,
                tooltip: '查看结果表格',
              ),
            if (_imageFile != null)
              IconButton(
                icon: Icon(_drawMode ? Icons.touch_app : Icons.draw),
                onPressed: _toggleDrawMode,
                tooltip: _drawMode ? '选择模式' : '绘制模式',
                color: _drawMode ? Colors.orange : null,
              ),
            if (widget.onSave != null && _imageFile != null && visibleBlocks.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveToBook,
                tooltip: '保存到点读本',
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: '更多操作',
              onSelected: (value) {
                switch (value) {
                  case 'ai_enhance_all':
                    _showAiEnhanceAllDialog();
                    break;
                  case 'select_model':
                    _showModelSelectionDialog();
                    break;
                  case 'play':
                    _playSelectedBlock();
                    break;
                  case 're_recognize':
                    _showReRecognizeDialog();
                    break;
                  case 'ai_enhance_selected':
                    _showAiEnhanceSelectedDialog();
                    break;
                  case 'edit':
                    _editSelectedBlock();
                    break;
                  case 'delete':
                    _deleteSelectedBlock();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (!_isAiEnhancing && _imageFile != null && visibleBlocks.isNotEmpty)
                  const PopupMenuItem(
                    value: 'ai_enhance_all',
                    child: Row(
                      children: [
                        Icon(Icons.auto_fix_high, size: 20),
                        SizedBox(width: 8),
                        Text('AI强化全部'),
                      ],
                    ),
                  ),
                if (_imageFile != null && !_isAiEnhancing)
                  PopupMenuItem(
                    value: 'select_model',
                    child: Row(
                      children: [
                        const Icon(Icons.psychology, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('选择AI模型'),
                              Text(
                                '当前: ${AppConstants.availableModels.firstWhere(
                                  (m) => m['name'] == _currentAiModel,
                                  orElse: () => AppConstants.availableModels.first,
                                )['label']}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_selectedIndex != null) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'play',
                    child: Row(
                      children: [
                        Icon(Icons.volume_up, size: 20),
                        SizedBox(width: 8),
                        Text('试听朗读'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 're_recognize',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 20),
                        SizedBox(width: 8),
                        Text('重新识别此区域'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'ai_enhance_selected',
                    child: Row(
                      children: [
                        Icon(Icons.auto_fix_high, size: 20, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('AI强化此区域'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('编辑文字'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('删除'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      body: SafeArea(
        child: _imageFile == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('请选择或拍摄图片'),
                    const SizedBox(height: 8),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('从相册选择'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('拍照'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    _updateDisplaySize(Size(constraints.maxWidth, constraints.maxHeight));
                    
                    return Stack(
                      alignment: AlignmentDirectional.topStart,
                      children: [
                        InteractiveViewer(
                          key: _interactiveViewerKey,
                          transformationController: _controller,
                          minScale: 0.5,
                          maxScale: 4.0,
                          panEnabled: false,
                          scaleEnabled: false,
                          constrained: false,
                          alignment: Alignment.topLeft,
                          child: GestureDetector(
                            onTapDown: _handleTapDown,
                            onScaleStart: _handleScaleStart,
                            onScaleUpdate: _handleScaleUpdate,
                            onScaleEnd: _handleScaleEnd,
                            child: SizedBox(
                              width: _displaySize.width,
                              height: _displaySize.height,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    _imageFile!,
                                    fit: BoxFit.fill,
                                  ),
                                  CustomPaint(
                                    painter: TextBlockPainter(
                                      textBlocks: _textBlocks,
                                      selectedIndex: _selectedIndex,
                                      scale: _getScale(),
                                      imageSize: _imageSize,
                                      tempRect: _tempRect,
                                      drawMode: _drawMode,
                                      editModeResize: _editModeResize,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_isProcessing)
                          Positioned(
                            top: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '正在识别文字...',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_showAiBanner)
                          Positioned(
                            top: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'AI正在优化识别结果...',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (!_isProcessing && !_showAiBanner && _drawMode)
                          Positioned(
                            top: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.draw, size: 16, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      '绘制模式：拖动绘制矩形，松开后编辑文字',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (!_isProcessing && !_showAiBanner && !_drawMode && visibleBlocks.isNotEmpty)
                          const SizedBox.shrink(),
                        if (!_isProcessing && visibleBlocks.isEmpty && _textBlocks.isNotEmpty)
                          Positioned(
                            top: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '未找到英文文字',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_errorMessage != null)
                          Positioned(
                            top: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        if (_selectedIndex != null)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: _editModeResize ? null : _toggleEditMode,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _editModeResize ? Colors.green : Colors.transparent,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.open_in_full,
                                              color: _editModeResize ? Colors.white : Colors.white54,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '调整大小',
                                              style: TextStyle(
                                                color: _editModeResize ? Colors.white : Colors.white54,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _editModeResize ? _toggleEditMode : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: !_editModeResize ? Colors.orange : Colors.transparent,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.open_with,
                                              color: !_editModeResize ? Colors.white : Colors.white54,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '移动位置',
                                              style: TextStyle(
                                                color: !_editModeResize ? Colors.white : Colors.white54,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 8,
                          bottom: 70,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                                  onPressed: _zoomIn,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '${(_controller.value.getMaxScaleOnAxis() * 100).toInt()}%',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                                  onPressed: _zoomOut,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                ),
                                const Divider(color: Colors.white38, height: 1, indent: 6, endIndent: 6),
                                IconButton(
                                  icon: const Icon(Icons.fit_screen, color: Colors.white, size: 18),
                                  onPressed: _resetZoom,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  tooltip: '重置缩放',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
},
                ),
              ],
            ),
          ),
        floatingActionButton: _imageFile != null
           ? Column(
               mainAxisAlignment: MainAxisAlignment.end,
               crossAxisAlignment: CrossAxisAlignment.end,
               children: [
                 if (_selectedIndex != null)
                   FloatingActionButton(
                     heroTag: 'play',
                     mini: true,
                     onPressed: _playSelectedBlock,
                     tooltip: '试听朗读',
                     backgroundColor: Colors.green,
                     child: const Icon(Icons.volume_up),
                   ),
                 if (_selectedIndex != null)
                   const SizedBox(height: 8),
                 if (_selectedIndex != null)
                   FloatingActionButton(
                     heroTag: 'edit',
                     mini: true,
                     onPressed: _editSelectedBlock,
                     tooltip: '编辑文字',
                     backgroundColor: Colors.orange,
                     child: const Icon(Icons.edit),
                   ),
                 const SizedBox(height: 8),
if (!_isAiEnhancing && visibleBlocks.isNotEmpty)
                    FloatingActionButton(
                      heroTag: 'ai',
                      mini: true,
                      onPressed: _showAiEnhanceAllDialog,
                      tooltip: 'AI强化全部',
                      backgroundColor: Colors.purple,
                      child: const Icon(Icons.auto_fix_high),
                    ),
                  if (!_isAiEnhancing && visibleBlocks.isNotEmpty)
                    const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'refresh',
                    onPressed: _showReRecognizeAllDialog,
                    tooltip: '重新识别全部',
                    child: const Icon(Icons.refresh),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class TextBlockPainter extends CustomPainter {
  final List<TextBlockData> textBlocks;
  final int? selectedIndex;
  final double scale;
  final Size imageSize;
  final Rect? tempRect;
  final bool drawMode;
  final bool editModeResize;

  TextBlockPainter({
    required this.textBlocks,
    required this.selectedIndex,
    required this.scale,
    required this.imageSize,
    this.tempRect,
    this.drawMode = false,
    this.editModeResize = true,
  });

  bool _isEnglishText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    
    for (final char in trimmed.split('')) {
      final codeUnit = char.codeUnitAt(0);
      if (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) {
        return false;
      }
    }
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale, scale);
    
    const double strokeWidth = 2.0;
    const double handleSize = 16.0;
    
    for (int i = 0; i < textBlocks.length; i++) {
      final block = textBlocks[i];
      
      if (block.isDeleted) continue;
      if (!_isEnglishText(block.text)) continue;
      
      final rect = block.boundingBox;
      final isSelected = i == selectedIndex;
      
      final fillPaint = Paint()
        ..color = isSelected
            ? (editModeResize
                ? Colors.green.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3))
            : Colors.blue.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      
      final borderPaint = Paint()
        ..color = isSelected
            ? (editModeResize ? Colors.green : Colors.orange)
            : Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth * 1.5 : strokeWidth;
      
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
      
      if (isSelected) {
        if (editModeResize) {
          _drawHandles(canvas, rect, handleSize, strokeWidth);
        } else {
          _drawMoveIcon(canvas, rect, handleSize);
        }
        _drawDeleteButton(canvas, rect);
      }
      
      final displayText = block.text.length > 20 ? '${block.text.substring(0, 20)}...' : block.text;
      final textPainter = TextPainter(
        text: TextSpan(
          text: displayText,
          style: TextStyle(
            color: isSelected ? Colors.green : Colors.blue,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.white.withOpacity(0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 14));
    }
    
    if (tempRect != null) {
      final tempFillPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      final tempBorderPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.5;
      
      canvas.drawRect(tempRect!, tempFillPaint);
      canvas.drawRect(tempRect!, tempBorderPaint);
    }
    
    canvas.restore();
  }

  void _drawHandles(Canvas canvas, Rect rect, double handleSize, double strokeWidth) {
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    final resizePositions = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
    ];

    for (final pos in resizePositions) {
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: handleSize, height: handleSize),
        handlePaint,
      );
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: handleSize, height: handleSize),
        handleBorderPaint,
      );
    }
  }

  void _drawMoveIcon(Canvas canvas, Rect rect, double handleSize) {
    final iconPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final len = handleSize * 0.4;

    canvas.drawLine(Offset(cx, cy - len), Offset(cx, cy + len), iconPaint);
    canvas.drawLine(Offset(cx - len, cy), Offset(cx + len, cy), iconPaint);
    final a = len * 0.45;
    canvas.drawLine(Offset(cx, cy - len), Offset(cx - a, cy - len + a), iconPaint);
    canvas.drawLine(Offset(cx, cy - len), Offset(cx + a, cy - len + a), iconPaint);
    canvas.drawLine(Offset(cx, cy + len), Offset(cx - a, cy + len - a), iconPaint);
    canvas.drawLine(Offset(cx, cy + len), Offset(cx + a, cy + len - a), iconPaint);
    canvas.drawLine(Offset(cx - len, cy), Offset(cx - len + a, cy - a), iconPaint);
    canvas.drawLine(Offset(cx - len, cy), Offset(cx - len + a, cy + a), iconPaint);
    canvas.drawLine(Offset(cx + len, cy), Offset(cx + len - a, cy - a), iconPaint);
    canvas.drawLine(Offset(cx + len, cy), Offset(cx + len - a, cy + a), iconPaint);
  }

  void _drawDeleteButton(Canvas canvas, Rect rect) {
    final deletePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    final deleteBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final deleteIconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    const double deleteSize = 24.0;
    final Offset deletePos = Offset(rect.right + deleteSize / 2, rect.top - deleteSize / 2);
    
    canvas.drawCircle(deletePos, deleteSize / 2, deletePaint);
    canvas.drawCircle(deletePos, deleteSize / 2, deleteBorderPaint);
    
    const double iconSize = deleteSize * 0.3;
    canvas.drawLine(
      Offset(deletePos.dx - iconSize, deletePos.dy - iconSize),
      Offset(deletePos.dx + iconSize, deletePos.dy + iconSize),
      deleteIconPaint,
    );
    canvas.drawLine(
      Offset(deletePos.dx + iconSize, deletePos.dy - iconSize),
      Offset(deletePos.dx - iconSize, deletePos.dy + iconSize),
      deleteIconPaint,
    );
  }

  @override
  bool shouldRepaint(covariant TextBlockPainter oldDelegate) {
    return oldDelegate.textBlocks != textBlocks ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.scale != scale ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.tempRect != tempRect ||
        oldDelegate.drawMode != drawMode ||
        oldDelegate.editModeResize != editModeResize;
  }
}