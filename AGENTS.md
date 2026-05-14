# AGENTS.md — 点读鸭 (DianDuYa) Book App

## Essential Commands

```bash
flutter analyze                            # lint + typecheck (0 errors required)
dart format lib/                           # auto-format
flutter pub run build_runner build --delete-conflicting-outputs  # regenerate Hive .g.dart files after model changes
```

No test suite exists (`test/` is empty). No CI. SDK managed via FVM at `.fvm/versions/stable`.

## Architecture

**App type**: Flutter children's English picture-book tap-to-read app with OCR + AI text enhancement.

```
lib/
├── app.dart                    # MaterialApp.router with warm child-friendly theme
├── main.dart                   # Entry: init services, ProviderScope, run app
├── core/                       # Router (GoRouter), theme, constants, ToastUtil
├── data/                       # Services (singletons x .instance), repos, Hive models
├── presentation/
│   ├── providers/              # Global Riverpod providers (books, settings, TTS, DI)
│   ├── features/text_detection/# Feature module (models/view_models/views/widgets)
│   ├── pages/                  # Full-screen pages
│   └── widgets/                # Shared widgets
```

## State Management (Riverpod 2.x)

### Provider lifecycle — CRITICAL distinction:

| Scope | Base Class | Registration | When disposed |
|-------|-----------|-------------|---------------|
| Page-level | `AutoDisposeNotifier<T>` | `NotifierProvider.autoDispose` | On pop |
| Global | `Notifier<T>` | `NotifierProvider` | Never |

- **`textDetectionProvider`** uses `AutoDisposeNotifier` — the ONLY page-level provider. It owns a `TransformationController` that must be disposed in `ref.onDispose()` inside `build()`.
- **All other notifiers** (`BooksNotifier`, `SettingsNotifier`, `TtsNotifier`) use plain `Notifier` — they persist across navigation.
- Do NOT add `autoDispose` to global providers — state would be lost on page transitions.

### ref.read vs ref.watch:
- `ref.watch` inside widget `build()` methods AND inside derived `Provider` declarations
- `ref.read` inside Notifier async methods (event handlers, `saveApiKey`, etc.)
- `ref.read(provider.notifier)` in widget `build()` to get the notifier for calling methods
- The codebase follows this correctly — never use `ref.read` in build() or `ref.watch` in Notifier methods

### User feedback — use ToastUtil, not SnackBar:
- `ToastUtil.success/error/warning/info` — for all user feedback messages
- `showDialog` with `AlertDialog` — for confirmation prompts (user must choose an action)
- Do NOT use `ScaffoldMessenger.showSnackBar()` anywhere — the app uses ToastUtil exclusively
- Theme's `snackBarTheme` has been removed; do not re-add it

## Key Gotchas

### Hive codegen is mandatory
Models with `@HiveType`/`@HiveField` require matching `.g.dart` files. After any model field change, run the build_runner command above. Missing `.g.dart` = runtime crash.

### TextDetection feature structure
- View: `ConsumerStatefulWidget` (in `views/`)
- State: immutable `copyWith` class with special `clear*` bool flags (set field to null when true)
- ViewModel: `AutoDisposeNotifier` (in `view_models/`)
- Provider defined at bottom of viewmodel file (NOT in `presentation/providers/`)
- BottomToolbar: 4 adaptive states based on mode + selection
- Canvas has 3 modes: `view` (pan/zoom), `draw` (draw new regions), `edit` (move/resize blocks)
- Only English text blocks are interactive (Chinese blocks are filtered out)

### SettingsProvider async init
`build()` returns default state synchronously, then `_loadSettings()` runs async. Initial state has `isLoading = true`. Consumers that depend on derived providers (`hasApiKeyProvider`, `selectedModelProvider`) must handle loading state. Use `ref.watch` to stay reactive — `FutureBuilder` won't refresh after provider state changes.

### BookManagePage is NOT Riverpod
It's a plain `StatefulWidget` using `setState` and direct service calls (`BookService.instance`). When editing, don't try to refactor it to Riverpod unless you coordinate with the rest of the page logic.

### Services are singletons
All services use `static final _instance` pattern. Access via `.instance`. In notifiers, prefer `ref.read(repositoryProvider)` over direct `.instance` calls, except for `AiService.instance.hasApiKey()` checks before AI operations.

### Derived providers must use ref.watch (not ref.read)
`selectedModelProvider` and `hasApiKeyProvider` derive from `settingsProvider`. If they use `ref.read`, they will NOT reactively update when the source provider changes. Always verify derived providers use `ref.watch`.

## Accessibility (CRITICAL — Required for All Interactive Elements)

### Semantics widget — ALWAYS wrap interactive elements
All tappable/clickable elements MUST have `Semantics` wrapper with proper labels:

```dart
// CORRECT — IconButton with Semantics
Semantics(
  label: '设置',
  hint: '打开应用设置页面',
  button: true,
  child: IconButton(
    icon: const Icon(Icons.settings),
    onPressed: () => context.push('/settings'),
    tooltip: '设置',  // tooltip still useful for visual users
  ),
)

// CORRECT — GestureDetector with Semantics
Semantics(
  label: block.text,
  hint: '点击播放朗读',
  button: true,
  child: GestureDetector(
    onTap: () => _playTextBlock(block),
    child: Container(...),
  ),
)
```

### Minimum touch target size — 44×44pt (iOS) / 48×48dp (Android)
- Flutter's `IconButton` has default 48x48 minimum — acceptable
- Custom GestureDetector/Container MUST ensure >= 44x44pt hit area
- Use `padding: const EdgeInsets.all(10)` minimum for small icons (24px)
- `hitSlop` not available in Flutter — use padding or larger container

### Do NOT skip Semantics for:
- IconButton (wrap with Semantics, not just tooltip)
- GestureDetector with custom visual
- FloatingActionButton
- InkWell
- Any element user can tap/click

### Canvas-based interactive content (TextDetectionView, TextBlockPainter)
For CustomPaint with interactive regions:
- Add hidden Semantics nodes positioned over each interactive region
- Use `Semantics(hidden: true, button: true, label: '...')` + `SizedBox.expand()` to make invisible but accessible
- See `book_detail_page.dart` `_buildTextBlockTapAreas` for pattern

## Navigation — GoRouter Only

### All page navigation MUST use GoRouter
The app uses GoRouter (`lib/core/router/app_router.dart`). All full-screen page navigation must use `context.push()` or `context.go()`:

```dart
// CORRECT — GoRouter navigation
context.push('/settings');
context.push('/settings/ai');
context.go('/');  // for root-level replacement

// WRONG — Do NOT use Navigator.push for full-screen pages
Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage()));
```

### Routes registered in app_router.dart
| Path | Name | Page |
|------|------|------|
| `/` | home | HomePage |
| `/book/:id` | book_detail | BookDetailPage |
| `/book/:id/manage` | book_manage | BookManagePage |
| `/settings` | settings | SettingsPage |
| `/settings/ai` | ai_settings | AiSettingsPage |
| `/settings/voice` | voice_settings | VoiceSettingsPage |
| `/settings/cache` | cache_management | CacheManagementPage |
| `/tutorial` | tutorial | TutorialPage |

### Exception: Modal/Sheet pages with callbacks
Pages that need to return results (like TextDetectionPage with `onSave` callback) may use `Navigator.push` — these are modal workflows, not navigation:

```dart
// Acceptable — Modal with callback
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => TextDetectionPage(
      onSave: (textBlocks, imageFile) async { ... },
    ),
  ),
);
```

## Performance — Async File Operations

### NEVER use synchronous file I/O on main thread
`File.readAsBytesSync()` blocks the UI thread and causes jank:

```dart
// WRONG — Blocks main thread
final bytes = file.readAsBytesSync();

// CORRECT — Async, non-blocking
final bytes = await file.readAsBytes();
final decodedImage = await decodeImageFromList(bytes);
```

### Applies to:
- `_getImageSize()` and similar image dimension methods
- Any `File.read*` or `File.write*` operations
- Use `await` and handle in FutureBuilder or async state

## Color Scheme — Unified Theme Colors

### Three-color design principle
整个应用遵循**三色设计原则**：背景色 + 主色 + 中性色，确保视觉统一、专业。

| 色彩类型 | 用途 | API |
|---------|------|-----|
| **背景色** | 页面、卡片、容器 | `AppTheme.surfaceOf(context)` / `cardOf(context)` |
| **主色强调** | 按钮、图标、数字、滑块、选中状态 | `AppTheme.primaryOf(context)` |
| **中性文字** | 次要文字、标签、提示 | `AppTheme.onSurfaceOf(context).withValues(alpha: 0.6)` |

### Primary color usage — CRITICAL
**主色统一使用 `primaryOf(context)`**，用于所有强调元素：

```dart
// CORRECT — Unified primary color
Icon(Icons.save, color: AppTheme.primaryOf(context))
Slider(activeColor: AppTheme.primaryOf(context))
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppTheme.primaryOf(context).withValues(alpha: 0.85),
  ),
)

// WRONG — Using secondary/accent for emphasis
Icon(Icons.save, color: AppTheme.secondaryOf(context))  // 绿色与紫蓝背景冲突
```

**适用场景：**
- 图标（AppBar actions、列表项图标、功能按钮图标）
- 滑块（Slider `activeColor`）
- 数字显示（百分比、数量）
- 选中状态背景/边框
- 主要按钮背景

### Neutral text color — CRITICAL
**次要文字统一使用 `onSurfaceOf(context).withValues(alpha: 0.6)`**：

```dart
// CORRECT — Theme-aware neutral text
Text('当前语速', style: TextStyle(color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6)))

// WRONG — Using mutedOf(context) (太暗，深色模式下不够亮)
Text('当前语速', style: TextStyle(color: AppTheme.mutedOf(context)))
```

**适用场景：**
- 标签文字（"当前语速"、"缓存占用"等）
- 提示文字（"最慢-最快"范围标签）
- 次要信息（文件数量、版本号）
- 禁用状态文字

### Foreground color on colored buttons — CRITICAL
**按钮前景色使用 `Theme.of(context).colorScheme.onPrimary/onSecondary`**：

```dart
// CORRECT — Theme-aware button foreground
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppTheme.primaryOf(context).withValues(alpha: 0.85),
    foregroundColor: Theme.of(context).colorScheme.onPrimary,
  ),
  child: Text('保存'),
)

// WRONG — Hardcoded Colors.white
ElevatedButton(
  style: ElevatedButton.styleFrom(
    foregroundColor: Colors.white,  // 深色模式下可能不协调
  ),
)
```

### AppBar — Unified gradient
**所有页面 AppBar 统一使用 `appBarGradientOf(context)`**：

```dart
// CORRECT — Unified AppBar gradient
AppBar(
  flexibleSpace: Container(
    decoration: BoxDecoration(gradient: AppTheme.appBarGradientOf(context)),
  ),
  actions: [
    IconButton(
      icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onPrimary),
      onPressed: () => context.push('/settings'),
    ),
  ],
)

// WRONG — Custom gradient or hardcoded colors
AppBar(
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [Colors.blue, Colors.green]),
    ),
  ),
)
```

### Color API — Use withValues, NOT withOpacity
**使用新API `withValues(alpha: x)` 替代废弃的 `withOpacity(x)`**：

```dart
// CORRECT — New API
AppTheme.primaryOf(context).withValues(alpha: 0.85)
Colors.white.withValues(alpha: 0.9)

// WRONG — Deprecated API (causes precision loss)
AppTheme.primaryOf(context).withOpacity(0.85)
Colors.white.withOpacity(0.9)
```

### Functional white colors — Keep as-is
以下场景保持白色设计（功能性需求，非主题色）：

| 场景 | 原因 |
|------|------|
| 图片编辑工具栏 (bottom_toolbar) | 深色图片背景上的高对比度 |
| 页面指示器 (page_indicator) | 图片背景上的白色指示 |
| 加载进度指示器 | 深色背景上的可见性 |
| 状态横幅 (error/info banner) | 图片上的临时提示 |

```dart
// KEEP — Functional white on dark image background
Container(
  color: Colors.white.withValues(alpha: 0.2),
  child: Icon(Icons.draw, color: Colors.white),
)
```

### Color harmony in dark mode
深色模式背景为紫蓝色系 (#1A1520/#2A2230)，颜色搭配原则：

| 颜色 | 与紫蓝背景关系 | 评价 |
|------|---------------|------|
| `primaryOf` (橙色) | 邻近色系 | ✅ 柔和和谐 |
| `secondaryOf` (绿色) | 互补色 | ❌ 强对比，刺眼 |
| `accentOf` (黄色) | 邻近色系 | ✅ 柔和（用于标签/徽章） |

**禁止在深色模式使用绿色作为强调色**（与紫蓝背景产生刺眼的互补色对比）。

## Dark Theme — System Support

### App supports both light and dark themes
- `MaterialApp.router` configured with `theme: AppTheme.lightTheme`, `darkTheme: AppTheme.darkTheme`, `themeMode: ThemeMode.system`
- Theme automatically switches based on system setting
- All colors defined in `AppTheme` with both light and dark variants

### Dynamic color retrieval
Use `AppTheme.xxxOf(context)` methods to get theme-aware colors:

```dart
// CORRECT — Theme-aware color
Container(color: AppTheme.surfaceOf(context))

// WRONG — Hardcoded color (won't adapt to dark mode)
Container(color: AppTheme.surfaceColor)
```

### Available dynamic color methods:
- `AppTheme.primaryOf(context)` — Primary color
- `AppTheme.secondaryOf(context)` — Secondary color
- `AppTheme.accentOf(context)` — Accent/highlight color
- `AppTheme.backgroundOf(context)` — Background color
- `AppTheme.surfaceOf(context)` — Surface/card color
- `AppTheme.cardOf(context)` — Card background
- `AppTheme.onSurfaceOf(context)` — Text color
- `AppTheme.errorOf(context)` — Error color
- `AppTheme.mutedOf(context)` — Muted/disabled color
- `AppTheme.gradientBoxOf(context)` — Gradient background decoration

## Typography — Google Fonts

### App uses custom fonts for child-friendly design
- **Display/Headline fonts**: Fredoka (rounded, playful)
- **Body/Label fonts**: Nunito (clean, readable)
- Fonts loaded via `google_fonts` package at runtime

### Font usage in TextTheme:
| Style | Font | Usage |
|-------|------|-------|
| displayLarge/Medium | Fredoka | Hero titles |
| headlineLarge/Medium/Small | Fredoka | Section headers |
| titleLarge | Fredoka | Card titles |
| titleMedium/Small | Nunito | Subtitles |
| bodyLarge/Medium/Small | Nunito | Body text |
| labelLarge/Medium/Small | Nunito | Labels, captions |

### Use TextTheme from Theme.of(context)
```dart
// CORRECT — Use theme text style (includes custom font)
Text('Title', style: Theme.of(context).textTheme.headlineMedium)

// WRONG — Inline TextStyle (won't use custom font)
Text('Title', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600))
```

## Design Tokens — Consistent Spacing, Radius, and Icons

### Use AppSpacing, AppRadius, AppIconSize from app_tokens.dart
Avoid hardcoded values for spacing, border radius, and icon sizes. Use the defined tokens:

```dart
// CORRECT — Use design tokens
padding: AppSpacing.paddingMd  // 16px
borderRadius: AppRadius.md     // 16px
Icon(icon, size: AppIconSize.md) // 24px

// WRONG — Hardcoded values
padding: EdgeInsets.all(16)
borderRadius: BorderRadius.circular(16)
Icon(icon, size: 24)
```

### Available tokens:
| Token Class | Values |
|-------------|--------|
| `AppSpacing` | xs(4), sm(8), md(16), lg(24), xl(32), xxl(48) |
| `AppRadius` | sm(8), md(16), lg(24), pill(999) |
| `AppIconSize` | sm(16), md(24), lg(32), xl(48) |
| `AppFontSize` | xs(10), sm(12), base(14), md(16), lg(18), xl(20), xxl(24), hero(32), display(40) |
| `AppAnim` | quick(150ms), normal(250ms), slow(400ms) |

## AppBar Gradients — Reuse Predefined Gradients

### Use predefined AppBar gradients from AppTheme
AppBar gradients are defined in `AppTheme` for consistency:

```dart
// CORRECT — Use predefined gradient
AppBar(
  flexibleSpace: Container(
    decoration: const BoxDecoration(gradient: AppTheme.appBarGradient),
  ),
)

// WRONG — Inline gradient definition
AppBar(
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [AppTheme.softOrange, Color(0xFFFF8C42)]),
    ),
  ),
)
```

### Available gradients:
- `AppTheme.appBarGradient` — Orange gradient (home, settings)
- `AppTheme.greenAppBarGradient` — Green-blue gradient (voice, cache, AI settings)
- `AppTheme.pinkAppBarGradient` — Pink-lavender gradient (tutorial)
- `AppTheme.appBarGradientOf(context)` — Theme-aware gradient

## Toast Feedback — Child-Friendly Parameters

### Toast parameters tuned for children's app
- **Font size**: 18px (larger than standard 16px)
- **Duration**: 4 seconds (longer display time)
- **Gravity**: BOTTOM (standard position)

```dart
// Usage
ToastUtil.success('操作成功');
ToastUtil.error('操作失败');
ToastUtil.warning('请先配置');
ToastUtil.info('提示信息');
```

## Version Information — Dynamic Retrieval

### Use package_info_plus for version display
Do NOT hardcode version numbers. Use `PackageInfo.fromPlatform()`:

```dart
// CORRECT — Dynamic version
FutureBuilder<PackageInfo>(
  future: PackageInfo.fromPlatform(),
  builder: (context, snapshot) {
    return Text('版本 ${snapshot.data?.version ?? '1.0.0'}');
  },
)

// WRONG — Hardcoded version
Text('版本 1.0.0')
```
