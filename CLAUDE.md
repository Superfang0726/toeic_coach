# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get                 # install dependencies
flutter run                     # run app (desktop: -d windows / macos / linux)
flutter analyze                 # lint (uses flutter_lints via analysis_options.yaml)
flutter test                    # run all tests (no tests exist yet)
flutter test test/foo_test.dart # run a single test file
flutter test --name "pattern"   # run tests matching a name
```

The UI is a two-pane `Row` (chat left, vocabulary database right), so it targets desktop/wide layouts rather than mobile.

## Architecture

A Flutter app that drills TOEIC Part 5 vocabulary. It generates fill-in-the-blank questions with Google Gemini, reviews the user's answer, and uses the result to adjust each word's mastery level — persisting everything to a local Excel file.

### Feature-folder + layered structure

Each feature folder (`chat/`, `vocabulary/`, `settings/`) holds its own UI, ViewModel, and Repository. The layering is **UI → ViewModel → Repository → external (Gemini / Excel / storage)**. Cross-cutting types live in `lib/models/`; the shared in-memory state lives in `lib/store/`.

### State flows through a single `Store`

`lib/store/app_store.dart` is a `ChangeNotifier` holding the three pieces of global state: `vocabulary` (List<Vocab>), `apiKey`, and `modelName`. It is the **only** `ChangeNotifierProvider` in `main.dart`. ViewModels receive the `Store` by constructor injection, read state from it, and call its `update*` setters to write back. The Excel file is the source of truth on disk; the `Store` is the working copy in memory.

`main.dart` bootstraps everything synchronously before `runApp`: it constructs the repositories, hydrates the `Store` from Excel + secure storage + shared preferences, then exposes `Store`, `ExcelRepository`, and `VocabularyViewmodel` via `MultiProvider`.

### ViewModel provisioning is inconsistent — know which pattern applies

- `VocabularyViewmodel` is provided globally in `main.dart` and read with `context.read<VocabularyViewmodel>()`.
- `ChatViewModel` is **not** provided. `ChatUi` constructs its own in `initState()` (pulling `Store` and `VocabularyViewmodel` from context), then immediately calls `initGenerativeModels()` and `startQuestion()`. `ChatViewModel` is a `ChangeNotifier`; `ChatUi` listens via `ListenableBuilder`.
- `SettingsViewModel` is constructed wherever needed and writes through to both storage repos and the `Store`.

### The Gemini conversation: three models, one shared history

`GeminiRepository.init()` builds **three** `GenerativeModel` instances that share one `List<Content>` chat history threaded through `ChatViewModel._history`:

1. **generateQuestionModel** — JSON schema output: `{sentence, options[], answer}`. Produces one Part 5 question.
2. **reviewUserAnswerModel** — JSON schema output: `{result, review[], memoryStateUpdateResult[{word, adjustment}]}`. Correctness is **not** judged by this model: `ChatViewModel` parses the `answer` key from the question response and computes `isCorrect` locally (`selectedOption.label == answer`); the prompt then states the verdict as fact and the model only phrases it. `result` is the human-readable verdict (incl. the correct answer, in Traditional Chinese), `review` holds the explanations, and `memoryStateUpdateResult` lists structured `{word, adjustment}` entries.
3. **updateMemoryStateModel** — forced function calling (`updateMemoryState`) that returns structured `{word, mean, adjustment: upgrade|downgrade}` entries.

The full cycle (`ChatViewModel`): `startQuestion()` → generate + parse question → `submitAnswer()` → review answer → call the function-calling model → map each `VocabAdjustment` into `VocabularyViewmodel.handleVocabAdjustment()`. Model responses are JSON parsed after stripping ``` fences; `ChatState` (generatingQuestion → displayingQuestion → generatingReview → displayingReview) drives which `ChatUi` view renders.

### Vocabulary mastery model — the core domain logic

This is the heart of the app and lives in `lib/vocabulary/vocab_domain.dart` (pure static functions, no state):

- Each `Vocab` has a `Level` (red / yellow / green) and a finer `MemoryState` (redLow → redMedium → redHigh → yellowLow → yellowHigh → green).
- `upgrade`/`downgrade` move a word one step along that chain (downgrades are punitive — a wrong yellow word drops straight to redLow). `inferLevel` derives the coarse `Level` back from the `MemoryState`.
- `PromptSetter.questionPrompt` (in `lib/chat/`) tells Gemini to use **red/yellow** words as the answer choices and **green** (known) words to build the sentence. `QuestionVocabFilter.filter` (also in `lib/chat/`) selects only words with `cooldown == 0` before passing them into the prompt.

`VocabularyViewmodel.handleVocabAdjustment` is the bridge from Gemini back to the database: if the word exists it applies the upgrade/downgrade and re-infers level; if it's a brand-new word (e.g. one the user flagged as unfamiliar) it adds it as a fresh red word.

### Auto-update feature

`lib/update/` checks GitHub releases for a newer version on startup. `UpdateRepository` fetches the latest release info; `UpdateViewModel` drives the logic; `UpdateDialog` is shown from `main.dart` if an update is available. `release_info.dart` in `lib/models/` is the data model for a release.

### Persistence

- **Vocabulary** → `ExcelRepository` reads/writes `vocabulary.xlsx` in the app documents directory. Every mutating `VocabularyViewmodel` method writes the whole list back to Excel immediately after updating the `Store`. Columns: `id, word, mean, level, state, cooldown`.
- **API key** → `SecureStorageRepository` (flutter_secure_storage).
- **Model name** → `SharedPreferencesRepository` (defaults to `gemini-3.1-flash-lite`).

## Conventions & gotchas

- `RetryHandler.retryHandler` (`lib/chat/retry_handler.dart`) wraps each Gemini API call in `ChatViewModel`. If you add a new model call, route it through `RetryHandler` rather than calling the SDK directly.
- The codebase uses `print` for debugging and has scattered `//TODO:` markers (e.g. "alert user", broken-row cleanup) — these mark genuinely unfinished work.
- `PromptSetter.reviewPrompt` deliberately does **not** mention any tool — the review model has no tools and only fills the `memoryStateUpdateResult` JSON field; the actual `updateMemoryState` function call happens in the separate third model, which reads that field from history. Keep the field name consistent across both sides if editing either.
- `Vocab` and `Option` are mutable value classes; `VocabAdjustment` is immutable. Neither `Vocab` nor `Option` has JSON serialization — Excel I/O is hand-rolled in `ExcelRepository`.

## Active task specs

- **UI beautification** → see [docs/ui_enhancement_spec.md](docs/ui_enhancement_spec.md). A UI-only pass (light mode, blue palette, card-based) driven by `lib/theme/app_theme.dart`; must not touch ViewModel/Domain/Repository logic.