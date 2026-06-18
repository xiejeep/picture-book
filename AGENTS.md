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
- `test/` is empty and there is no CI workflow; `fvm flutter analyze` is the main verification step today.
- Run the `build_runner` command after changing Hive models in `lib/data/models/`; generated `*.g.dart` files are committed beside models.

## Architecture

- Entrypoint is `lib/main.dart`: initializes `StorageService.instance` and `ImageService.instance` before `runApp(const ProviderScope(child: BookApp()))`.
- `lib/app.dart` owns `MaterialApp.router`, theme mode, TTS/file-intent init, and NFC lifecycle/subscription handling.
- Routes are in `lib/core/router/app_router.dart`; README route/version tables are stale, so trust this file and `pubspec.yaml`.
- State uses Riverpod 2 `Notifier<State>` providers with hand-written immutable state/copyWith classes in `lib/presentation/providers/`.
- Services are singletons wrapped by providers in `lib/presentation/providers/service_providers.dart`, then repository providers in `repository_providers.dart`; prefer provider access in new Riverpod-aware code, but existing pages still mix in direct `.instance` calls.
- Storage is Hive: boxes are `books`, `ai_settings`, plus internal `app_settings`; `StorageService` also stores the Zhipu API key in `flutter_secure_storage` under `zhipu_api_key`.

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
