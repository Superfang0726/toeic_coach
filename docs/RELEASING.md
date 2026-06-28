# Releasing TOEIC Coach (Windows)

How to publish a new version so users can download it **and** so the in-app
auto-updater detects it. Follow the steps top to bottom for each release.

The auto-updater relies on two conventions, so don't break them:

1. The GitHub **tag** is `vX.Y.Z` (e.g. `v0.2.0`).
2. The uploaded installer is named **`toeic_coach-X.Y.Z-setup.exe`** (the
   `-setup.exe` suffix is how the app finds the right asset).

---

## One-time setup (do this once per machine)

1. **Install Inno Setup 6** — the free Windows installer builder, from
   <https://jrsoftware.org/isdl.php>. After install, the compiler lives at
   `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`.
2. **Install the GitHub CLI** — <https://cli.github.com/> — then authenticate
   once:
   ```powershell
   gh auth login
   ```
   (Choose GitHub.com → HTTPS → login with a browser.)

> **Code signing note:** the installer is **not** code-signed. On first download
> Windows SmartScreen may say *"Windows protected your PC"* — users click
> **More info → Run anyway**. This is expected without a paid signing
> certificate and is a future improvement; nothing in the app depends on it.

---

## Release steps

Pick the new version number first. Below uses `0.2.0` as the example — replace
it everywhere.

### 1. Bump the version

Edit `pubspec.yaml`:

```yaml
version: 0.2.0+2     # format is <version>+<build>; bump both
```

- The part before `+` (`0.2.0`) is what users and the updater compare.
- The part after `+` (`2`) is the build number; increment it each release.

### 2. Build the release app

```powershell
flutter pub get
flutter build windows --release
```

Output lands in `build\windows\x64\runner\Release\`.

### 3. Build the installer

Pass the same version to Inno Setup's compiler:

```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=0.2.0 windows\installer\toeic_coach.iss
```

This produces `dist\toeic_coach-0.2.0-setup.exe`.

> Quick local sanity check: run that installer, confirm the app installs and
> launches, before publishing.

### 4. Commit the version bump

```powershell
git commit -am "Release v0.2.0"
```

### 5. Tag and push

```powershell
git tag v0.2.0
git push origin main --tags
```

- `git tag v0.2.0` marks this commit as the release point.
- `--tags` pushes the new tag along with your commits so GitHub knows about it.

### 6. Create the GitHub Release + upload the installer

```powershell
gh release create v0.2.0 dist\toeic_coach-0.2.0-setup.exe --title "v0.2.0" --notes "What changed in this version..."
```

- `v0.2.0` — the tag this release points to (must match step 5).
- The `.exe` path — the asset users download and the updater fetches.
- `--notes` — release notes; **this exact text is shown inside the app's update
  dialog**, so write it for users.

That's it. The release is now the "latest" on GitHub, and any running copy of an
older version will offer the update on next launch (or via Settings →
**檢查更新**).

---

## Web UI fallback (if you'd rather not use `gh`)

Steps 1–5 are the same. For step 6:

1. Go to the repo on GitHub → **Releases** → **Draft a new release**.
2. Choose the tag `v0.2.0` you just pushed.
3. Set the title `v0.2.0` and write the release notes.
4. **Attach** `dist\toeic_coach-0.2.0-setup.exe` under "Attach binaries".
5. Click **Publish release**.

---

## How the auto-updater uses this

On launch (and from Settings), the app calls
`https://api.github.com/repos/Superfang0726/toeic_coach/releases/latest`, reads
the `tag_name`, compares it to its own version, and if the release is newer it
shows the notes and offers to download the `-setup.exe` asset and run it. The
installer (configured with `CloseApplications`/`RestartApplications`) closes the
running app, replaces the files, and relaunches the new version.
