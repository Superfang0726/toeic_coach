# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get                 # install dependencies
flutter run                     # run app (desktop: -d windows / macos / linux)
flutter analyze                 # lint (uses flutter_lints via analysis_options.yaml)
flutter test                    # run all tests (test/ has unit tests; no mocking lib — see Testing)
flutter test test/foo_test.dart # run a single test file
flutter test --name "pattern"   # run tests matching a name
```

The UI is a two-pane `Row` (chat left, vocabulary database right), so it targets desktop/wide layouts rather than mobile.

## Git workflow

**Meaningful changes (features, bug fixes, refactors) must NOT be committed directly to `main`.** Before starting such a change:

1. Create a branch: `git checkout -b <type>/<short-desc>` (`feat/`, `fix/`, `refactor/`, `chore/`).
2. Commit the work on that branch.
3. `git push -u origin <branch>` → `gh pr create` → merge back to `main` **via the GitHub PR**.

Trivial changes (typos, comment tweaks) may go directly to `main`.

A PreToolUse hook (`.claude/hooks/guard-main-branch.ps1`, wired in `.claude/settings.json`) is the safety net: whenever a file-writing tool (Edit/Write/NotebookEdit) runs while on `main`, it prompts the user to confirm (`permissionDecision: "ask"`). Proactively create the branch first so that prompt never appears for real work — the prompt firing means you forgot to branch. The hook script is UTF-8 **with BOM** (required so Windows PowerShell 5.1 reads its Chinese text) and forces UTF-8 stdout; keep both if you edit it.

## Architecture

A Flutter app that drills TOEIC Part 5 vocabulary. It generates fill-in-the-blank questions with Google Gemini, reviews the user's answer, and uses the result to adjust each word's mastery level — persisting everything to a local Excel file.

### Feature-folder + layered structure

Each feature folder (`chat/`, `vocabulary/`, `settings/`) holds its own UI, ViewModel, and Repository. The layering is **UI → ViewModel → Repository → external (Gemini / Excel / storage)**. Cross-cutting types live in `lib/models/`; the shared in-memory state lives in `lib/store/`.

### State flows through a single `Store`

`lib/store/app_store.dart` is a `ChangeNotifier` holding the four pieces of global state: `vocabulary` (List<Vocab>), `apiKey`, `modelName`, and `currentRound` (the global question-round counter). It is the **only** `ChangeNotifierProvider` in `main.dart`. ViewModels receive the `Store` by constructor injection, read state from it, and call its `update*` setters to write back. The Excel file is the source of truth on disk; the `Store` is the working copy in memory.

`main.dart` bootstraps everything synchronously before `runApp`: it constructs the repositories, hydrates the `Store` from Excel + secure storage + shared preferences, then exposes `Store`, `ExcelRepository`, and `VocabularyViewmodel` via `MultiProvider`.

### ViewModel provisioning is inconsistent — know which pattern applies

- `VocabularyViewmodel` is provided globally in `main.dart` and read with `context.read<VocabularyViewmodel>()`.
- `ChatViewModel` is **not** provided. `ChatUi` constructs its own in `initState()` (pulling `Store` and `VocabularyViewmodel` from context), then immediately calls `initGenerativeModels()` and `startQuestion()`. `ChatViewModel` is a `ChangeNotifier`; `ChatUi` listens via `ListenableBuilder`.
- `SettingsViewModel` is constructed wherever needed and writes through to both storage repos and the `Store`.

### The Gemini conversation: three models, one shared history

`GeminiRepository.init()` builds **three** `GenerativeModel` instances that share one `List<Content>` chat history threaded through `ChatViewModel._history`:

1. **generateQuestionModel** — JSON schema output: `{sentence, options[], answer}`. Produces one Part 5 question.
2. **reviewUserAnswerModel** — JSON schema output: `{result, review[], memoryStateUpdateResult[{word, adjustment}]}`. Correctness is **not** judged by this model: `ChatViewModel` computes `isCorrect` locally (`selectedOption.label == _correctLabel`, where `_correctLabel` is set at parse time — via `resolveAnswerLabel` in normal mode, or Gemini's `answer` key in novel mode); the prompt then states the verdict as fact and the model only phrases it. `result` is the human-readable verdict (incl. the correct answer, in Traditional Chinese), `review` holds the explanations, and `memoryStateUpdateResult` lists structured `{word, adjustment}` entries. The user can also right-click any answer option to flag it unfamiliar (`ChatViewModel.toggleOptionUnfamiliar`, independent of which option is selected); `PromptSetter.reviewPrompt` resolves in Dart whether a flagged option overrides the normal correctness-based upgrade — a flagged option is always downgraded, even if it is the correct answer — and states that resolved outcome to the model rather than asking it to judge the conflict.
3. **updateMemoryStateModel** — forced function calling (`updateMemoryState`) that returns structured `{word, mean, adjustment: upgrade|downgrade}` entries.

The full cycle (`ChatViewModel`): `startQuestion()` → generate + parse question → `submitAnswer()` → review answer → call the function-calling model → map each `VocabAdjustment` into `VocabularyViewmodel.handleVocabAdjustment()`. Model responses are JSON parsed after stripping ``` fences; `ChatState` (generatingQuestion → displayingQuestion → generatingReview → displayingReview) drives which `ChatUi` view renders.

### Vocabulary mastery model — the core domain logic

This is the heart of the app and lives in `lib/vocabulary/vocab_domain.dart` (pure static functions, no state):

- Each `Vocab` has a `Level` (red / yellow / green) and a finer `MemoryState` (redLow → redMedium → redHigh → yellowLow → yellowHigh → green).
- `upgrade`/`downgrade` move a word one step along that chain (downgrades are punitive — a wrong yellow word drops straight to redLow). `inferLevel` derives the coarse `Level` back from the `MemoryState`.
- **Question-word scheduling** lives in `QuestionVocabSelector` (in `lib/chat/`). `ChatViewModel._generateQuestion` calls `pickAnswerWord(vocabulary, currentRound)`, which returns the **most overdue** red/yellow word (max `currentRound - nextDueRound`, random tiebreak) — the program, not Gemini, chooses which word is tested. Two modes result:
  - **Normal mode** (a red/yellow word is due): `PromptSetter.questionPrompt(answer, distractorPool, greenPool)` fixes that word as the correct answer and lets Gemini build the sentence, pick 3 distractors, and randomize positions. `ChatViewModel` then derives the correct label by **locating the scheduled word among the returned options** (`resolveAnswerLabel`), not by trusting Gemini's `answer`; if Gemini omitted the word it throws `ScheduledAnswerMissingException`, which `RetryHandler` treats as retryable so the question regenerates. Because the scheduler re-picks that same most-overdue word every attempt, an un-placeable word would wedge generation — so when the retries are exhausted, `startQuestion` falls back to one novel-mode generation (`_generateQuestion(forceNovel: true)`) instead of failing.
  - **Novel mode** (`pickAnswerWord` returns `null` — nothing due, or an empty/green-only database): `PromptSetter.novelQuestionPrompt()` has Gemini invent a fresh question; the correct label falls back to Gemini's `answer`. Wrong/unfamiliar novel words enter the database as red via `handleVocabAdjustment`, so the vocabulary grows and resting words eventually come due again.
  Each answered question increments the persisted `currentRound`; a used word is rescheduled to `currentRound + inferInterval(memoryState)`.

`VocabularyViewmodel.handleVocabAdjustment` is the bridge from Gemini back to the database: if the word exists it applies the upgrade/downgrade and re-infers level; if it's a brand-new word (e.g. one the user flagged as unfamiliar) it adds it as a fresh red word.

### Auto-update feature

`lib/update/` checks GitHub releases for a newer version on startup. `UpdateRepository` fetches the latest release info; `UpdateViewModel` drives the logic; `UpdateDialog` is shown from `main.dart` if an update is available. `release_info.dart` in `lib/models/` is the data model for a release.

### Persistence

- **Vocabulary** → `ExcelRepository` reads/writes `vocabulary.xlsx` in the app documents directory. Every mutating `VocabularyViewmodel` method writes the whole list back to Excel immediately after updating the `Store`. Columns: `id, word, mean, level, state, nextDueRound` (legacy files headed `cooldown` read as-is — they predate round persistence, so the countdown value already equals the absolute due round — and upgrade on first write).
- **API key** → `SecureStorageRepository` (flutter_secure_storage).
- **Model name** → `SharedPreferencesRepository` (defaults to `gemini-3.1-flash-lite`).
- **Current round** → `SharedPreferencesRepository` (key `round`, defaults to 0).

## Conventions & gotchas

- **"Installed apps" version not changing after an auto-update is almost always a stale Windows Settings cache, not a bug.** The Inno Setup installer *does* rewrite the Add/Remove-Programs `DisplayVersion` on upgrade; but the Windows Settings installed-apps list is cached and won't refresh live — reopen it or use `appwiz.cpl` to see the new version. Related context on why versions can look inconsistent: the app has three independent version sources synced **by hand**, not derived from each other — the running app reads its version from `pubspec.yaml` via `package_info_plus` (what the updater compares), while the installer / registry `DisplayVersion` comes from the `/DMyAppVersion=X.Y.Z` flag hand-typed into ISCC at build time (`windows/installer/toeic_coach.iss`, `#ifndef` fallback `0.0.0`), **not** from `pubspec.yaml`. The updater installs **per-machine** (Program Files + HKLM), so an upgrade needs UAC elevation and isn't truly silent.
- `RetryHandler.retryHandler` (`lib/chat/retry_handler.dart`) wraps each Gemini API call in `ChatViewModel`. If you add a new model call, route it through `RetryHandler` rather than calling the SDK directly.
- The codebase uses `print` for debugging and has scattered `//TODO:` markers (e.g. "alert user", broken-row cleanup) — these mark genuinely unfinished work.
- `PromptSetter.reviewPrompt` deliberately does **not** mention any tool — the review model has no tools and only fills the `memoryStateUpdateResult` JSON field; the actual `updateMemoryState` function call happens in the separate third model, which reads that field from history. Keep the field name consistent across both sides if editing either.
- `Vocab` and `Option` are mutable value classes; `VocabAdjustment` is immutable. Neither `Vocab` nor `Option` has JSON serialization — Excel I/O is hand-rolled in `ExcelRepository`.

## Testing

Tests live in `test/` and run with `flutter test`. There is **no mocking library** (no mockito/mocktail) — instead, tests use hand-written **Fakes that subclass the real repository** and override only the I/O method, e.g. `FakeExcelRepository extends ExcelRepository` overriding `writeExcel` to capture the written list in memory. Domain logic (`vocab_domain.dart`) and pure helpers (`isVersionNewer`) are covered directly as pure-function tests. Follow the Fake pattern for new ViewModel tests rather than adding a mocking dependency.

## Active task specs

- **UI beautification** → see [docs/ui_enhancement_spec.md](docs/ui_enhancement_spec.md). A UI-only pass (light mode, blue palette, card-based) driven by `lib/theme/app_theme.dart`; must not touch ViewModel/Domain/Repository logic.