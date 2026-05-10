# claude-config

This directory **is** the container's `~/.claude/`. `bin/_claude-run`
bind-mounts it read-write at `/home/dev/.claude/` on every launch.

That means:

- Tracked files here (`CLAUDE.md`, `settings.json`, `agents/`, `commands/`,
  `skills/`, `hooks/`) are shared across machines via git.
- Volatile state Claude writes at runtime (`projects/`, `todos/`,
  `shell-snapshots/`, `history.jsonl`, `.credentials.json`, etc.) accumulates
  in this directory but is **gitignored** — see `.gitignore`.
- Edits made by Claude inside a session — adding a slash command, tweaking
  `CLAUDE.md` — land directly in your working tree, ready for `git diff` /
  `git commit`.
- A change committed in the repo is picked up by the next `claude` run on any
  machine that has pulled — **no `claude-update` rebuild required.**

## What's tracked

| Path             | Purpose                                                |
|------------------|--------------------------------------------------------|
| `CLAUDE.md`      | Global user instructions (style, role, preferences).   |
| `settings.json`  | Model, theme, permissions, hooks, env vars.            |
| `agents/`        | Custom subagent definitions.                           |
| `commands/`      | Custom slash commands.                                 |
| `skills/`        | Custom skills.                                         |
| `hooks/`         | Hook scripts referenced from `settings.json`.          |

## What's NOT tracked (.gitignore)

- `projects/`, `todos/`, `shell-snapshots/`, `history.jsonl` — session state
- `statsig/`, `ide/`, `__store.db` — caches
- `.credentials.json` — auth tokens (Linux only; macOS uses Keychain). Keep
  this in `.gitignore` no matter what.
- `.claude.json` — OAuth account / theme / onboarding state (mounted at
  `~/.claude.json` in the container, sibling of `~/.claude/`)
- `plugins/` — has machine-specific install paths
- `settings.local.json` — per-machine setting overrides
- `caches/` — tool caches (Maven, Cargo, Go, npm, Mix, Hex, etc.) bind-mounted
  into the container at their canonical paths so deps don't re-download every
  run. Can grow large; safe to delete to reclaim disk.

## Per-machine overrides

Drop a `settings.local.json` in this directory. It's gitignored, and Claude
Code applies it on top of `settings.json` automatically.

## Updating

Either edit files here directly, or let Claude modify them inside a session —
both write through.

```bash
git pull                                # pick up other machines' changes
# ...edit, or run a claude session that updates config...
git add . && git commit && git push
```

## Caveat: state divergence with `claude-native`

Container sessions store their `projects/`, `todos/`, `history.jsonl` here in
the repo. Host-side `claude-native` (the unwrapped binary) writes to host
`~/.claude/`. If you mix the two, you'll see different histories in each.
