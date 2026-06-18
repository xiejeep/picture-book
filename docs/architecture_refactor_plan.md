# 点读鸭阅读核心架构重构计划

## 背景

点读鸭的核心链路是：导入绘本图片 -> OCR/AI 修正 -> 生成文字块 -> 阅读页点击文字块 -> TTS 播放 -> 翻译展示 -> NFC/deep link 自动播放。

当前项目已经有清晰的分层雏形：

- `lib/main.dart` 负责初始化 `StorageService`、`ImageService` 并启动 Riverpod。
- `lib/app.dart` 管理主题、TTS/file intent 初始化、NFC 生命周期。
- `lib/core/router/app_router.dart` 是实际路由来源。
- `lib/data/services/` 封装 TTS、NFC、OCR、AI、存储、文件等外部能力。
- `lib/data/repositories/` 已经提供 `BookRepository` 等入口。
- `lib/application/reading/text_block_ai_use_case.dart` 已经开始承接阅读场景中的 AI 文字块流程。
- `lib/presentation/providers/reading_state.dart` 已经有阅读状态数据类。
- `lib/presentation/features/text_detection/` 已经形成 `models / view_models / views / widgets` 的 feature 化组织方式。

但阅读核心页面仍然过重：

- `lib/presentation/pages/book_reader_page.dart` 约 1900 行，是全项目最大文件。
- `BookReaderPage` 同时承担页面布局、手势命中、TTS 编排、翻译流程、文字块编辑、AI 操作、NFC 绑定、动画控制、持久化更新、弹窗构建。
- `ReadingState` 目前只是页面内手动维护的数据对象，尚未成为 Riverpod 状态源。
- `presentation/features/reader/widgets/` 已存在目录，但阅读页 UI 还没有迁进去。

本计划目标是把阅读页从“全能页面”重构为“薄页面 + 可观察状态 + 小部件 + 用例”的结构，保持现有行为和中文文案稳定。

## 当前问题诊断

### 1. 页面承担过多职责

`BookReaderPage` 当前包含以下职责：

- 页面骨架：`Scaffold`、`AppBar`、空状态、`PhotoViewGallery`、页码、阅读浮层。
- 手势和坐标：屏幕坐标转图片像素、文字块命中、点击播放、长按菜单。
- 播放流程：停止旧播放、设置播放状态、启动 loading 动画、调用 TTS、监听播放状态。
- 翻译流程：判断缓存翻译、调用翻译服务、更新阅读状态、持久化 `aiTranslatedText`。
- 文字块编辑：编辑原文、编辑翻译、保存文字块。
- AI 操作：API key 检查、AI 优化、AI 翻译、toast 反馈。
- NFC 操作：自动播放 NFC action、写入 NFC 标签、展示绑定弹窗。
- 语音设置：读取/保存语速设置、展示设置弹窗。
- 动画：焦点框飞入、弹跳、loading spinner。

这导致任何阅读体验的小改动都要进入同一个 1900 行文件，回归面很大。

### 2. 状态来源不统一

当前阅读状态存在多种来源：

- `_book` 本地字段。
- `_readingState` 本地字段。
- `_currentSpeechRate` 本地字段。
- TTS service stream。
- Riverpod providers，如 `nfcEnabledProvider`、`ttsServiceProvider`、`bookRepositoryProvider`。
- 页面内动画 controller 状态。

状态来源越多，越容易出现 UI 与持久化对象不同步，或 rebuild 后 controller 生命周期异常的问题。

### 3. 业务逻辑仍然靠页面协调

虽然已经有 `TextBlockAiUseCase`，但以下业务仍在页面内：

- 播放文字块前后的状态切换。
- 翻译结果选择、缓存和保存。
- 文字块更新持久化。
- NFC 标签绑定的可用性检查和写入流程。
- 语音设置保存。

页面应当负责展示和触发，不应直接成为业务流程的主实现。

### 4. UI 组件无法复用和独立验证

阅读栏、顶部栏、空状态、焦点框、文字块操作菜单等都嵌在页面私有方法中：

- 无法在其他页面复用。
- 无法独立调整样式。
- 修改一个弹窗也需要打开整个阅读页。
- 文件结构没有体现阅读 feature 的内部边界。

### 5. 存在可顺手修复的生命周期问题

`PageController` 当前在 `build` 中创建并赋值给 `_pageController`，但没有在 `dispose` 中释放。它应在 `initState` 创建、在 `dispose` 释放，避免 rebuild 重建 controller 和潜在资源泄漏。

## 重构目标

### 主要目标

- 将 `BookReaderPage` 降到 300 行以内，长期目标 150-250 行。
- 阅读页只保留参数接收、生命周期订阅、页面组装和少量动画 controller。
- 阅读状态由 Riverpod Notifier 管理，而不是页面字段手动 `setState`。
- 业务流程放入 `application/reading/` 用例或 reader notifier。
- UI 组件放入 `presentation/features/reader/widgets/`。
- 所有书籍写入通过 `BookRepository` 或用例收口。
- 保持现有 UI 文案、功能行为、NFC/deep link payload 不变。

### 非目标

- 不重写整个应用架构。
- 不替换 Hive。
- 不改变模型 `typeId` 或 `@HiveField`。
- 不改变安卓/iOS 原生 NFC 配置，除非某阶段明确需要。
- 不一次性引入复杂 Clean Architecture。
- 不为了拆文件制造新的巨型 controller。

## 目标目录结构

推荐最终结构：

```text
lib/
  application/
    reading/
      play_text_block_use_case.dart
      translate_text_block_use_case.dart
      update_reader_block_use_case.dart
      bind_nfc_block_use_case.dart
      text_block_ai_use_case.dart

  presentation/
    features/
      reader/
        models/
          reader_state.dart
          reader_view_data.dart
        view_models/
          reader_notifier.dart
        views/
          book_reader_view.dart
        widgets/
          reader_app_bar.dart
          reader_gallery.dart
          reader_empty_state.dart
          reader_page_indicator.dart
          reader_reading_bar.dart
          reader_focus_border.dart
          reader_block_actions_sheet.dart
          reader_block_edit_sheet.dart
          reader_translation_edit_sheet.dart
          reader_nfc_bind_dialog.dart
          reader_voice_settings_dialog.dart
```

说明：

- `views/` 放完整页面主体组合。
- `widgets/` 放可复用 UI 片段。
- `view_models/` 放 Riverpod notifier。
- `models/` 放 reader feature 专属状态和展示数据。
- `application/reading/` 放跨 widget 的业务流程。

短期可以保留 `lib/presentation/pages/book_reader_page.dart` 作为路由入口，内部委托给 `BookReaderView`。

## 职责边界

### Page

允许：

- 接收路由参数。
- 初始化和释放页面生命周期资源。
- 建立必要的 `ref.listenManual` 订阅。
- 创建动画 controller。
- 组装 `BookReaderView`。

不允许：

- 直接调用 `_book.save()`。
- 直接修改 `_book.pages[...]`。
- 编排 AI、翻译、NFC 写入等跨步骤业务。
- 构建大段弹窗 UI。

### ReaderNotifier

允许：

- 管理当前页、当前播放块、loading 块、翻译展示状态、顶部栏显示状态。
- 暴露 `toggleAppBar`、`toggleBorders`、`setCurrentPage`、`clearTranslation` 等 UI 状态动作。
- 调用用例完成播放、翻译、文字块更新。

不建议：

- 持有 `AnimationController`。
- 直接展示 toast、dialog、bottom sheet。
- 了解具体 Widget 结构。

### Application Use Case

允许：

- 编排多个 service/repository。
- 返回结构化结果。
- 处理业务状态和错误类型。

不允许：

- 依赖 `BuildContext`。
- 展示 toast/dialog。
- 直接操作 Widget。

### Service

允许：

- 封装平台或外部系统能力，如 TTS、NFC、OCR、AI、文件、存储。
- 暴露 stream/result。

不允许：

- 知道页面路由。
- 知道弹窗/toast。
- 持有 UI 状态。

## 阶段计划

### 阶段 0：建立基线和约束

目标：确保后续每一步都能判断是否引入回归。

任务：

- 记录当前大文件行数。
- 运行 `fvm flutter analyze`，记录已有问题。
- 确认 `test/` 中现有测试可运行。
- 确认 `BookReaderPage` 当前功能入口：普通阅读、NFC 自动播放、deep link 自动播放、文字块长按菜单、翻译显示、语音设置。

验收标准：

- 有一份基线分析结果。
- 明确哪些 analyze 问题是重构前已有。

推荐命令：

```bash
find lib -name '*.dart' -print0 | xargs -0 wc -l | sort -nr | head -40
fvm flutter analyze
fvm flutter test
```

风险：低。

### 阶段 1：修复生命周期和低风险问题

目标：先修复无需架构大改的明显问题。

任务：

- 将 `_pageController` 从 `build` 中移到 `initState` 初始化。
- 在 `dispose` 中调用 `_pageController.dispose()`。
- 检查 `_pageController.jumpToPage` 前是否已经初始化。
- 保持当前页初始值来自 `_book.currentPageIndex`。

验收标准：

- `BookReaderPage.build` 中不再创建 `PageController`。
- 页面翻页行为不变。
- `fvm flutter analyze` 通过，或仅剩已有问题。

风险：低。

### 阶段 2：先拆纯 UI 组件

目标：不改业务，只把大段 Widget 私有方法拆到 reader widgets。

推荐拆分：

- `_buildReadingBar` -> `ReaderReadingBar`
- `_buildFocusBorder` -> `ReaderFocusBorder`
- 空页面分支 -> `ReaderEmptyState`
- AppBar actions -> `ReaderAppBar`
- 长按操作菜单 -> `ReaderBlockActionsSheet`
- 语音设置弹窗 -> `ReaderVoiceSettingsDialog`
- NFC 绑定弹窗 -> `ReaderNfcBindDialog`

实施顺序：

1. 先拆 `ReaderReadingBar`，因为它是清晰的展示组件。
2. 再拆 `ReaderFocusBorder`，保留 animation 参数从父组件传入。
3. 再拆 `ReaderEmptyState` 和 `ReaderAppBar`。
4. 最后拆 bottom sheet/dialog，因为它们带回调和局部 loading 状态。

组件参数原则：

- 传入展示所需数据，不传整个页面 state 对象，除非字段很多且稳定。
- 事件通过 callback 暴露，如 `onStopPlaying`、`onReplay`、`onClose`。
- 不在 widget 内直接读 service。

验收标准：

- `BookReaderPage` 行数降低到 1200 行左右。
- 没有改变阅读行为。
- UI 文案仍为中文。
- `fvm flutter analyze` 通过。

风险：低到中。主要风险是 callback 参数遗漏。

### 阶段 3：将 ReadingState 升级为 ReaderState + Notifier

目标：让阅读状态成为 Riverpod 状态源。

建议新增：

```text
lib/presentation/features/reader/models/reader_state.dart
lib/presentation/features/reader/view_models/reader_notifier.dart
```

`ReaderState` 字段建议：

- `BookModel book`
- `int currentIndex`
- `int? playingBlockIndex`
- `int? loadingBlockIndex`
- `String? playingText`
- `bool showBorders`
- `bool showAppBar`
- `bool showTranslation`
- `int? translatedBlockIndex`
- `String? translatedText`
- `bool isTranslating`
- `TranslationStatus translationStatus`

`ReaderNotifier` 方法建议：

- `initialize(BookModel book)`
- `setCurrentIndex(int index)`
- `toggleAppBar()`
- `toggleBorders()`
- `toggleTranslation()`
- `setPlaybackLoading(int blockIndex, String text)`
- `setPlaybackStarted()`
- `clearPlayback()`
- `setTranslationLoading(int blockIndex)`
- `setTranslationResult(...)`
- `clearTranslation()`
- `updateBook(BookModel book)`

迁移策略：

- 先保留旧 `ReadingState` 文件，新增 reader feature 下的新状态。
- 页面改为 `ref.watch(readerProvider)`。
- 原本的 `_readingState.copyWith` 逐步替换为 notifier 方法。
- 迁完后删除或迁移旧 `lib/presentation/providers/reading_state.dart`。

验收标准：

- `BookReaderPage` 不再持有 `_readingState` 字段。
- 状态更新主要通过 `ReaderNotifier`。
- 页面切换、播放、翻译栏显示行为不变。
- copyWith nullable clear flag 行为有单元测试。

风险：中。状态字段多，容易漏迁。

### 阶段 4：抽离阅读播放流程

目标：把 `_playTextBlock`、`_stopPlaying`、`_replayCurrentBlock` 从页面搬出。

建议新增：

```text
lib/application/reading/play_text_block_use_case.dart
```

职责：

- 停止旧播放。
- 调用 TTS 播放。
- 返回播放开始、失败、完成所需结构化结果。

更现实的短期方案：

- TTS 调用仍由 `ReaderNotifier` 执行。
- 页面只在点击命中后调用 `notifier.playBlock(block, index)`。
- 动画相关仍由页面监听 `playingBlockIndex` 后触发，或由页面 callback 触发。

需要注意：

- `AnimationController` 依赖 `TickerProvider`，不要塞进 notifier。
- 焦点框计算可以抽成纯函数，如 `ReaderFocusCalculator`。
- `TtsService.stateStream` 已存在，应继续使用 stream/provider，不回退到全局回调。

验收标准：

- 页面不再直接调用 `ttsServiceProvider.speak/stop`。
- 页面不再直接管理 `playingText`、`loadingBlockIndex`。
- 连续点击文字块时旧播放能停止，新播放能开始。
- loading spinner 和焦点框行为不变。

风险：中。TTS 和动画的边界要切清楚。

### 阶段 5：抽离翻译和缓存流程

目标：把 `_translateBlock` 从页面移出。

建议新增：

```text
lib/application/reading/translate_text_block_use_case.dart
```

返回类型建议：

```dart
class TranslateTextBlockResult {
  final TranslationStatus status;
  final String? translatedText;
  final TextBlockModel? updatedBlock;
  final bool shouldPersist;
  final String? message;
}
```

职责：

- 优先读取 `aiTranslatedText`。
- 其次读取人工 `translatedText`。
- 没有缓存时调用 `TranslationService.translateWithStatus`。
- 翻译成功后生成带 `aiTranslatedText` 的新 `TextBlockModel`。
- 不展示 toast，不直接弹窗。

验收标准：

- 页面不再直接调用 `translationServiceProvider.translateWithStatus`。
- 翻译成功后仍能缓存到文字块。
- 翻译失败、下载模型、翻译中状态仍正确显示。
- 默认日志不输出儿童阅读文本或翻译内容。

风险：中。

### 阶段 6：收口文字块更新

目标：统一阅读页内文字块写入路径。

建议新增：

```text
lib/application/reading/update_reader_block_use_case.dart
```

职责：

- 根据 `bookId + pageIndex + blockIndex` 更新一个文字块。
- 内部通过 `BookRepository.updatePageTextBlocks` 完成保存。
- 返回更新后的 `BookModel` 或 `PageModel`，避免页面持有旧引用。

需要处理的调用点：

- 编辑文字保存。
- 编辑翻译保存。
- AI 翻译填充保存。
- 自动翻译缓存保存。

验收标准：

- 阅读页不再手写 `List<TextBlockModel>.from(page.textBlocks)`。
- 阅读页不直接调用 `bookRepositoryProvider.updatePageTextBlocks`。
- 保存后 UI 使用最新 book/state。

风险：中。Hive 对象引用可变，必须确认 UI 和存储同步。

### 阶段 7：拆编辑弹窗和 AI 填充流程

目标：让编辑弹窗变成独立组件，AI 操作变成可复用流程。

推荐拆分：

- `ReaderBlockEditSheet`：编辑原文。
- `ReaderTranslationEditSheet`：编辑翻译。
- `ReaderBlockActionsSheet`：长按后的动作列表。

AI 相关：

- 复用现有 `TextBlockAiUseCase`。
- 页面或 sheet 只处理 loading 和把结果写入 controller。
- 错误和无结果通过统一结果对象映射到 toast。

验收标准：

- `_editBlockText`、`_editBlockTranslation`、`_aiEnhanceAndFill`、`_aiTranslateAndFill` 不再集中在页面中。
- 编辑原文时仍会清空旧翻译。
- 编辑翻译时仍会更新当前阅读栏翻译。
- API key 缺失仍提示“请先在设置中配置 API Key”。

风险：中。弹窗内 `StatefulBuilder` 局部状态迁移时要保证 loading 按钮状态正确。

### 阶段 8：拆 NFC 绑定流程

目标：页面只触发“绑定 NFC”，不实现写标签流程。

建议新增：

```text
lib/application/reading/bind_nfc_block_use_case.dart
lib/presentation/features/reader/widgets/reader_nfc_bind_dialog.dart
```

Use case 职责：

- 检查 NFC 是否可用。
- 调用 `NfcService.writeTag(bookId, pageId, blockId)`。
- 把 `NfcException` 转成结构化错误。

Dialog 职责：

- 展示文字块摘要。
- 展示写入中/错误/重新绑定状态。
- 调用 use case 或 notifier 暴露的绑定方法。

验收标准：

- 页面不直接调用 `nfcService.writeTag`。
- 设备不支持 NFC 时仍提示“此设备不支持 NFC 功能”。
- 写入失败时可重新绑定。
- iOS AppBar 手动扫描入口保留。

风险：中高。NFC 需要真机验证。

### 阶段 9：拆语音设置弹窗

目标：把 `_showVoiceSettingsDialog` 从页面移出，并收口语速保存。

推荐拆分：

- `ReaderVoiceSettingsDialog`
- 可选 `VoiceSettingsUseCase`

职责：

- 读取当前 TTS engine。
- 根据 engine 决定语速范围和 divisions。
- 保存 `AiSettingsModel.speechRate`。
- 页面只负责打开弹窗和接收保存后的 rate。

验收标准：

- 页面不再包含整段语音设置 UI。
- “更多设置”仍跳转 `/settings`。
- 保存后 toast 仍显示“语速已调整”。
- 系统 TTS 和 Supertonic 速度范围不变。

风险：低到中。

### 阶段 10：重组阅读视图

目标：让 `BookReaderPage` 变成薄路由入口。

推荐形态：

```dart
class BookReaderPage extends ConsumerStatefulWidget {
  // only route args
}

class _BookReaderPageState extends ConsumerState<BookReaderPage>
    with TickerProviderStateMixin {
  // lifecycle subscriptions + animation controllers

  @override
  Widget build(BuildContext context) {
    return BookReaderView(...);
  }
}
```

`BookReaderView` 负责组合：

- `ReaderAppBar`
- `ReaderGallery`
- `ReaderReadingBar`
- `PageIndicator`
- hidden app bar tap zone

验收标准：

- `BookReaderPage` 低于 300 行。
- `BookReaderView` 低于 500 行。
- 单个 reader widget 尽量低于 250 行。
- 没有新的 1000 行类。

风险：中。组合层参数会变多，需要及时抽展示数据。

### 阶段 11：补架构保护测试

目标：给纯逻辑加最小测试，防止后续继续胖回页面。

优先测试：

- `ReaderState.copyWith` nullable clear flag。
- 图片坐标转换和文字块命中测试，如果抽为纯函数。
- 翻译 use case 对 `aiTranslatedText`、`translatedText`、在线翻译结果的优先级。
- 文字块更新 use case 能正确替换目标 block，不影响其他 block。
- NFC action payload transformation，如 `dianduya://play/<bookId>/<pageId>/<blockId>`。

验收标准：

- 涉及纯逻辑的新 public 行为有测试。
- `fvm flutter test` 通过。

风险：低。

## 推荐提交顺序

建议按以下顺序小步提交：

1. 修复 `PageController` 生命周期。
2. 拆 `ReaderReadingBar`、`ReaderFocusBorder`、`ReaderEmptyState`。
3. 拆 `ReaderAppBar`。
4. 拆 block action sheet、编辑 sheet。
5. 新增 `ReaderState` 和 `ReaderNotifier`，迁移 show/toggle/currentIndex 状态。
6. 迁移播放状态到 notifier。
7. 抽翻译 use case。
8. 抽文字块更新 use case。
9. 抽 NFC 绑定 use case/dialog。
10. 抽语音设置 dialog。
11. 引入 `BookReaderView`，把 `BookReaderPage` 压成路由入口。
12. 补测试和清理旧 `ReadingState` 文件。

## 文件级任务清单

### `lib/presentation/pages/book_reader_page.dart`

- 移除 build 内 `PageController` 创建。
- 移除 `_readingState` 本地字段。
- 移除大段 `_build...` 私有 widget 方法。
- 移除编辑弹窗和 NFC/语音弹窗构建逻辑。
- 移除直接业务调用，改为 notifier/use case。
- 最终只保留路由参数、生命周期订阅、动画 controller、`BookReaderView` 组装。

### `lib/presentation/providers/reading_state.dart`

- 短期保留，避免一次性迁移。
- 中期迁移到 `presentation/features/reader/models/reader_state.dart`。
- 迁移完成后删除旧文件或改为 re-export，避免双状态模型长期共存。

### `lib/application/reading/text_block_ai_use_case.dart`

- 保留并继续作为 AI 优化/翻译入口。
- 后续改为注入 repository/service，而不是直接 `.instance`，但不作为第一阶段目标。
- 统一 `TextBlockAiResult` 的错误、无结果、成功语义。

### `lib/data/repositories/book_repository.dart`

- 视需要增加更细的文字块更新方法。
- 保持页面不直接接触 Hive 保存。

### `lib/presentation/features/reader/`

- 作为阅读功能的主要新归宿。
- 避免把所有逻辑塞到一个 `reader_notifier.dart`，超过 600 行时继续拆 use case 或 helper。

## 验收指标

### 结构指标

- `BookReaderPage`：低于 300 行。
- `BookReaderView`：低于 500 行。
- 单个 reader widget：尽量低于 250 行。
- 单个 use case：尽量低于 250 行。
- 页面层不出现 `_book.save()`。
- 页面层不直接修改 `_book.pages[...]`。
- 页面层不直接调用 `TranslationService.translateWithStatus`。
- 页面层不直接调用 `NfcService.writeTag`。

### 行为指标

- 普通点击文字块能播放。
- 点击另一个文字块能停止旧播放并播放新文字块。
- loading 状态、播放边框、焦点动画正常。
- 翻译开关正常。
- 翻译缓存正常。
- 长按菜单正常。
- 编辑原文/翻译正常保存。
- AI 优化/AI 翻译仍能填充输入框。
- NFC 标签绑定正常。
- NFC/deep link 自动播放正常。
- 语音设置正常保存。
- 空读本页面正常显示。
- 横竖屏均无明显布局异常。

### 验证命令

每个阶段至少运行：

```bash
fvm flutter analyze
```

涉及纯逻辑或模型行为时运行：

```bash
fvm flutter test
```

涉及 Hive model 变更时才运行：

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

本计划不要求修改 Hive 字段。若后续必须修改，禁止重排已有 `typeId` 和 `@HiveField` 编号。

## 风险和应对

### 风险：一次性迁移太大

应对：

- 先拆纯 UI。
- 每次只移动一个稳定区域。
- 每阶段运行 analyze。
- 保持旧行为，再调整结构。

### 风险：Notifier 变成新的巨型类

应对：

- Notifier 只管理状态和调用 use case。
- 超过 600 行时强制拆 use case。
- AI、翻译、NFC、文字块更新不放进 notifier 内部细节。

### 风险：动画和状态边界不清

应对：

- `AnimationController` 留在 page/view。
- 纯计算抽 helper。
- notifier 只暴露“当前播放块变化”。
- view 根据状态变化触发动画。

### 风险：Hive 可变引用导致 UI 不刷新

应对：

- 更新文字块后返回新的 book/page 数据。
- notifier 持有最新 `BookModel`。
- 避免页面继续使用旧 `_book` 引用。

### 风险：NFC 需要真机验证

应对：

- NFC 绑定阶段单独提交。
- 保留当前 payload：`dianduya://play/<bookId>/<pageId>/<blockId>`。
- Android 和 iOS 分别手测。
- 把 parse/action transformation 写成纯测试。

### 风险：弹窗拆分后 context 生命周期错误

应对：

- 异步后检查 `context.mounted`。
- 弹窗内部 loading 状态局部化。
- use case 不持有 `BuildContext`。

## 代码审查清单

每次重构 PR/提交检查：

- 是否减少 `BookReaderPage` 行数，而不是把复杂度搬到另一个大文件。
- 新文件是否符合 reader feature 目录结构。
- 页面是否仍有业务编排、service 直接调用或持久化写入。
- Riverpod provider 是否成为主要状态来源。
- UI 文案是否保持中文。
- 是否使用 `.withValues(alpha:)`，没有重新引入 `.withOpacity()`。
- 是否保留语义化按钮或 `SemanticsIconButton`。
- 默认日志是否没有输出儿童阅读文本、OCR 内容、AI 响应、翻译内容。
- 是否运行了本阶段要求的验证命令。

## 建议第一轮落地范围

第一轮建议只做低风险瘦身：

1. 修复 `PageController` 生命周期。
2. 新增 `ReaderReadingBar`。
3. 新增 `ReaderFocusBorder`。
4. 新增 `ReaderEmptyState`。
5. 新增 `ReaderAppBar`。
6. 运行 `fvm flutter analyze`。

预期收益：

- `BookReaderPage` 从约 1900 行降到约 1200-1400 行。
- 不触碰核心业务行为。
- 为后续 notifier/use case 迁移创造清晰边界。

第二轮再迁移 `ReaderState/ReaderNotifier`，不要和第一轮混在一起。

## 当前进度快照（2026-06-18）

本轮重构已经完成阅读页 UI 瘦身、视图拆分、状态迁移、播放/翻译 use case 抽离及审查修复。当前 Git 工作区干净。

### 已完成提交

```text
d612fe4 fix reader translate use case nullable text and testability
2b408a8 refactor reader translate use case
44d43a6 refactor reader play use case
7de9f1b fix reader playback race on consecutive taps
d6f483e fix reader provider scope and lifecycle
bd9d6a6 refactor reader state notifier
081d0b7 refactor reader book view
ed4927e refactor reader gallery
98f87e7 refactor reader voice settings dialog
5082fff refactor reader nfc bind dialog
59f08ee refactor reader text edit sheet
baf442f refactor reader UI widgets
```

### 已完成内容

1. 修复 `PageController` 生命周期

- 原问题：`BookReaderPage.build` 中创建并赋值 `_pageController`，rebuild 时可能重复创建，且没有释放。
- 当前状态：已改为 `initState` 初始化，`dispose` 中释放。

2. 抽离纯 UI 组件

已新增：

```text
lib/presentation/features/reader/widgets/reader_app_bar.dart
lib/presentation/features/reader/widgets/reader_block_actions_sheet.dart
lib/presentation/features/reader/widgets/reader_empty_state.dart
lib/presentation/features/reader/widgets/reader_focus_border.dart
lib/presentation/features/reader/widgets/reader_reading_bar.dart
```

3. 抽离编辑弹窗

已新增：

```text
lib/presentation/features/reader/widgets/reader_text_edit_sheet.dart
```

当前行为：

- 编辑原文和编辑翻译共用 `ReaderTextEditSheet`。
- 页面保留保存逻辑和 AI 请求入口。
- AI 优化/AI 翻译仍调用现有 `TextBlockAiUseCase`。

4. 抽离 NFC 绑定弹窗

已新增：

```text
lib/presentation/features/reader/widgets/reader_nfc_bind_dialog.dart
```

当前行为：

- 弹窗组件负责写入中、错误、重试和成功关闭 UI。
- 页面仍负责 NFC 可用性检查、调用 `NfcService.writeTag`、转换 `NfcException` 错误消息。
- NFC payload 未改变，仍是 `dianduya://play/<bookId>/<pageId>/<blockId>`。

5. 抽离语音设置弹窗

已新增：

```text
lib/presentation/features/reader/widgets/reader_voice_settings_dialog.dart
```

当前行为：

- 弹窗组件负责语速 slider、engine 标签、更多设置入口和确认按钮 UI。
- 页面保留 `_saveSpeechRate`，负责读取/保存 `AiSettingsModel.speechRate` 并提示“语速已调整”。

6. 抽离 ReaderGallery

已新增：

```text
lib/presentation/features/reader/widgets/reader_gallery.dart
```

当前行为：

- 组件负责 `PhotoViewGallery.builder`、图片文件/placeholder 展示、`ReadingTextBlockPainter`、挂载 `ReaderFocusBorder`。
- 通过 callback 暴露 `onTapDown`、`onTapUp`、`onScaleEnd`、`onDoubleTap`、`onPageChanged`。
- 页面保留 `_imageFile`、`_onTapDown`、`_handleTapUp`、`_cancelLongPress`、`_clearTranslation`、`_pageController`、动画 controller。
- 不改播放、翻译、NFC、保存逻辑。

7. 抽离 BookReaderView

已新增：

```text
lib/presentation/features/reader/views/book_reader_view.dart
```

当前行为：

- view 负责 `Scaffold` 组装（含空读本分支）、`ReaderAppBar`、隐藏顶部栏触摸区、`ReaderGallery`、`ReaderReadingBar`、`PageIndicator` 的组合。
- view 为 `StatelessWidget`，只接收 `ReaderState` + 动画展示字段 + 平台标志 + callback，不持有 `ref`。
- 页面 `build` 只保留 `_viewportSize` 读取、`nfcEnabledProvider` watch、回调闭包和 `BookReaderView` 组装。
- `onPageChanged` 闭包仍在页面内执行 `setState` + `_clearTranslation` + `bookRepositoryProvider.updateCurrentPageIndex`。
- 未迁移状态，未触碰播放/翻译/NFC/保存逻辑。

8. 抽离 ReaderState / ReaderNotifier

已新增：

```text
lib/presentation/features/reader/models/reader_state.dart
lib/presentation/features/reader/view_models/reader_notifier.dart
```

当前行为：

- `ReaderState` 为不可变状态类，字段与旧 `ReadingState` 一致，保留 nullable clear flag 语义。
- `ReaderNotifier` 暴露 `initialize`、`setCurrentIndex`、`toggleAppBar`、`toggleBorders`、`toggleTranslation`、`setPlaybackLoading`、`setPlaybackStarted`、`clearPlayback`、`setTranslationLoading`、`setCachedTranslation`、`setTranslationResult`、`setTranslatedBlock`、`clearTranslation`、`updateBook`。
- 页面不再持有 `_readingState` 字段；`build` 通过 `ref.watch(readerProvider)` 读取，动作通过 `ref.read(readerProvider.notifier)` 调用。
- TTS 播放状态、翻译展示状态、toggle 状态全部由 notifier 收口；动画 controller/`_pageController`/`_longPressTimer`/焦点 rect 仍留在页面。
- 编辑翻译保存后通过 `notifier.setTranslatedBlock` 更新阅读栏翻译。
- 删除旧 `lib/presentation/providers/reading_state.dart` 及其测试，新增 `test/reader_state_test.dart` 覆盖 copyWith clear flag 行为。
- 已修复 `readerProvider` 在 `initState` 修改导致的 build 周期崩溃：改为路由层 `ProviderScope` override 注入 `BookModel`，`ReaderNotifier` 改为 `AutoDisposeNotifier` 构造注入，页面卸载自动释放；同时解决多 reader 实例共享全局状态问题。
- 已修复连续点击文字块的播放状态竞争：旧 `speak` Future 被取消后恢复会无条件 `clearPlayback`，现改为 `_clearPlaybackIfCurrent(blockIndex, text)` 校验当前 state 仍属于本次播放才清理。

9. 抽离播放流程 use case

已新增：

```text
lib/application/reading/play_text_block_use_case.dart
```

当前行为：

- use case 持有 `TtsService`，暴露 `stop()`、`speak(text)`、`isPlaying`，返回结构化 `PlayTextBlockResult { phase, text }`。
- 新增 `playTextBlockUseCaseProvider` 注入 `TtsService`。
- 页面 `_playTextBlock`/`_stopPlaying` 改为调用 `playTextBlockUseCaseProvider`，不再直接调 `ttsServiceProvider.speak/stop`。
- `setPlaybackLoading`/`clearPlayback` 状态仍由 `ReaderNotifier` 管理；动画 controller/`_pageController`/焦点 rect 仍留在页面。
- 平台初始化 `TtsService.instance.initialize()` 和 `stateStream` 订阅保留在页面（不属于播放编排）。
- 连续点击竞争修复沿用 `_clearPlaybackIfCurrent`。

10. 抽离翻译和缓存流程 use case

已新增：

```text
lib/application/reading/translate_text_block_use_case.dart
test/translate_text_block_use_case_test.dart
```

当前行为：

- use case 通过 `typedef TranslateWithStatusFn` 注入翻译调用，暴露同步 `cachedTranslation(block)`（优先 `aiTranslatedText`，其次 `translatedText`）和异步 `translate(block, blockIndex)`（返回 `TranslateTextBlockResult { phase: translated|failed, status, translatedText?, updatedBlock?, shouldPersist }`）。
- 新增 `translateTextBlockUseCaseProvider`，注入 `translationServiceProvider.translateWithStatus`。
- 页面 `_translateBlock` 先用 `cachedTranslation` 命中即 `setCachedTranslation`，未命中先 `setTranslationLoading` 再调 use case，结果回填 `setTranslationResult`，`shouldPersist` 时持久化更新后的 block。
- 页面不再直接调用 `translationServiceProvider.translateWithStatus`，也不再手写 `block.copyWith(aiTranslatedText: ...)`。
- 翻译失败/下载模型/翻译中状态仍由 notifier `setTranslationResult` 正确展示。
- use case 不展示 toast、不弹窗、不持有 `BuildContext`。
- 单元测试覆盖 `cachedTranslation` 三种优先级，以及 `translate` 的 done/失败/done 但 text 为 null 三条 async 路径（通过注入假函数，无需真实 `TranslationService`）。

审查修复（d612fe4）：

- `TranslateTextBlockResult.translatedText` 改为 `String?`，失败路径透传 `result.translatedText`（可能为 null）而非 `?? ''`，避免 `ReaderReadingBar` 把空字符串当作成功翻译渲染空框，失败态仍显示“翻译失败”。
- use case 依赖从具体 `TranslationService` 改为 `TranslateWithStatusFn` 函数注入，解除私有构造限制，async 路径可被单元测试覆盖。

### 当前行数

```text
773  lib/presentation/pages/book_reader_page.dart
43   lib/application/reading/play_text_block_use_case.dart
70   lib/application/reading/translate_text_block_use_case.dart
74   lib/presentation/features/reader/models/reader_state.dart
119  lib/presentation/features/reader/view_models/reader_notifier.dart
174  lib/presentation/features/reader/views/book_reader_view.dart
134  lib/presentation/features/reader/widgets/reader_app_bar.dart
110  lib/presentation/features/reader/widgets/reader_block_actions_sheet.dart
73   lib/presentation/features/reader/widgets/reader_empty_state.dart
57   lib/presentation/features/reader/widgets/reader_focus_border.dart
122  lib/presentation/features/reader/widgets/reader_gallery.dart
181  lib/presentation/features/reader/widgets/reader_nfc_bind_dialog.dart
202  lib/presentation/features/reader/widgets/reader_reading_bar.dart
154  lib/presentation/features/reader/widgets/reader_text_edit_sheet.dart
223  lib/presentation/features/reader/widgets/reader_voice_settings_dialog.dart
```

`BookReaderPage` 已从约 1915 行降到 773 行。播放与翻译编排均已收口到 use case。

### 已验证

每个切片完成后都对阅读页和 reader widgets 做过局部静态检查：

```bash
fvm flutter analyze lib/presentation/pages/book_reader_page.dart lib/presentation/features/reader/widgets/...
```

结果：局部分析通过。

说明：全项目 `fvm flutter analyze` 仍会报告大量既有 info/warning，当前未作为本轮目标处理。

## 后续续作计划

### 下一步优先级 1：收口文字块更新 use case

目标：统一阅读页内文字块写入路径。

建议新增：

```text
lib/application/reading/update_reader_block_use_case.dart
```

职责：

- 根据 `bookId + pageIndex + blockIndex` 更新一个文字块。
- 内部通过 `BookRepository.updatePageTextBlocks` 完成保存。
- 返回更新后的 `BookModel` 或 `PageModel`，避免页面持有旧引用。

验收标准：

- 阅读页不再手写 `List<TextBlockModel>.from(page.textBlocks)`。
- 阅读页不直接调用 `bookRepositoryProvider.updatePageTextBlocks`。
- 保存后 UI 使用最新 book/state。

### 暂缓事项

暂时不要做：

- 大规模改 `BookRepository` 接口。
- 同时迁移 NFC handler 和 ReaderNotifier。
- 改 Hive model。
- 改 Android/iOS 原生 NFC 配置。

这些属于后续阶段，先把阅读页继续稳定瘦身。

## 后续恢复工作提示

如果从新会话继续，建议先运行：

```bash
git status --short
git log --oneline -5
wc -l lib/presentation/pages/book_reader_page.dart lib/presentation/features/reader/**/*.dart
```

然后从“下一步优先级 1：收口文字块更新 use case”开始。
