# 重构进度记录

## 项目：点读鸭 (DianDuYa) Book App
## 日期：2026-05-15

---

## 一、已完成的重构（9/9）

### 阶段 1：5 个严重 Bug 修复 ✅

#### Bug #1: 同步文件 I/O 阻塞主线程
- **文件**: `lib/data/services/book_service.dart:50`
- **修复**: `imageFile.readAsBytesSync()` → `await imageFile.readAsBytes()`
- **状态**: ✅ 完成

#### Bug #2: TextBlockData 可变字段 → 不可变
- **文件**: `lib/presentation/features/text_detection/models/text_block_data.dart`
- **修复**: 所有字段从 `var` 改为 `final`，viewmodel/ocr_results 中所有直接赋值改为 `copyWith` 模式
- **影响文件**:
  - `text_detection_viewmodel.dart` — `_onEditUpdate`, `_onEditEnd`, `deleteSelectedBlock`, `updateBlockText`, `aiEnhanceAll`, `aiEnhanceSelectedBlock`
  - `lib/presentation/pages/ocr/ocr_results_page.dart` — `_editBlock`, `_editTranslation`, `_useAiText`, `_useOriginalText`, `_deleteBlock`, `_aiEnhanceBlock`, `_aiEnhanceAllBlocks`, `_aiTranslateAllBlocks`
- **状态**: ✅ 完成

#### Bug #3: VoiceSettingsPage 保存丢失字段
- **文件**: `lib/presentation/pages/voice_settings_page.dart:50-56`
- **修复**: 改用 `currentSettings.copyWith(useGlmTts: ..., ttsVoice: ..., speechRate: ...)` 保留 `selectedTextModel` 和 `useSlowSpeed`
- **同样修复**: `book_detail_page.dart` 语音设置对话框保存逻辑（约 line 210-216）
- **状态**: ✅ 完成

#### Bug #4: 创建空书孤儿问题
- **文件**: `lib/presentation/pages/home_page.dart:19-39`
- **修复**: 将 `createBook` 调用移到 `onSave` 回调内部，用户取消时不创建书
- **新增**: `TextBlockData` → `TextBlockModel` 转换逻辑（因为 `BooksNotifier.addPageToBook` 现在要求强类型）
- **状态**: ✅ 完成

#### Bug #5: 导航违规
- **文件 1**: `lib/presentation/pages/book_detail_page.dart:357` — `Navigator.pushNamed(context, '/settings')` → `context.push('/settings')`
- **文件 2**: `lib/presentation/features/text_detection/views/text_detection_view.dart:956` — `Navigator.push(...VoiceSettingsPage())` → `context.push('/settings/voice')`
- **附带**: 移除了 `text_detection_view.dart` 对 `voice_settings_page.dart` 的未使用 import，添加了 `go_router` import
- **状态**: ✅ 完成

---

### 阶段 2：公共工具提取 ✅

#### TextUtils.isEnglishText()
- **新文件**: `lib/core/utils/text_utils.dart`
- **消除重复**: 从 3 处提取为统一工具
  - `lib/presentation/features/text_detection/models/text_detection_state.dart` — 删除 `_isEnglishText()`，改用 `TextUtils.isEnglishText()`
  - `lib/presentation/features/text_detection/view_models/text_detection_viewmodel.dart` — 同上
  - `lib/presentation/features/text_detection/views/text_block_painter.dart` — 同上

#### FileUtils.formatFileSize()
- **新文件**: `lib/core/utils/file_utils.dart`
- **消除重复**: 从 2 处提取为统一工具
  - `lib/data/services/image_service.dart` — `formatFileSize()` 改为委托 `FileUtils.formatFileSize()`
  - `lib/presentation/pages/cache_management_page.dart` — `_formatSize()` 改为委托 `FileUtils.formatFileSize()`

#### 其他清理
- **删除重复**: `AppTheme.settingsAppBarGradient`（与 `appBarGradient` 完全相同），`app_theme.dart`
- **默认值统一**: `AiSettingsModel` 的 `ttsVoice` 和 `selectedTextModel` 默认值改为引用 `AppConstants.defaultTtsVoice` / `AppConstants.defaultTextModel`
- **状态**: ✅ 完成

---

### 阶段 3：.withOpacity() → .withValues(alpha:) ✅

- **总计替换**: 105 处，跨 10 个文件
- **文件列表**:
  - `lib/core/theme/app_theme.dart` — 42 处
  - `lib/presentation/pages/settings_page.dart` — 15 处
  - `lib/presentation/pages/home_page.dart` — 12 处
  - `lib/presentation/pages/cache_management_page.dart` — 8 处
  - `lib/presentation/widgets/book_card.dart` — 8 处
  - `lib/presentation/pages/ai_settings_page.dart` — 6 处
  - `lib/presentation/widgets/page_indicator.dart` — 6 处
  - `lib/presentation/features/text_detection/views/text_block_painter.dart` — 4 处
  - `lib/presentation/pages/voice_settings_page.dart` — 3 处
  - `lib/core/router/app_router.dart` — 1 处
- **状态**: ✅ 完成，`rg "\.withOpacity\(" lib/ --type dart` 结果为 0

---

### 阶段 4：AiService 拆分 ✅

**原文件**: `lib/data/services/ai_service.dart` (679 行，God Class)

拆分为 3 个服务：

| 新服务 | 文件 | 职责 | 行数 |
|--------|------|------|------|
| `VisionService` | `lib/data/services/vision_service.dart` | 视觉 OCR 提取 + base64 编码 | ~90 |
| `TextCleaningService` | `lib/data/services/text_cleaning_service.dart` | 文本清洗 + 翻译优化 + 批量处理 + JSON 解析 + 校验 | ~380 |
| `AiService`（精简 facade） | `lib/data/services/ai_service.dart` | API Key 管理 + TTS 合成 + 连接测试，委托到子服务 | ~170 |

- `AiService` 保持原有公共 API 不变，所有消费者无需修改
- `VisionService` 和 `TextCleaningService` 作为单例独立存在
- **状态**: ✅ 完成

---

### 阶段 5：Repository/单例 DI 修复 ✅

| 变更 | 文件 |
|------|------|
| `repository_providers` 改用 `ref.read`（避免无意义重建） | `lib/presentation/providers/repository_providers.dart` |
| `BooksNotifier.addPageToBook` 参数类型从 `dynamic` 改为 `File + List<TextBlockModel>` | `lib/presentation/providers/books_provider.dart` |
| `SettingsNotifier._loadSettings` 加 try/catch 防止永久 `isLoading` | `lib/presentation/providers/settings_provider.dart` |
| `BookService.updatePageTextBlocks` 清除 35 行 `debugPrint` | `lib/data/services/book_service.dart` |

- **状态**: ✅ 完成

---

## 二、第二轮修复（会话 2）

### 阶段 6：Bug 修复 + 清理 ✅

#### #7: TtsNotifier.dispose() 死代码删除
- **文件**: `lib/presentation/providers/tts_provider.dart`
- **修复**: 删除全局 `Notifier` 上永远不会被调用的 `dispose()` 方法
- **状态**: ✅ 完成

#### #8: 神秘 Future.delayed 删除
- **文件**: `lib/presentation/pages/book_detail_page.dart`
- **修复**: 删除 `initState()` 中的 `Future.delayed(Duration(seconds: 3), () { setState(() {}); })` — 空 setState 无任何效果
- **状态**: ✅ 完成

#### #9: JSON 手动拼接 → jsonEncode
- **文件**: `lib/data/services/text_cleaning_service.dart`
- **修复**: `_textCleanBatch` 和 `_translationRefineBatch` 中的字符串插值构造 JSON → 使用 `jsonEncode` 防止注入
- **状态**: ✅ 完成

#### #11: 空目录残留删除
- **删除**: `lib/domain/`, `lib/canvas/` 及其所有子目录
- **状态**: ✅ 完成

### 阶段 7：单例 → Provider DI 修复 ✅

#### #4: TextDetectionViewmodel 单例 → Provider
- **文件**: `lib/presentation/features/text_detection/view_models/text_detection_viewmodel.dart`
- **修复**:
  - `StorageService.instance.getAiSettings()` → `ref.read(settingsProvider).settings`
  - `OcrService.instance.recognizeText()` → `ref.read(ocrRepositoryProvider).recognizeText()`
  - `AiService.instance.enhanceTextBlocks()` 保留（repository 不支持 `onProgress` 回调）
- **状态**: ✅ 完成

#### #5: ai_settings_page 单例 → Provider
- **文件**: `lib/presentation/pages/ai_settings_page.dart`
- **修复**:
  - `AiService.instance.getApiKey/saveApiKey/deleteApiKey/testConnection` → `ref.read(aiRepositoryProvider)`
  - `StorageService.instance.getAiSettings/saveAiSettings/deleteAiSettings` → `ref.read(settingsProvider).settings` / `ref.read(storageServiceProvider)`
- **状态**: ✅ 完成

#### #5: ocr_results_page 单例 → Provider（部分）
- **文件**: `lib/presentation/pages/ocr/ocr_results_page.dart`
- **修复**:
  - `AiService.instance.getSelectedModel()` → `ref.read(selectedModelProvider)`
  - `AiService.instance.hasApiKey()` → `ref.read(aiRepositoryProvider).hasApiKey()`
  - `TranslationService.instance.translateWithStatus()` → `ref.read(translationServiceProvider).translateWithStatus()`
  - `AiService.instance.enhanceTextBlocks/enhanceTranslation/extractVisionText` 保留（需 `onProgress` / `visionDescription` 参数）
- **状态**: ✅ 完成

### 阶段 8：同步文件 I/O 修复 ✅

#### #14: image_service 同步操作 → async
- **文件**: `lib/data/services/image_service.dart`
- **修复**:
  - `createSync()` → `await create()`（saveImage, saveCoverImage）
  - `existsSync()` → `await exists()`（deleteImage, deleteBookDirectory, getBookStorageSize, clearAllBooksDirectory）
  - `listSync()` → `await for ... list()`（getBookStorageSize）
  - `getImageFile()` 保留同步 — 所有调用方在 `build()` 中同步使用
- **状态**: ✅ 完成

#### #6: TtsNotifier 状态管理（复查）
- **分析**: `TtsService.speak()` 内部使用 `Completer` + `await _speakCompleter?.future` 等待播放完成
- **结论**: `finally` 块在播放完成后才执行，行为正确，无需修改

---

## 三、仍未修复的架构问题（供后续会话继续）

### HIGH 优先级

#### ~~1. BookDetailPage 非 Riverpod + God Class (1012 行)~~ ✅ 已修复（会话 3）
- **文件**: `lib/presentation/pages/book_detail_page.dart`
- **修复**: 转为 `ConsumerStatefulWidget`，所有 `TtsService.instance` / `StorageService.instance` / `TranslationService.instance` / `ImageService.instance` → `ref.read(xxxProvider)`
- **移除**: 未使用的 `storage_service.dart` / `image_service.dart` 直接 import
- **状态**: ✅ 完成

#### ~~2. BookManagePage God Class (840 行)~~ ✅ 部分修复（会话 3）
- **文件**: `lib/presentation/pages/book_manage_page.dart`
- **修复**: 移除 `_editPage` 中 35 行 debugPrint 调试日志
- **备注**: 保持非 Riverpod（AGENTS.md 允许），可考虑后续通过 repository provider 访问
- **状态**: ✅ 完成

#### ~~3. TextDetectionView God Class (1014 行)~~ ✅ 已修复（会话 3）
- **文件**: `lib/presentation/features/text_detection/views/text_detection_view.dart`
- **修复**: 10 个对话框方法抽取到 `_TextDetectionDialogs` mixin（`part` 文件）
- **新增文件**: `text_detection_dialogs.dart` — 10 个对话框方法（editSelectedBlock, confirmDeleteBlock, showAiEnhanceAllDialog, showAiEnhanceSelectedDialog, showModelSelectionDialog, showReRecognizeAllDialog, showReRecognizeSelectedBlock, showUnsavedDialog, showHelpDialog）
- **主文件行数**: 1014 → ~570（减少 44%）
- **状态**: ✅ 完成

### MEDIUM 优先级

#### ~~10. Prompt 硬编码在 Dart 代码中~~ ✅ 已修复（会话 3）
- **新增文件**: `lib/core/constants/app_prompts.dart`
- **提取**: Vision OCR 提取 prompt、文本清洗 prompt 模板、翻译优化 prompt 模板、AI 使用通知文本
- **影响文件**: `vision_service.dart`, `text_cleaning_service.dart`, `text_detection_dialogs.dart`
- **状态**: ✅ 完成

#### 6. TtsNotifier 状态管理问题（经复查：实际无 bug）
- **文件**: `lib/presentation/providers/tts_provider.dart`
- **分析**: `TtsService.speak()` 内部 `await _speakCompleter?.future` 等待 TTS 播放完成后才返回，所以 `finally` 块正确地在播放结束后设 `isSpeaking = false`
- **结论**: 无需修改

#### 10. Prompt 硬编码在 Dart 代码中
- **文件**: `lib/data/services/vision_service.dart`, `lib/data/services/text_cleaning_service.dart`
- **问题**: 大段 AI prompt 嵌在 Dart 代码中，不便维护
- **建议**: 外部化到 assets/prompts/ 目录或常量文件

#### ~~13. Semantics 不完整~~ ✅ 已修复（会话 4）
- **修复**: 为所有交互元素添加 `Semantics` wrapper（label + hint + button: true）
- **涉及文件**:
  - `page_indicator.dart` — 2 个 GestureDetector（上一页/下一页按钮）
  - `bottom_toolbar.dart` — 10 个 GestureDetector（模式/子模式/操作按钮）
  - `settings_page.dart` — 3 个 GestureDetector（主题选择器）
  - `book_manage_page.dart` — 2 个 InkWell（保存按钮、封面编辑）
  - `voice_settings_page.dart` — 2 个 InkWell（TTS 类型选项）
  - `ocr_results_page.dart` — 4 个 IconButton → SemanticsIconButton + 1 个 FAB
  - `block_card.dart` — 1 个 InkWell（文字块卡片）
  - `info_container.dart` — 1 个 GestureDetector（编辑图标）
- **状态**: ✅ 完成

### LOW 优先级

#### 12. Repository 层零价值（设计选择）
- 当前 Repository 纯委托到单例，无额外逻辑
- 如果不需要可测试性，可以考虑简化为直接使用 Service Provider
- 但保留也无害，后续可注入 mock 实现

#### ~~13. Semantics 不完整~~ ✅ 已修复（会话 4）

#### 14. image_service getImageFile() 同步操作残留
- `getImageFile()` 仍使用 `existsSync()` — 因为所有调用方都在 `build()` 方法中同步使用，改为 async 需要 FutureBuilder
- 其余 `createSync()`/`existsSync()`/`listSync()` 均已修复为 async

---

## 三、构建验证

### 第一轮
```
flutter analyze: 0 errors, 0 warnings (from our changes)
dart format lib/: All formatted
```

### 第二轮
```
flutter analyze: 0 errors, 6 pre-existing warnings (not from our changes)
dart format lib/: 2 files formatted
```

### 第三轮
```
flutter analyze: 0 errors, 6 pre-existing warnings (not from our changes)
dart format lib/: 2 files formatted
```

### 第四轮
```
flutter analyze: 0 errors, 0 warnings, 127 info (仅 style 建议)
dart format lib/: 4 files formatted
```

## 四、关键文件变更清单

### 第一轮新增文件
- `lib/core/utils/text_utils.dart` — TextUtils.isEnglishText()
- `lib/core/utils/file_utils.dart` — FileUtils.formatFileSize()
- `lib/data/services/vision_service.dart` — 视觉 OCR 提取服务
- `lib/data/services/text_cleaning_service.dart` — 文本清洗 + 翻译服务

### 第一轮修改文件
- `lib/data/services/ai_service.dart` — 精简为 facade，委托到 VisionService + TextCleaningService
- `lib/data/services/book_service.dart` — async I/O 修复 + 清除 debugPrint
- `lib/data/services/image_service.dart` — formatFileSize 委托到 FileUtils
- `lib/data/models/ai_settings_model.dart` — 默认值引用 AppConstants
- `lib/data/models/text_block_data.dart` — 所有字段 final
- `lib/core/theme/app_theme.dart` — 删除重复 gradient + 42 处 withOpacity 修复
- `lib/core/router/app_router.dart` — 1 处 withOpacity 修复
- `lib/presentation/features/text_detection/models/text_detection_state.dart` — 使用 TextUtils
- `lib/presentation/features/text_detection/view_models/text_detection_viewmodel.dart` — copyWith 模式 + TextUtils + 删除 unused var
- `lib/presentation/features/text_detection/views/text_detection_view.dart` — GoRouter 导航 + import 清理
- `lib/presentation/features/text_detection/views/text_block_painter.dart` — TextUtils + withOpacity 修复
- `lib/presentation/pages/home_page.dart` — 空书修复 + 类型转换 + withOpacity 修复
- `lib/presentation/pages/book_detail_page.dart` — GoRouter + copyWith 语音设置保存
- `lib/presentation/pages/voice_settings_page.dart` — copyWith 保存 + withOpacity 修复
- `lib/presentation/pages/cache_management_page.dart` — FileUtils + withOpacity 修复
- `lib/presentation/pages/ocr/ocr_results_page.dart` — copyWith 模式（所有 TextBlockData 赋值）
- `lib/presentation/pages/settings_page.dart` — withOpacity 修复
- `lib/presentation/pages/ai_settings_page.dart` — withOpacity 修复
- `lib/presentation/providers/books_provider.dart` — 强类型参数 + 删除 unused import
- `lib/presentation/providers/settings_provider.dart` — try/catch 加固
- `lib/presentation/providers/repository_providers.dart` — ref.read 替代 ref.watch
- `lib/presentation/widgets/book_card.dart` — withOpacity 修复
- `lib/presentation/widgets/page_indicator.dart` — withOpacity 修复

### 第二轮修改文件
- `lib/presentation/providers/tts_provider.dart` — 删除 dispose() 死代码
- `lib/presentation/pages/book_detail_page.dart` — 删除无意义 Future.delayed
- `lib/data/services/text_cleaning_service.dart` — JSON 手动拼接 → jsonEncode
- `lib/presentation/features/text_detection/view_models/text_detection_viewmodel.dart` — StorageService/OcrService 单例 → Provider
- `lib/presentation/pages/ai_settings_page.dart` — AiService/StorageService 单例 → Provider
- `lib/presentation/pages/ocr/ocr_results_page.dart` — AiService/TranslationService 单例 → Provider（部分）
- `lib/data/services/image_service.dart` — 同步文件 I/O → async

### 第二轮删除
- `lib/domain/` — 空目录
- `lib/canvas/` — 空目录

### 第三轮新增文件
- `lib/core/constants/app_prompts.dart` — AI prompt 常量（vision/clean/translation/notice）
- `lib/presentation/features/text_detection/views/text_detection_dialogs.dart` — TextDetectionView 对话框 mixin（`part` 文件）

### 第三轮修改文件
- `lib/presentation/pages/book_detail_page.dart` — ConsumerStatefulWidget + provider DI（TtsService/StorageService/TranslationService/ImageService → ref.read）
- `lib/presentation/pages/book_manage_page.dart` — 移除 _editPage 中 35 行 debugPrint
- `lib/presentation/features/text_detection/views/text_detection_view.dart` — 对话框方法提取到 mixin，主文件 1014→570 行
- `lib/data/services/vision_service.dart` — prompt 引用 AppPrompts.visionExtractText()
- `lib/data/services/text_cleaning_service.dart` — prompt 引用 AppPrompts.textCleanBatch() / AppPrompts.translationRefineBatch()
```

### 第四轮修改文件
- `lib/data/repositories/service_repositories.dart` — 移除 unused `dart:ui` import
- `lib/data/repositories/book_repository_impl.dart` — 移除 unused fields/imports（`_storageService`/`_imageService`/`constants.dart`）
- `lib/presentation/pages/ocr/widgets/status_banner.dart` — 移除 unused `app_theme.dart` import
- `lib/presentation/pages/settings_page.dart` — 移除 unused `isDark` 变量 + 3 个主题选择器添加 Semantics
- `lib/presentation/widgets/page_indicator.dart` — 2 个翻页按钮添加 Semantics（参数化 label/hint）
- `lib/presentation/features/text_detection/widgets/bottom_toolbar.dart` — 10 个工具栏按钮添加 Semantics（4 个 builder 方法）
- `lib/presentation/pages/book_manage_page.dart` — 保存按钮 + 封面编辑添加 Semantics
- `lib/presentation/pages/voice_settings_page.dart` — 2 个 TTS 选项添加 Semantics
- `lib/presentation/pages/ocr/ocr_results_page.dart` — 4 个 IconButton → SemanticsIconButton + FAB 添加 Semantics
- `lib/presentation/pages/ocr/widgets/block_card.dart` — InkWell 添加 Semantics
- `lib/presentation/pages/ocr/widgets/info_container.dart` — 编辑图标 GestureDetector 添加 Semantics
