# AGENTS.md — 点读鸭 (DianDuYa)

Flutter children's English picture-book reading app. Chinese market, Chinese UI.

## Commands

```bash
fvm flutter pub get          # install deps (always use via fvm)
fvm flutter run              # run app
fvm flutter analyze          # lint + typecheck (run before committing)
dart format lib/             # format
fvm flutter pub run build_runner build --delete-conflicting-outputs  # Hive model codegen
```

No tests exist (`test/` is empty). No CI. No unit tests.

## Architecture

- **State**: Riverpod 2.x — `Notifier<State>` pattern with custom `copyWith` state classes
- **Routing**: GoRouter (all routes in `lib/core/router/app_router.dart:77`)
- **Storage**: Hive with `build_runner` codegen (`*.g.dart` alongside models)
- **Services**: All singletons (`ClassName.instance`) wrapped in Riverpod Providers (`lib/presentation/providers/service_providers.dart`), then Repository layer (`lib/presentation/providers/repository_providers.dart`). Mixed usage — some code reads singletons directly, some via providers. Prefer provider access.
- **Entrypoint**: `lib/main.dart` — initializes `StorageService.instance` and `ImageService.instance` synchronously before `runApp`

## Key Convensions

- `.withOpacity()` is fully migrated to `.withValues(alpha:)` — never reintroduce deprecated API
- `TextBlockData` fields are `final` — use `copyWith` to update, never direct assignment
- AI prompts live in `lib/core/constants/app_prompts.dart` (not inline in services)
- Semantics wrappers added on interactive elements for accessibility
- App name: `点读鸭`, deep link scheme: `dianduya://`
- Portrait orientation preferred (set in `main.dart`)
- Hive box names: `books`, `ai_settings`
- `version: 1.0.6+11` (from pubspec.yaml, also served via `package_info_plus`)

## Directory Layout

```
lib/
├── main.dart                          # Entrypoint + init
├── app.dart                           # MaterialApp.router + NFC lifecycle
├── core/                              # constants, router, theme, utils
├── data/
│   ├── models/                        # Hive-annotated models (+ .g.dart generated)
│   ├── repositories/                  # Thin wrappers over services
│   └── services/                      # 16 singleton services (AiService, TtsService, etc.)
└── presentation/
    ├── providers/                     # Riverpod providers (books, settings, tts, services, repos)
    ├── pages/                         # Full-screen pages (12)
    ├── features/text_detection/       # OCR + text block editing module
    └── widgets/                       # Shared widgets (5)
```

## Refactoring History

Key completed work (see `REFACTOR_PROGRESS.md` for full detail):
- Sync I/O → async throughout
- `withOpacity()` → `withValues(alpha:)` (105 replacements)
- `AiService` God class split into `VisionService` + `TextCleaningService`
- `TextDetectionView` (1014→570 lines) — dialogs extracted to part-file mixin
- `BookDetailPage` — converted from singletons to Riverpod `ConsumerStatefulWidget`
- Prompts extracted from services to `AppPrompts` constants

## Gotchas

- `.fvmrc` pins `"stable"` — always use `fvm flutter` not bare `flutter`
- VS Code SDK path: `.fvm/versions/stable`
- `book_detail_page.dart` still has inline `TextBlockPainter` duplicate (2 copies exist)
- `image_service.getImageFile()` remains sync (callers use in `build()`)
- `BookManagePage` is not Riverpod (by design, per refactor notes)
