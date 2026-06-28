# TOEIC Coach

A Flutter desktop app that drills TOEIC Part 5 vocabulary using AI-generated fill-in-the-blank questions powered by Google Gemini.

---

## Features

### AI-Powered Practice Questions
- Generates TOEIC Part 5 fill-in-the-blank sentences on demand using Google Gemini.
- Four answer choices per question, drawn from your vocabulary list.
- Known (green) words are used to build the sentence; unknown/learning words appear as answer options — so every question tests what you actually need to learn.

### Spaced-Repetition Mastery Tracking
- Each word has a mastery level: **Red** (unfamiliar) → **Yellow** (learning) → **Green** (known).
- Correct answers upgrade a word; wrong answers push it back (wrong yellow words drop straight to red).
- A cooldown system prevents the same word from appearing too frequently.

### Detailed AI Review
- After answering, Gemini explains why each option is correct or incorrect.
- Explanations are in Traditional Chinese, making it accessible for Taiwanese/Chinese learners.
- The app automatically updates word mastery based on your answer.

### Vocabulary Database Panel
- A side panel shows your full word list with current mastery level and status.
- Add new words, browse by level, and track overall progress at a glance.

### Persistent Storage
- Vocabulary is saved to `vocabulary.xlsx` in your app documents folder — portable and editable outside the app.
- Chat history persists across sessions so you can review past questions and answers.

### Auto-Update
- The app checks GitHub for new releases on startup and prompts you to update with one click.

---

## Installation

### Windows (recommended — pre-built installer)

1. Go to the [Releases page](https://github.com/Superfang0726/toeic_coach/releases/latest).
2. Download `toeic_coach-X.Y.Z-setup.exe`.
3. Run the installer. If Windows SmartScreen warns you, click **More info → Run anyway** (the app is not code-signed).
4. Launch **TOEIC Coach** from the Start Menu or desktop shortcut.

### Build from source (Windows / macOS / Linux)

**Prerequisites:**
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK ≥ 3.12)
- A [Google Gemini API key](https://aistudio.google.com/app/apikey) (free tier available)

```bash
git clone https://github.com/Superfang0726/toeic_coach.git
cd toeic_coach
flutter pub get
flutter run -d windows   # or -d macos / -d linux
```

For a release build:

```bash
flutter build windows --release
# Output: build\windows\x64\runner\Release\
```

---

## How to Use

### 1. Set your API key
On first launch, go to **Settings** (gear icon) and paste your Google Gemini API key. You can also choose which Gemini model to use (default: `gemini-2.5-flash-lite`).

### 2. Add vocabulary
In the **Vocabulary** panel on the right, add the words you want to study. New words start at **Red** (unfamiliar).

### 3. Start a session
The **Chat** panel on the left runs the practice loop automatically:
- A fill-in-the-blank sentence is generated.
- Select one of the four answer options.
- Read the AI review to understand why each option is right or wrong.
- Repeat — the app picks the next question based on which words need the most practice.

### 4. Track progress
Word levels update after every answer. Green words graduate out of active rotation; red words get drilled more often until they improve.

### 5. Check for updates
Go to **Settings → 檢查更新** to manually check for a newer version, or let the app check automatically on startup.
