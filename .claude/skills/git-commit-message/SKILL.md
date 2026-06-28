Write a well-crafted Git commit message for the following changes: $ARGUMENTS

---

## Rules to Follow (all seven, every time)

1. **Separate subject from body with a blank line**
2. **Limit the subject line to 50 characters** (72 is the hard ceiling)
3. **Capitalize the subject line**
4. **Do not end the subject line with a period**
5. **Use the imperative mood** — "Fix bug", not "Fixed bug". Test: *"If applied, this commit will ___."*
6. **Wrap the body at 72 characters** (manually)
7. **Use the body to explain *what* and *why*, not *how*** — the code already shows how

## Output Format

Produce a complete, ready-to-use commit message in a code block:

```
Subject line of 50 chars or less, imperative mood

Optional body explaining what changed and why. Wrap
at 72 characters. Focus on motivation and context,
not implementation details which the code already shows.

Resolves: #123  ← optional issue reference
```

Skip the body if the change is genuinely self-explanatory (e.g., "Fix typo in README").

## Imperative Mood Starters

Add, Fix, Remove, Update, Refactor, Rename, Extract, Merge, Revert, Bump, Document, Test, Handle, Introduce, Simplify

## If No Arguments Were Provided

If `$ARGUMENTS` is empty, run `git diff --staged` to inspect staged changes, then generate the commit message based on what you find. If nothing is staged, run `git diff HEAD` instead.

## Reviewing an Existing Message

If the input looks like an existing commit message (rather than a description of changes), evaluate each of the seven rules, give specific feedback, and offer a revised version.

## Multiple Commits

If the changes span multiple concerns, suggest splitting them and generate a separate message for each.