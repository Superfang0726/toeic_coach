# PreToolUse guard: when the current git branch is `main`, ask the user to
# confirm before letting a file-writing tool (Edit/Write/NotebookEdit) run.
# Meaningful changes should be made on a feature branch (see CLAUDE.md > Git workflow);
# trivial edits (typo/comments) can be confirmed through and committed to main.
# On any other branch this emits nothing and exits 0 (allow).

# Emit stdout as UTF-8 so Claude Code parses the JSON (and Chinese reason) correctly,
# regardless of the machine's OEM/ANSI codepage.
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

$branch = (git rev-parse --abbrev-ref HEAD 2>$null)
if ($branch -eq 'main') {
  @{ hookSpecificOutput = @{
      hookEventName            = 'PreToolUse'
      permissionDecision       = 'ask'
      permissionDecisionReason = '目前在 main 分支。有意義的改動請先開 feature branch (git checkout -b ...);若只是瑣碎修改 (typo/註解),可核准後直接進行。'
  } } | ConvertTo-Json -Compress
}
exit 0
