# AGENTS.md - 点读鸭 (DianDuYa)

Flutter children's English picture-book reading app for the Chinese market; keep UI copy Chinese unless a task says otherwise.

## Commands

```bash
fvm flutter pub get
fvm flutter run
fvm flutter analyze
dart format lib/
fvm flutter test
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

- `.fvmrc` pins `stable`; use `fvm flutter`, not bare `flutter` from README examples.
- `test/` contains unit tests for NFC/action parsing and immutable model/state copy behavior; run `fvm flutter test` when touching those paths. There is still no CI workflow, so `fvm flutter analyze` remains the main verification step.
- Run the `build_runner` command after changing Hive models in `lib/data/models/`; generated `*.g.dart` files are committed beside models.

## Architecture

- Entrypoint is `lib/main.dart`: initializes `StorageService.instance` and `ImageService.instance` before `runApp(const ProviderScope(child: BookApp()))`.
- `lib/app.dart` owns `MaterialApp.router`, theme mode, TTS/file-intent init, and NFC lifecycle/subscription handling.
- Routes are in `lib/core/router/app_router.dart`; README route/version tables are stale, so trust this file and `pubspec.yaml`.
- State uses Riverpod 2 providers with hand-written immutable state/copyWith classes in `lib/presentation/providers/`.
- Services are singletons wrapped by providers in `lib/presentation/providers/service_providers.dart`, then repository providers in `repository_providers.dart`; prefer provider access in new Riverpod-aware code, but existing pages still mix in direct `.instance` calls.
- Storage is Hive: boxes are `books`, `ai_settings`, plus internal `app_settings`; `StorageService` also stores the Zhipu API key in `flutter_secure_storage` under `zhipu_api_key`.
- `lib/application/` holds lightweight use cases that orchestrate business workflows too large for pages, starting with `application/reading/text_block_ai_use_case.dart`.
- `BookReaderPage` is the active reader page. Do not recreate a parallel detail/reader page; deleted `BookDetailPage` was an obsolete duplicate.
- `TtsService` exposes `TtsPlaybackState` through a broadcast stream and `ttsStateProvider`; UI should observe state instead of assigning global mutable TTS callbacks.
- NFC routing/business consumption goes through `NfcActionHandler` and `pendingNfcActionProvider`; `NfcService` should stay focused on platform scan/write/parse concerns.

## Architecture Guardrails

- Keep pages thin: pages may own layout, gestures, dialogs, focus/animation controllers, and view-only local UI details. Do not add new persistence, NFC routing, TTS orchestration, or AI workflow logic directly to pages.
- Put cross-step business workflows in `lib/application/<feature>/...` use cases. Use cases should return structured results rather than showing toasts, opening dialogs, or mutating widgets directly.
- Put app state in immutable state classes under `lib/presentation/providers/`. Use `copyWith()` and explicit clear flags for nullable fields; do not add clusters of mutable page fields for durable reader state.
- Route all book writes through `BookRepository`/`BookService` or an existing notifier/repository provider. Do not call `_book.save()` from pages and do not assign into `_book.pages[...]` from UI code.
- Keep services narrow and platform/external-system oriented: TTS, NFC, OCR/vision, AI APIs, storage, filesystem. Services may expose streams/results, but should not know page widgets, routes, or toasts.
- Do not add global mutable callbacks or global consumed flags for app behavior. Prefer streams/providers plus explicit handlers with lifecycle-owned subscriptions, e.g. `ref.listenManual` in `ConsumerState.initState` and close the returned subscription in `dispose`.
- Default logs must not print children's reading text, OCR output, AI prompts/responses, translation content, or imported book text. Use `AppLog.content(...)` for gated content logs and keep `AppLog.verboseContentLog` false by default.
- New public model/state behavior needs small unit tests when it is pure Dart logic. At minimum protect parsing, copyWith clear-flag behavior, and route/action payload transformations.
- Avoid “temporary” duplicate flows. If a new feature looks similar to reader, AI, TTS, NFC, import/export, or storage logic, extract or reuse the existing module instead of copying it.
- Make small vertical changes that preserve behavior. If a change requires a new architectural exception, document the reason in code or `AGENTS.md` before expanding the pattern.

## Conventions

- Do not reintroduce deprecated `.withOpacity()`; use `.withValues(alpha:)`.
- Keep AI prompts in `lib/core/constants/app_prompts.dart`, not inline in services.
- `TextBlockData`, `TextBlockModel`, and `PageModel` fields are effectively immutable; update with `copyWith()` instead of assignment.
- Never renumber existing Hive `typeId` or `@HiveField` values; `AiSettingsModel` intentionally has gaps in field numbers.
- Preserve semantics/accessibility wrappers on interactive controls; `lib/presentation/widgets/semantics_icon_button.dart` exists for icon buttons.
- App name is `点读鸭`; NFC/deep-link payloads use `dianduya://play/<bookId>/<pageId>/<blockId>`.

## Platform And Package Gotchas

- `photo_view` is vendored via `pubspec.yaml` path `lib/vendor/photo_view` with custom `onDoubleTap` support; do not replace it with the pub.dev package casually.
- Android native package/application id is still `com.example.picture_book_app`; release builds currently use the debug signing config.
- Android handles NFC intents and `.ddb` file imports in `android/app/src/main/.../MainActivity.kt` plus manifest filters.
- iOS Podfile sets `platform :ios, '16.0'`, `use_frameworks! :linkage => :static`, and manually links `CoreNFC` for `nfc_manager`; keep that hook if editing pods.
- Orientation is not portrait-only: `main.dart`, Android manifest config changes, and iOS plist all allow portrait and landscape.
- `ImageService.getImageFile()` is synchronous and is used from build paths; do not make it async without changing callers.
