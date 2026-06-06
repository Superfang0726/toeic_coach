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

**Panel Frame** *(user request, 2026-06-06)*

- Wrap the entire right panel in a framed container so it visually mirrors the
  left chat pane: `kSurface` background, `borderRadius: 16`, 1px `kBorder`
  outline. The panel should read as its own bordered card, not a borderless
  region bleeding into the background.

**Input Area**

- Wrap in a `Card` (`elevation: 2`, `borderRadius: 16`)
- `TextField`: use `OutlineInputBorder` with `borderRadius: 12` and `borderColor: kBorder`
- The **word** and **mean** fields must each have their **own** outlined box
  (separate `OutlineInputBorder`), so the user can clearly tell the two inputs
  apart rather than seeing them as one undivided strip *(user request,
  2026-06-06)*. Give each a `labelText` / `hintText` ("Word" / "Meaning") and
  spacing between them.
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

**Scrollable layout — overflow fix** *(user request, 2026-06-06)*

The `displayingQuestion` and `displayingReview` columns currently use a fixed
`Column` + `Spacer()` to pin the action button to the bottom. When the window
is shrunk (or the review text is long), the fixed-height content exceeds the
available height and Flutter throws a `RenderFlex overflow` (yellow/black
"BOTTOM OVERFLOWED BY N PIXELS" bar).

Fix: restructure both views so the **content area scrolls** and the action
button stays pinned at the bottom — `Expanded(child: SingleChildScrollView(...))`
for the content, the button below it, and **remove the `Spacer()`** (a `Spacer`
cannot live inside a scroll view). This removes the overflow at any window size.
Apply as part of Step 5 (question) and Step 6 (review).

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
- Correctness comes from a structured `isCorrect` boolean on the review schema
  / `ChatViewModel`, not from parsing the `result` string *(approved scope
  exception, 2026-06-07)*. This is the one place the "no logic changes" rule was
  relaxed: a boolean was added to `reviewUserAnswerModel`'s schema and exposed
  via `ChatViewModel.isCorrect`. The `result` text is kept (it carries the
  correct answer); the `!result.contains('錯誤')` heuristic remains only as a
  fallback when the flag is absent.

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
