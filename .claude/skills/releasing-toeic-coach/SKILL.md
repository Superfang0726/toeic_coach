---
name: releasing-toeic-coach
description: Use when preparing or publishing a new TOEIC Coach release — bumping the app version, building the Windows installer, tagging, or drafting the GitHub release title and notes.
---

# Releasing TOEIC Coach (Windows)

## Overview

How to publish a new version so users can download it **and** so the in-app
auto-updater detects it. Follow the steps top to bottom for each release.

The auto-updater relies on two conventions, so don't break them:

1. The GitHub **tag** is `vX.Y.Z` (e.g. `v0.2.0`).
2. The uploaded installer is named **`toeic_coach-X.Y.Z-setup.exe`** (the
   `-setup.exe` suffix is how the app finds the right asset).

## One-time setup (do this once per machine)

1. **Install Inno Setup 6** — <https://jrsoftware.org/isdl.php>. `ISCC.exe`
   lives in the Inno Setup install directory — an **all-users** install puts
   it at `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`, a **per-user** install
   at `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`. Use whichever matches
   how you installed it in step 3 below.
2. **Install the GitHub CLI** — <https://cli.github.com/> — then `gh auth
   login` once (GitHub.com → HTTPS → login with a browser).

> **Code signing note:** the installer is **not** code-signed. On first
> download Windows SmartScreen may say *"Windows protected your PC"* — users
> click **More info → Run anyway**. Expected without a paid signing
> certificate; nothing in the app depends on it.

## Release steps

Pick the new version number first. Below uses `0.2.0` as the example —
replace it everywhere.

### 1. Bump the version

Edit `pubspec.yaml`:

```yaml
version: 0.2.0+2     # format is <version>+<build>; bump both
```

The part before `+` (`0.2.0`) is what users and the updater compare. The part
after `+` (`2`) is the build number; increment it each release.

### 2. Build the release app

```powershell
flutter pub get
flutter build windows --release
```

Output lands in `build\windows\x64\runner\Release\`.

### 3. Build the installer

```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=0.2.0 windows\installer\toeic_coach.iss
```

Per-user install: use
`& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" /DMyAppVersion=0.2.0 windows\installer\toeic_coach.iss`
instead. This produces `dist\toeic_coach-0.2.0-setup.exe`.

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

`git tag v0.2.0` marks this commit as the release point; `--tags` pushes it
along with your commits so GitHub knows about it.

### 6. Draft the release title and notes

Turning the commit log into release notes is curation, not transcription:
filter out everything that isn't user-facing, describe what's left in terms
of user impact, and write it the way this project always does.

1. **Find the range.** Last tag: `git tag --sort=-creatordate` (top entry).
   Commits since: `git log <last-tag>..HEAD --oneline`.
2. **Write the notes in Traditional Chinese.** This is fixed for this
   project, regardless of what language the commit messages are in.
3. **Filter the commit list.** Drop: merge commits, docs/plan/spec-only
   commits, test-only commits, chore/tooling commits (CI, `.claude/`, lint
   config), the version-bump/release commit itself, and internal
   refactors/renames with no observable behavior change. Keep: anything a
   user of the running app would actually notice.
4. **Read the diff, not just the message**, for each kept commit (`git show
   <hash>`). Commit messages are written for developers and often omit the
   detail that makes a description accurate to what a user will actually see.
5. **Write for the user.** Describe the behavior change, not the code
   change — no class/function/file names, no "refactor", no ticket numbers.
6. **Structure by how many kinds of change there are:**
   - One change → a flat paragraph or single bullet, no header.
   - Multiple changes → bullet list, grouped under `## 修正` (fixes) and/or
     `## 新功能` (new features) subtitles — only the categories that apply,
     in that order if both are present.
7. **Title is always the bare tag** (e.g. `v0.4.3`), matching `git tag` / the
   version field — never a descriptive title.

**Quick reference — include or drop?**

| Commit looks like | Include in notes? |
|---|---|
| `Merge pull request #N ...` | No |
| `docs: ...` / non-behavioral `chore: ...` | No |
| `test: ...` | No |
| `Release vX.Y.Z` (the bump commit) | No |
| Internal rename/refactor, no behavior change | No |
| `feat: ...` / `fix: ...` that changes runtime behavior | Yes — reworded for users |

**Common mistakes:**
- Writing the notes in English (or the commit messages' language) — always
  Traditional Chinese, no exceptions.
- Copy-pasting the commit message as the note text — commit messages target
  developers; release notes target users.
- Including an internal refactor because it touched a file users "depend
  on" — if there's no observable behavior change, it isn't release-notes
  material.
- Using English headers ("Fixes"/"Features") or forcing a header onto a
  single change — use exactly `## 修正` / `## 新功能`, and only when there's
  more than one item to group.

### 7. Create the GitHub Release + upload the installer

```powershell
gh release create v0.2.0 dist\toeic_coach-0.2.0-setup.exe --title "v0.2.0" --notes "<drafted notes from step 6>"
```

- `v0.2.0` — the tag this release points to (must match step 5).
- The `.exe` path — the asset users download and the updater fetches.
- `--notes` — **this exact text is shown inside the app's update dialog.**

That's it. The release is now the "latest" on GitHub, and any running copy of
an older version will offer the update on next launch (or via Settings →
**檢查更新**).

## Web UI fallback (if you'd rather not use `gh`)

Steps 1–5 are the same. For step 7:

1. Go to the repo on GitHub → **Releases** → **Draft a new release**.
2. Choose the tag `v0.2.0` you just pushed.
3. Set the title `v0.2.0` and paste in the release notes from step 6.
4. **Attach** `dist\toeic_coach-0.2.0-setup.exe` under "Attach binaries".
5. Click **Publish release**.

## How the auto-updater uses this

On launch (and from Settings), the app calls
`https://api.github.com/repos/Superfang0726/toeic_coach/releases/latest`, reads
the `tag_name`, compares it to its own version, and if the release is newer it
shows the notes and offers to download the `-setup.exe` asset and run it. The
installer (configured with `CloseApplications`) closes the running app and
replaces the files; its `[Run]` section relaunches the new version.
