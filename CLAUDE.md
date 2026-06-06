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
2. **reviewUserAnswerModel** — JSON schema output: `{result, review[], memoryStateUpdateResult[]}`. Evaluates the answer (in Traditional Chinese) and lists which words should move up/down.
3. **updateMemoryStateModel** — forced function calling (`updateMemoryState`) that returns structured `{word, mean, adjustment: upgrade|downgrade}` entries.

The full cycle (`ChatViewModel`): `startQuestion()` → generate + parse question → `submitAnswer()` → review answer → call the function-calling model → map each `VocabAdjustment` into `VocabularyViewmodel.handleVocabAdjustment()`. Model responses are JSON parsed after stripping ``` fences; `ChatState` (generatingQuestion → displayingQuestion → generatingReview → displayingReview) drives which `ChatUi` view renders.

### Vocabulary mastery model — the core domain logic

This is the heart of the app and lives in `lib/vocabulary/vocab_domain.dart` (pure static functions, no state):

- Each `Vocab` has a `Level` (red / yellow / green) and a finer `MemoryState` (redLow → redMedium → redHigh → yellowLow → yellowHigh → green).
- `upgrade`/`downgrade` move a word one step along that chain (downgrades are punitive — a wrong yellow word drops straight to redLow). `inferLevel` derives the coarse `Level` back from the `MemoryState`.
- `QuestionVocabFilter.filter` selects only words with `cooldown == 0` to feed into a question.
- `PromptSetter.questionPrompt` tells Gemini to use **red/yellow** words as the answer choices and **green** (known) words to build the sentence.

`VocabularyViewmodel.handleVocabAdjustment` is the bridge from Gemini back to the database: if the word exists it applies the upgrade/downgrade and re-infers level; if it's a brand-new word (e.g. one the user flagged as unfamiliar) it adds it as a fresh red word.

### Persistence

- **Vocabulary** → `ExcelRepository` reads/writes `vocabulary.xlsx` in the app documents directory. Every mutating `VocabularyViewmodel` method writes the whole list back to Excel immediately after updating the `Store`. Columns: `id, word, mean, level, state, cooldown`.
- **API key** → `SecureStorageRepository` (flutter_secure_storage).
- **Model name** → `SharedPreferencesRepository` (defaults to `gemma-4-31b-it`).

## Conventions & gotchas

- The codebase uses `print` for debugging and has scattered `//TODO:` markers (e.g. "alert user", broken-row cleanup) — these mark genuinely unfinished work.
- Prompt text in `PromptSetter` references a tool named `updateVocab`, but the actual `FunctionDeclaration` is named `updateMemoryState`. Keep this in mind if editing either side.
- `Vocab` and `Option` are mutable value classes; `VocabAdjustment` is immutable. Neither `Vocab` nor `Option` has JSON serialization — Excel I/O is hand-rolled in `ExcelRepository`.

# TOEIC Coach — UI Enhancement Spec

## Background

This is a Flutter desktop application (Windows/macOS).
All core features are complete. This task focuses exclusively on **UI beautification** — no business logic should be modified.

---

## Design Direction

- **Mode**: Light Mode
- **Style**: Vibrant with visual hierarchy, inspired by educational apps (Duolingo / Quizlet aesthetic)
- **Primary Color**: Blue palette (fresh, trustworthy feel)
- **Key Characteristics**: Card-based layout, layered shadows, rounded corners, subtle gradients

---

## Color Scheme

Create `lib/theme/app_theme.dart` and define the following constants. Use them consistently across the entire project:

```dart
// Backgrounds
const Color kBackground     = Color(0xFFF0F4FF); // Blue-tinted off-white
const Color kSurface        = Color(0xFFFFFFFF); // Card background

// Primary
const Color kPrimary        = Color(0xFF3B82F6); // Blue
const Color kPrimaryLight   = Color(0xFFEFF6FF); // Tinted blue (hover backgrounds, etc.)
const Color kPrimaryDark    = Color(0xFF1D4ED8); // Button pressed state

// Accent Colors
const Color kSuccess        = Color(0xFF22C55E); // Green (correct answer)
const Color kError          = Color(0xFFEF4444); // Red (wrong answer)
const Color kWarning        = Color(0xFFF59E0B); // Yellow (unfamiliar word marker)

// Text
const Color kTextPrimary    = Color(0xFF1E293B);
const Color kTextSecondary  = Color(0xFF64748B);
const Color kTextHint       = Color(0xFFCBD5E1);

// Border / Divider
const Color kBorder         = Color(0xFFE2E8F0);
```

---

## Typography

Add the `google_fonts` package to `pubspec.yaml` if not already present:

```dart
// Headings (AppBar, card titles)
GoogleFonts.poppins(fontWeight: FontWeight.w700)

// Body text (questions, options)
GoogleFonts.notoSans() // CJK character support
```

---

## Global ThemeData

Define `AppTheme.light()` in `app_theme.dart`:

```dart
ThemeData light() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: kPrimary,
    surface: kSurface,
    background: kBackground,
  ),
  scaffoldBackgroundColor: kBackground,
  cardTheme: CardTheme(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    color: kSurface,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: kSurface,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: kTextPrimary,
    ),
  ),
);
```

---

## Per-Screen Changes

### AppBar

- Background: `kSurface` (white), with a 1px `kBorder` bottom divider
- Title: "TOEIC Coach", Poppins Bold, `kTextPrimary`
- Settings button: `Icons.settings_outlined`, color `kTextSecondary`

---

### Overall Layout (main.dart)

- Scaffold background: `kBackground`
- Left/right divider: replace with `VerticalDivider(width: 1, color: kBorder)`

---

### Right Panel: Vocabulary Database (DatabaseUi)

**Input Area**

- Wrap in a `Card` (`elevation: 2`, `borderRadius: 16`)
- `TextField`: use `OutlineInputBorder` with `borderRadius: 12` and `borderColor: kBorder`
- On focus: border changes to `kPrimary`
- Level selector: replace with three `ChoiceChip`s (🔴 Red / 🟡 Yellow / 🟢 Green); selected chip background uses a tinted version of the corresponding color
- Add button: `FilledButton`, background `kPrimary`, `borderRadius: 12`, white text

**Vocabulary List**

- Each `VocabListItem` becomes a card: white background, `borderRadius: 12`, soft shadow:
  ```dart
  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))]
  ```
- Left edge: 4px color strip based on `level` — Red → `kError`, Yellow → `kWarning`, Green → `kSuccess`
- Right side: small dot or Badge showing `memoryState` (6 states, gradient colors from low to high)
- On hover: background changes to `kPrimaryLight`, delete icon color becomes `kError`
- List spacing: add `gap: 8` between items

**Collapse / Expand Button**

- Replace with a `FloatingActionButton.small`, using `Icons.chevron_right` / `Icons.chevron_left`

---

### Left Panel: Chat Area (ChatUi)

**Shared Card Style**

Wrap all state content areas in:

```dart
Container(
  decoration: BoxDecoration(
    color: kSurface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: Offset(0, 4),
    )],
  ),
)
```

---

**`generatingQuestion` / `generatingReview` States**

- Replace plain text with a centered layout:
  - `CircularProgressIndicator(color: kPrimary)`
  - Text below: "Generating question…" / "Reviewing…", `kTextSecondary`, Noto Sans

---

**`displayingQuestion` State**

*Question sentence area (Wrap + tappable word tokens)*

- Card background: soft blue gradient — `LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFFFFFFF)])`
- Each word token: rounded chip style, `borderRadius: 6`
- Tapped (unfamiliar): background `Color(0xFFFFFBEB)` (warm yellow tint), underline `kWarning`
- Untapped: transparent background, underline `kTextHint` on hover

*Options area*

- Each option is a standalone card, `borderRadius: 12`, `border: 1px kBorder`
- Left side: circular Label badge (A/B/C/D), background `kPrimaryLight`, text `kPrimary`
- Selected state: card border → `kPrimary` (2px), background → `kPrimaryLight`, show checkmark icon
- Use `AnimatedContainer` for selection transition (duration: 200ms)

*Submit button*

- Use `FilledButton.icon`, full width, height 52, `borderRadius: 14`
- No option selected: background `kBorder`, text `kTextHint` (disabled appearance)
- Option selected: background `kPrimary`, white text, icon `Icons.send_rounded`
- Add subtle scale micro-animation on press

---

**`displayingReview` State**

*Answer result*

- Correct: top color strip `kSuccess`, title icon `Icons.check_circle` (green)
- Incorrect: top color strip `kError`, title icon `Icons.cancel` (red)
- Result text: 20sp, `fontWeight: w600`

*Review & memory state adjustment*

- Each `reviewItem`: preceded by a `•` bullet, color `kTextSecondary`
- Each `memoryStateAdjustment`: preceded by an arrow icon — ⬆ green for upgrade, ⬇ red for downgrade

*Next question button*

- Same style as the submit button, icon changed to `Icons.arrow_forward_rounded`

---

### SettingsUi (AlertDialog)

- Dialog: `borderRadius: 20`, `surfaceTintColor: transparent`
- API Key field: add suffix `IconButton` with eye icon to toggle visibility
- Model dropdown: use `DropdownButtonFormField`, styled consistently with the text field
- Save button: `FilledButton`, `kPrimary`, full width

---

## Execution Order

Execute one step at a time. Verify the app visually after each step before proceeding.

1. **Create `app_theme.dart`** — define all Color constants and ThemeData
2. **Apply ThemeData in `main.dart`** — verify global background and AppBar changes
3. **Restyle `VocabListItem`** — left color strip, card shadow, hover effect
4. **Restyle `DatabaseUi` input area** — TextField, ChoiceChips, add button
5. **Restyle `ChatUi` — displayingQuestion** — question area, options, submit button
6. **Restyle `ChatUi` — displayingReview** — result strip, review list, next button
7. **Restyle loading states** — replace plain text with CircularProgressIndicator
8. **Restyle `SettingsUi`** — dialog border radius, eye icon, unified field styles

---

## Constraints

- **Do not modify any ViewModel, Domain, or Repository logic**
- All colors must be referenced from `app_theme.dart` — no hardcoded color values inside widgets
- Add `google_fonts` to `pubspec.yaml` if not already present
- Replace all existing hardcoded colors (e.g. `Color.fromARGB(20, 16, 24, 40)`) with the corresponding constants from `app_theme.dart`