# Auto-Update Feature — Line-by-Line Code Walkthrough

A learning-oriented companion to the auto-update + publishing work. It explains
**what each block does and why**, file by file. Read it top to bottom; later
files build on earlier ones.

> Layering recap (from `CLAUDE.md`): **UI → ViewModel → Repository → external**.
> The updater adds one new feature folder, `lib/update/`, plus one model in
> `lib/models/`. Nothing in the existing chat/vocabulary/settings logic changes.

---

## 1. `pubspec.yaml` — the two new dependencies

```yaml
http: ^1.2.0
package_info_plus: ^8.0.0
```

- **`http`** — a simple client for HTTPS requests. Used to (a) ask GitHub's API
  for the latest release and (b) stream-download the installer file. Dart's
  built-in `dart:io HttpClient` could do it too, but `http` is the standard,
  much friendlier API.
- **`package_info_plus`** — reads the app's *own* version (the `version:` in this
  file, baked into the build) back out at runtime. That's the "current version"
  we compare against GitHub's "latest version". Keeps a single source of truth so
  the displayed version can't drift from reality.

`^1.2.0` means "1.2.0 or any newer 1.x" (caret = compatible-with). `flutter pub
get` resolved these to concrete versions and wrote them to `pubspec.lock`.

---

## 2. `lib/models/release_info.dart` — the data carrier

```dart
class ReleaseInfo {
  final String version;
  final String notes;
  final String installerUrl;

  const ReleaseInfo({
    required this.version,
    required this.notes,
    required this.installerUrl,
  });
}
```

- An **immutable value class**: every field is `final`, so once built a
  `ReleaseInfo` never changes. This mirrors `VocabAdjustment` — data that comes
  from outside (here, the GitHub API) and just gets passed around.
- **`version`** — the release's version with any leading `v` removed (`0.2.0`).
- **`notes`** — the release description shown to the user ("what's new").
- **`installerUrl`** — the direct download link to the `*-setup.exe` asset.
- The **`const` constructor** with `required` named params means callers must
  supply all three, and the object can be created at compile time when the
  values are constant. Named params make call sites self-documenting.

This class has **no behavior** — it only holds data. The repository builds it;
the ViewModel reads it.

---

## 3. `lib/update/update_repository.dart` — the external boundary

This is the only file that touches the network, the filesystem, and the OS. By
keeping all of that here, the ViewModel above it stays pure and testable.

### Imports

```dart
import 'dart:convert';                 // jsonDecode
import 'dart:io';                       // File, Process, exit, Platform
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart'; // getTemporaryDirectory
import 'package:toeic_coach/models/release_info.dart';
```

- `dart:convert` gives `jsonDecode` to parse GitHub's JSON response.
- `dart:io` gives file writing (`File`), launching another program
  (`Process`), quitting the app (`exit`), and OS path details (`Platform`).
- `as http` namespaces the package so calls read as `http.get(...)` — clearer
  than bare `get`.

### Repo coordinates + the API URL

```dart
static const String _owner = 'Superfang0726';
static const String _repo = 'toeic_coach';

static final Uri _latestReleaseUri = Uri.parse(
  'https://api.github.com/repos/$_owner/$_repo/releases/latest',
);
```

- `static const` = one shared compile-time constant for all instances (the `_`
  prefix makes it private to this file).
- `/releases/latest` is GitHub's endpoint that returns the newest **non-draft,
  non-prerelease** release as JSON. Unauthenticated calls are limited to 60/hour
  per IP — far more than occasional update checks need.

### `fetchLatestRelease()` — "is there a newer version?"

```dart
Future<ReleaseInfo?> fetchLatestRelease() async {
  try {
    final response = await http.get(
      _latestReleaseUri,
      headers: const {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) return null;
```

- `Future<ReleaseInfo?>` — runs asynchronously (network), and the `?` means it
  may return `null`. `null` is our "no update / couldn't check" signal.
- `await http.get(...)` sends the request and waits for the reply without
  freezing the UI. The `Accept` header asks GitHub for its stable JSON format.
- `statusCode != 200` → anything but success (404 = no releases yet, etc.) →
  bail out with `null`.

```dart
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final tag = (json['tag_name'] as String?)?.trim();
    if (tag == null || tag.isEmpty) return null;
```

- `jsonDecode` turns the response text into a Dart `Map`. `as Map<String,
  dynamic>` tells the compiler its shape (string keys, any values).
- `tag_name` is the git tag of the release (e.g. `v0.2.0`). `as String?` +
  `?.trim()` safely handles a missing field; if it's absent or blank we give up.

```dart
    final assets = (json['assets'] as List<dynamic>? ?? []);
    String? installerUrl;
    for (final asset in assets) {
      final map = asset as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? '';
      if (name.toLowerCase().endsWith('-setup.exe')) {
        installerUrl = map['browser_download_url'] as String?;
        break;
      }
    }
    if (installerUrl == null) return null;
```

- A release can have many uploaded files (`assets`). `?? []` defaults to an
  empty list if the field is missing, so the loop is always safe.
- We pick the asset whose filename ends in **`-setup.exe`** — this is the naming
  convention the release checklist enforces (see the `releasing-toeic-coach`
  skill in `.claude/skills/`). That
  decouples us from the exact version in the filename.
- `browser_download_url` is the direct link we'll download later. No installer
  asset → nothing to update to → `null`.

```dart
    return ReleaseInfo(
      version: _stripV(tag),
      notes: (json['body'] as String?)?.trim() ?? '',
      installerUrl: installerUrl,
    );
  } catch (e) {
    print('UpdateRepository.fetchLatestRelease failed: $e');
    return null;
  }
}
```

- Build the `ReleaseInfo`: normalize the tag (`v0.2.0` → `0.2.0`), use the
  release `body` as notes (empty string if none).
- The `try/catch` wraps **everything**: a dropped connection, malformed JSON,
  etc. all collapse to `null`. The app must work offline, so a failed check is
  silent (just a debug `print`, consistent with the rest of this codebase).

### `downloadInstaller(...)` — fetch the file, report progress

```dart
Future<File> downloadInstaller(
  String url,
  void Function(double progress) onProgress,
) async {
  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);
    if (response.statusCode != 200) {
      throw HttpException('Download failed (HTTP ${response.statusCode})');
    }
```

- Returns a `Future<File>` — the downloaded file on disk.
- `onProgress` is a **callback**: a function the caller passes in that we invoke
  repeatedly (0.0→1.0) so the UI can animate a progress bar. `void
  Function(double)` is its type.
- We use a `Client` + `send` (instead of `http.get`) because that gives a
  **stream** — we receive the file in chunks instead of all at once, which is
  what lets us measure progress and avoid holding the whole `.exe` in memory.
- Unlike the check, a failed *download* `throw`s — the user explicitly asked to
  update, so the error should surface (the ViewModel catches it).

```dart
    final tempDir = await getTemporaryDirectory();
    final fileName = url.split('/').last;
    final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    final sink = file.openWrite();
```

- `getTemporaryDirectory()` (path_provider) gives an OS temp folder we're
  allowed to write to. `Platform.pathSeparator` is `\` on Windows.
- `openWrite()` opens a streaming **sink** — we'll pour bytes into it.

```dart
    final total = response.contentLength ?? -1;
    int received = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress(total > 0 ? received / total : -1);
    }
    await sink.flush();
    await sink.close();
    return file;
  } finally {
    client.close();
  }
}
```

- `contentLength` is the total byte size if the server reports it; `-1` means
  "unknown" and we pass `-1` to `onProgress` so the UI can show an
  indeterminate bar.
- `await for (... in response.stream)` loops over the incoming chunks. Each
  chunk is written to disk (`sink.add`) and adds to `received`; the fraction
  `received / total` is reported as progress.
- `flush` + `close` make sure all bytes are on disk before we hand back the
  file.
- `finally { client.close(); }` always frees the network connection, even if
  something throws mid-download.

### `runInstallerAndExit(...)` — hand off and quit

```dart
Future<void> runInstallerAndExit(File installer) async {
  await Process.start(
    installer.path,
    const [],
    mode: ProcessStartMode.detached,
    runInShell: true,
  );
  exit(0);
}
```

- `Process.start` launches the downloaded installer as a **separate program**.
- `ProcessStartMode.detached` means the installer keeps running independently —
  it won't die when our app closes (which is the whole point).
- `exit(0)` immediately quits the Flutter app. This is essential: Windows locks
  a running `.exe`, so our app must be gone for the installer to overwrite it.
  Inno Setup is configured (`CloseApplications`) to close the app and replace
  the files; its `[Run]` section relaunches the new version.

### `_stripV(...)` — tiny helper

```dart
String _stripV(String tag) =>
    tag.startsWith('v') ? tag.substring(1) : tag;
```

- Turns the git-tag style `v0.2.0` into a plain `0.2.0`. The `=>` is shorthand
  for a one-expression function. Used so the version we store matches the format
  `package_info_plus` reports.

---

## 4. `lib/update/update_viewmodel.dart` — the coordinator

Holds the update *state* and orchestrates the repository. The UI only ever talks
to this; it never touches the network directly.

### The status enum

```dart
enum UpdateStatus { idle, checking, upToDate, available, downloading, error }
```

- A fixed set of phases the flow can be in. The dialog renders a different look
  for each — exactly like `ChatState` drives the chat screen. Using an `enum`
  (instead of loose booleans) makes the states mutually exclusive and
  exhaustive.

### Construction + dependency injection

```dart
class UpdateViewModel extends ChangeNotifier {
  final UpdateRepository _repository;

  UpdateViewModel({UpdateRepository? repository})
    : _repository = repository ?? UpdateRepository();
```

- `extends ChangeNotifier` — gives `notifyListeners()`, which tells the UI
  "state changed, rebuild." The dialog subscribes via `ListenableBuilder`.
- The constructor takes an **optional** repository. In the real app we pass
  nothing and it makes its own (`?? UpdateRepository()`); in a test we could
  pass a fake. This is *dependency injection* and is what keeps the class
  testable.

### State fields + getters

```dart
UpdateStatus _status = UpdateStatus.idle;
ReleaseInfo? _latest;
String _currentVersion = '';
double _progress = 0;     // 0..1, or -1 when total size is unknown
String? _errorMessage;

UpdateStatus get status => _status;
ReleaseInfo? get latest => _latest;
String get currentVersion => _currentVersion;
double get progress => _progress;
String? get errorMessage => _errorMessage;
```

- Fields are **private** (`_`); the UI reads them only through getters. That way
  the UI can't accidentally mutate state — all changes go through the methods
  below, which call `notifyListeners()`.

```dart
void _set(UpdateStatus status) {
  _status = status;
  notifyListeners();
}
```

- A helper so every status change also triggers a UI rebuild in one line.

### `checkForUpdate()`

```dart
Future<void> checkForUpdate() async {
  _set(UpdateStatus.checking);

  final info = await PackageInfo.fromPlatform();
  _currentVersion = info.version;

  final latest = await _repository.fetchLatestRelease();
  if (latest != null && isVersionNewer(latest.version, _currentVersion)) {
    _latest = latest;
    _set(UpdateStatus.available);
  } else {
    _set(UpdateStatus.upToDate);
  }
}
```

- Flip to `checking` (UI can show a spinner).
- `PackageInfo.fromPlatform()` reads our own running version (`0.1.0`).
- Ask the repository for the latest release. If it exists **and** is strictly
  newer, store it and go to `available`; otherwise `upToDate`.
- Note there's no `try/catch` here: the repository already swallows its errors
  and returns `null`, which lands us safely in `upToDate`. A failed check never
  blocks or scares the user.

### `startUpdate()`

```dart
Future<void> startUpdate() async {
  final latest = _latest;
  if (latest == null) return;

  _progress = 0;
  _set(UpdateStatus.downloading);
  try {
    final installer = await _repository.downloadInstaller(
      latest.installerUrl,
      (p) {
        _progress = p;
        notifyListeners();
      },
    );
    await _repository.runInstallerAndExit(installer); // exits the process
  } catch (e) {
    _errorMessage = '更新失敗：$e';
    _set(UpdateStatus.error);
  }
}
```

- Guard: only runs if we actually have a release in hand.
- Switch to `downloading`, then call the repository. The inline function
  `(p) { _progress = p; notifyListeners(); }` is the `onProgress` callback — each
  reported fraction updates `_progress` and rebuilds the bar.
- On success, `runInstallerAndExit` never returns (the app exits). If anything
  fails, we catch it, store a Chinese error message (matching the app's UI
  language), and move to `error` so the dialog can show it.

### `isVersionNewer(...)` — the comparison (unit-tested)

```dart
bool isVersionNewer(String latest, String current) {
  final a = _segments(latest);
  final b = _segments(current);
  if (a == null || b == null) return false;

  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final ai = i < a.length ? a[i] : 0;
    final bi = i < b.length ? b[i] : 0;
    if (ai != bi) return ai > bi;
  }
  return false; // all segments equal
}
```

- A **top-level, pure** function (not inside the class) so the test file can
  call it directly with no Flutter setup. "Pure" = same input → same output, no
  side effects.
- Parse both versions into number lists (e.g. `[0, 2, 0]`). If either is
  malformed, treat as "not newer" (safe default — never nag on garbage).
- Walk the segments left to right. Missing trailing segments count as `0`, so
  `0.2` and `0.2.0` compare equal. The first differing segment decides the
  result (`ai > bi`). If all equal, it's not newer.
- This is why the tests check `0.10.0 > 0.9.0` — string comparison would wrongly
  say `"0.10.0" < "0.9.0"`; numeric comparison gets it right.

### `_segments(...)` — version → numbers

```dart
List<int>? _segments(String version) {
  var v = version.trim();
  if (v.startsWith('v')) v = v.substring(1);
  v = v.split(RegExp(r'[-+]')).first;
  final parts = v.split('.');
  final result = <int>[];
  for (final part in parts) {
    final n = int.tryParse(part);
    if (n == null) return null;
    result.add(n);
  }
  return result.isEmpty ? null : result;
}
```

- Trim spaces, drop a leading `v`.
- `split(RegExp(r'[-+]')).first` cuts off anything after a `-` or `+` — so
  `0.2.0-beta` and `0.2.0+5` both reduce to `0.2.0`. (Build/pre-release tags
  don't affect "is it newer".)
- Split on `.` and parse each piece with `int.tryParse`, which returns `null`
  instead of throwing on non-numbers. Any non-numeric piece → whole thing is
  `null` (malformed). An empty result is also `null`.

---

## 5. `test/update_viewmodel_test.dart` — proving the logic

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/update/update_viewmodel.dart';

void main() {
  group('isVersionNewer', () {
    test('a higher patch is newer', () {
      expect(isVersionNewer('0.2.0', '0.1.0'), isTrue);
    });
    ...
```

- `flutter_test` provides `group`, `test`, `expect`, and matchers like `isTrue`.
- `group(...)` bundles related tests under one name for readable output.
- Each `test('description', () { ... })` is one case. `expect(actual, matcher)`
  fails the test if `actual` doesn't satisfy `matcher`.
- We only test `isVersionNewer` because it's the one piece of **real logic** with
  tricky edge cases. The repository (network/IO) and dialog (UI) are verified by
  actually running the app, not unit tests.

The cases, and why each exists:

| Test | Guards against |
|------|----------------|
| `0.2.0 > 0.1.0` → true | the basic happy path |
| `0.1.0` vs `0.1.0` → false | offering an update to the same version |
| `0.1.0` vs `0.2.0` → false | offering a *downgrade* |
| `0.10.0 > 0.9.0` → true | the classic string-vs-number bug |
| leading `v` on either side | tag format (`v0.2.0`) vs runtime format (`0.2.0`) |
| `+build` / `-beta` suffixes | suffixes wrongly counting as differences |
| `0.2` vs `0.2.0` | different segment counts |
| `'abc'` → false | malformed/garbage input crashing or nagging |

Run them with:

```bash
flutter test test/update_viewmodel_test.dart
```

All 8 pass. ✅

---

## 6. `lib/update/update_dialog.dart` — what the user sees

A `StatelessWidget` that *reads* the ViewModel and rebuilds whenever it changes.
It holds no state of its own — that all lives in `UpdateViewModel`.

### The opener

```dart
static Future<void> show(BuildContext context, UpdateViewModel viewModel) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdateDialog(viewModel: viewModel),
  );
}
```

- A `static` convenience method so callers write `UpdateDialog.show(context,
  vm)` instead of repeating the `showDialog` boilerplate.
- `barrierDismissible: false` — tapping outside the box won't close it, so the
  user can't accidentally dismiss a download in progress; they use the buttons.

### Listening for changes

```dart
return ListenableBuilder(
  listenable: viewModel,
  builder: (context, _) {
    return AlertDialog( ... );
  },
);
```

- `ListenableBuilder` subscribes to the ViewModel. Every `notifyListeners()`
  (status change, progress tick) re-runs `builder`, repainting the dialog. This
  is the **same pattern `ChatUi` uses** — consistency with the codebase.

### Status-driven rendering

The dialog has three small helpers — `_titleFor`, `_content`, `_actions` — each a
`switch` on `viewModel.status`. This keeps "what to show" in one place per piece:

```dart
case UpdateStatus.downloading:
  final p = viewModel.progress;
  return Column(
    ...
    LinearProgressIndicator(
      value: p >= 0 ? p : null,   // null => indeterminate animation
      ...
    ),
    Text(p >= 0 ? '${(p * 100).toStringAsFixed(0)}%' : '下載中…'),
  );
```

- While downloading: a progress bar. `value: null` makes Flutter show the
  sweeping "indeterminate" animation when we don't know the file size (`-1`),
  otherwise it fills `0.0→1.0`. `toStringAsFixed(0)` formats `0.42` as `42`.

```dart
case UpdateStatus.error:
  return Text(viewModel.errorMessage ?? '發生未知錯誤。', ...);
```

- On error: just show the message the ViewModel stored.

```dart
default: // available
  final latest = viewModel.latest;
  return Column(
    ...
    Text('目前版本 ${viewModel.currentVersion} → 新版本 ${latest?.version ?? ''}'),
    if ((latest?.notes ?? '').isNotEmpty)
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(child: Text(latest!.notes, ...)),
      ),
  );
```

- The "available" view: current → new version line, then the release notes. The
  `ConstrainedBox` + `SingleChildScrollView` cap the notes at 200px tall and let
  long notes scroll instead of overflowing the dialog.
- `if (...)` inside a widget list is **collection-if** — the notes block is only
  added when there actually are notes.

### Buttons (`_actions`)

```dart
case UpdateStatus.downloading:
  return const []; // no buttons mid-download
...
default: // available
  return [
    TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('稍後')),
    FilledButton(onPressed: () => viewModel.startUpdate(), child: Text('立即更新')),
  ];
```

- During download: no buttons (can't cancel/dismiss).
- When available: **稍後 (Later)** just closes the dialog; **立即更新 (Update now)**
  calls `startUpdate()`. That flips status to `downloading`, which — thanks to
  the `ListenableBuilder` — instantly re-renders this same dialog into its
  progress-bar form. On success the app exits into the installer.

All colors come from `lib/theme/app_theme.dart` (`kPrimary`, `kTextSecondary`,
`kError`, …) so the dialog matches the rest of the app.

---

## 7. Wiring it in — `main.dart`

```dart
final UpdateViewModel _updateViewModel = UpdateViewModel();

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _updateViewModel.checkForUpdate();
    if (!mounted) return;
    if (_updateViewModel.status == UpdateStatus.available) {
      UpdateDialog.show(context, _updateViewModel);
    }
  });
}

@override
void dispose() {
  _updateViewModel.dispose();
  super.dispose();
}
```

- `addPostFrameCallback` runs **after the first frame is painted** — so the app
  window appears immediately and the network check happens in the background.
  Startup is never blocked waiting on GitHub.
- `if (!mounted) return;` — by the time the async check finishes, the widget
  could (in theory) be gone. Touching `context` after that would crash; this
  guard prevents it. Standard Flutter async-in-State safety.
- Only opens the dialog when status is `available`. Offline / up-to-date → the
  check ends silently and the user sees nothing.
- `dispose()` releases the ViewModel's listeners when the app widget is torn
  down, matching how every other `ChangeNotifier` is cleaned up.

---

## 8. Wiring it in — Settings (`settings_ui.dart`)

```dart
final UpdateViewModel _updateViewModel = UpdateViewModel();
bool _checkingForUpdate = false;

Future<void> _checkForUpdates() async {
  setState(() => _checkingForUpdate = true);
  await _updateViewModel.checkForUpdate();
  if (!mounted) return;
  setState(() => _checkingForUpdate = false);
  if (_updateViewModel.status == UpdateStatus.available) {
    UpdateDialog.show(context, _updateViewModel);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已是最新版本（${_updateViewModel.currentVersion}）')),
    );
  }
}
```

- This is the **manual** path — a button users can press anytime, and the one
  you'll use to test the flow without waiting for startup.
- `_checkingForUpdate` toggles a spinner on the button so a press gives instant
  feedback. `setState` rebuilds the settings dialog to reflect it.
- Same `available` → show dialog logic. The difference: when there's **no**
  update, it tells the user so explicitly via a `SnackBar` ("already up to
  date") — because they asked, they deserve an answer. (Startup stays silent.)

The button itself, in the dialog's `actions`:

```dart
TextButton(
  onPressed: _checkingForUpdate ? null : _checkForUpdates,
  child: _checkingForUpdate
      ? const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2))
      : const Text('檢查更新', ...),
),
```

- `onPressed: null` while checking **disables** the button so it can't be
  double-pressed; otherwise it runs `_checkForUpdates`.
- The child swaps between a tiny spinner and the label "檢查更新 (Check for
  updates)".

`dispose()` also disposes `_updateViewModel`, same as in `main.dart`.

---

## 9. The installer — `windows/installer/toeic_coach.iss`

This is **not** Dart — it's an [Inno Setup](https://jrsoftware.org/) script that
packs the built app into a single `setup.exe`. Key parts:

```ini
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
```

- The version is passed in at build time (`/DMyAppVersion=0.2.0`). This block is
  a fallback so the script still compiles if you forget. Keeping the version on
  the command line means it always matches `pubspec.yaml` — no second place to
  edit.

```ini
AppId={{8F3A1C7E-2B4D-4E9A-9C1F-6D5E7A8B9C0D}
```

- A permanent unique ID. Windows uses it to recognize "this is the same app" so
  a new installer **upgrades** the existing install instead of creating a
  duplicate. **Never change it** once shipped.

```ini
OutputDir=..\..\dist
OutputBaseFilename=toeic_coach-{#MyAppVersion}-setup
```

- Writes `dist\toeic_coach-0.2.0-setup.exe`. The `-setup.exe` suffix is exactly
  what `UpdateRepository.fetchLatestRelease()` searches for among the release
  assets — the convention that ties the two halves together.

```ini
CloseApplications=yes
```

- This makes an in-place update work: when the updater launches this installer
  while the app is running, `CloseApplications` closes the app so Inno Setup can
  replace its files; the `[Run]` section then relaunches the new version. This is
  the other side of the repository's "launch installer, then `exit(0)`".

```ini
[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs
```

- Copies the **entire** release output — the `.exe` *and* its required `data\`
  folder and DLLs — into the install directory (`{app}`). `recursesubdirs`
  includes the nested `data\` tree. A Flutter Windows app won't run without those
  companion files, so we ship the whole folder.

The `[Icons]` and `[Run]` sections create Start-Menu/desktop shortcuts and offer
to launch the app when the installer finishes.

---

## 10. The release checklist — `releasing-toeic-coach` skill

Not code — the human procedure for cutting a release: bump version → build →
make installer → commit → tag → draft notes → `gh release create` with the
installer attached. The two conventions everything depends on:

1. tag = `vX.Y.Z`
2. installer asset name ends in `-setup.exe`

Lives in `.claude/skills/releasing-toeic-coach/SKILL.md`; it's written to be
followed step by step when you publish.

---

## How it all fits together (the full loop)

1. You publish `v0.2.0` per the `releasing-toeic-coach` skill — a GitHub Release with
   `toeic_coach-0.2.0-setup.exe` attached.
2. A user on `0.1.0` launches the app. `main.dart`'s post-frame callback calls
   `UpdateViewModel.checkForUpdate()`.
3. `UpdateRepository.fetchLatestRelease()` asks GitHub, finds tag `v0.2.0` and
   the `-setup.exe` asset, returns a `ReleaseInfo`.
4. `isVersionNewer('0.2.0', '0.1.0')` is true → status `available` → the dialog
   shows the notes.
5. User clicks **立即更新**. `startUpdate()` → `downloadInstaller` (progress bar)
   → `runInstallerAndExit` launches the installer and quits the app.
6. Inno Setup replaces the files and relaunches `0.2.0`. Done.

Every piece has one job and a clear boundary: the **repository** talks to the
outside world, the **ViewModel** holds state and decides, the **dialog** shows
it, and the **installer script** does the actual file swap.

