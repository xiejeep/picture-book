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
