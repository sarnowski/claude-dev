# claude-dev

A devcontainer that wraps [Claude Code](https://claude.com/claude-code) along
with a kitchen-sink set of dev tools (languages, cloud CLIs, Docker, etc.) so
Claude runs in an isolated, reproducible environment instead of directly on the
host.

Three CLI commands wrap it:

- `claude` — start Claude Code inside the container
- `claude-shell` — drop into a bash shell inside the container (same mounts)
- `claude-update` — (re)build the container image from `Dockerfile`

## Prerequisites

- Docker (Docker Desktop on macOS, or Docker Engine on Linux)
- `~/.local/bin` on your `PATH`

## Setup

After cloning the repo, link the three commands into `~/.local/bin` and build
the image. The example below assumes you cloned to `~/Projects/claude-dev`;
adjust the path if you cloned somewhere else.

```bash
cd ~/.local/bin

# Optional: if you already have the official `claude` installed here,
# preserve it as `claude-native` so it stays accessible.
[ -L claude ] && [ ! -e claude-native ] && mv claude claude-native

ln -sf ~/Projects/claude-dev/bin/claude        claude
ln -sf ~/Projects/claude-dev/bin/claude-shell  claude-shell
ln -sf ~/Projects/claude-dev/bin/claude-update claude-update
```

Then build the image (first build takes a while — many toolchains):

```bash
claude-update
```

You're done. From any directory:

```bash
claude          # launches Claude Code in the container, mounted at $PWD
claude-shell    # bash shell in the same container/environment
```

## Shared Claude config

`claude-config/` in this repo **is** the container's `~/.claude/` —
bind-mounted read-write on every launch. Tracked files (`CLAUDE.md`,
`settings.json`, `agents/`, `commands/`, `skills/`, `hooks/`) are shared
across machines via git; volatile runtime state (`projects/`, `todos/`,
`history.jsonl`, etc.) accumulates here but is gitignored
(`claude-config/.gitignore`).

- Pulling new commits is enough — no image rebuild needed for config changes.
- Edits made by Claude inside a session land directly in your working tree.
- `git add claude-config/ && git commit && git push` to share to other
  machines.

For per-machine setting overrides, drop a `settings.local.json` in
`claude-config/` — it's gitignored, and Claude applies it on top of
`settings.json` automatically.

See `claude-config/README.md` for the full story (and a caveat about state
divergence if you mix this with `claude-native`).

## What gets mounted

- **Current working directory** — at the same path inside the container, so
  paths in tool output line up with the host.
- **`claude-config/` from the repo** (RW) → mounted as the container's
  `~/.claude/`. Holds both tracked config and gitignored runtime state.
- **Docker socket** (`/var/run/docker.sock`) — the container can drive the host
  Docker daemon. **Note: this effectively gives the container root on the host.**
- **Read-only when present**: `~/.claude.json`, `~/.gitconfig`, `~/.ssh`,
  `~/.aws`, `~/.azure`, `~/.config/gh`, `~/.kube`, `~/.config/gcloud` — so git,
  gh, ssh, and cloud CLIs just work with your host credentials.
- **Forwarded env vars**: `TERM`, `COLORTERM`, `EDITOR`, `ANTHROPIC_API_KEY`,
  `GITHUB_TOKEN`/`GH_TOKEN`, `AWS_PROFILE`, `AWS_REGION`,
  `GOOGLE_CLOUD_PROJECT`.

## Adding tools

Edit `Dockerfile`, then rerun `claude-update`. Layer caching means most edits
only rebuild from the changed layer downward, so adding a single apt package or
language toolchain is usually fast.

## User mapping

`claude-update` bakes your host UID/GID into the image (via `--build-arg
USER_UID=$(id -u) USER_GID=$(id -g)`), so files written into mounted volumes
are owned by you on the host, not root. If you ever run this on a different
machine with a different UID/GID, just rerun `claude-update` there.
