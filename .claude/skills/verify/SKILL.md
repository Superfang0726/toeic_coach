---
name: verify
description: Build, launch, and drive TOEIC Coach on Windows to verify a change end-to-end — including screenshots and clicks that don't disturb the user's active desktop session.
---

# Verifying TOEIC Coach on Windows

## Build & launch

```powershell
flutter run -d windows --no-resident   # builds (~25s warm), launches, tool exits; app keeps running
# faster relaunch once built:
Start-Process "build\windows\x64\runner\Debug\toeic_coach.exe"
Get-Process toeic_coach                # confirm it's up; MainWindowHandle is the FLUTTER_RUNNER_WIN32_WINDOW
```

The chat pane does NOT auto-call Gemini on launch — it waits for the 開始出題 button, so launching is free. Generating/answering a question spends real Gemini quota on the user's API key.

## State locations (check before/after driving)

- Vocabulary: `[Environment]::GetFolderPath('MyDocuments')\vocabulary.xlsx` — **back it up before any flow that answers a question** (the app rewrites the whole file).
- SharedPreferences: `%APPDATA%\com.example\toeic_coach\shared_preferences.json` (plain JSON: `model`, `round`).
- API key: flutter_secure_storage in the same dir (opaque, don't touch).

## Screenshots without stealing focus

The user may be actively using the machine. **Never** `SetForegroundWindow` + `CopyFromScreen` — it fails silently under focus-stealing protection and captures whatever window covers that region (possibly the user's private content). Use `PrintWindow` with `PW_RENDERFULLCONTENT` (flag 3) on the main window handle; it captures the app's own surface even when covered. If `IsIconic` (user minimized it), restore with `ShowWindow(h, 4)` (SW_SHOWNOACTIVATE) — and take the minimize as a hint the user is present; keep interactions minimal.

## Clicking without stealing focus

`PostMessage` to the **FLUTTERVIEW child window** (enumerate children of the main handle) works; Flutter processes WM_MOUSEMOVE/WM_LBUTTONDOWN/WM_LBUTTONUP posted at client coordinates:

```powershell
# WM_MOUSEMOVE 0x0200, WM_LBUTTONDOWN 0x0201 (wParam 1), WM_LBUTTONUP 0x0202; lParam = (y<<16)|x
```

PrintWindow output coordinates ≈ FLUTTERVIEW client coordinates (1280x720 default window). Gotcha: a click posted while a button is still disabled is swallowed — re-capture to confirm state before clicking submit-type buttons.

## Flows worth driving

1. Launch → vocab list renders (Excel read + Store hydration).
2. 開始出題 (~centre-left, e.g. 315,458) → question card (due-filter + Gemini + JSON parse).
3. Click an option → 送出 enables → click 送出 (~315,623) → wait ~15s → review card (review + function-calling + round increment + rescheduling).
4. Check `shared_preferences.json` round and diff `vocabulary.xlsx` against the backup (xlsx = zip; parse `xl/sharedStrings.xml` + `xl/worksheets/sheet1.xml`).
5. Close via `PostMessage(h, 0x0010, 0, 0)` (WM_CLOSE) — always close what you launched.
