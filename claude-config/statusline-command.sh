#!/usr/bin/env bash
# Claude Code statusLine command
# Renders: user@host:cwd  [used_tokens/window_size tokens, remaining%]
# Mirrors the standard Debian bash PS1 (without the trailing prompt character).
# Context usage is appended when token data is available.

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')

# Fall back to shell pwd if the JSON field is absent
if [ -z "$cwd" ] || [ "$cwd" = "null" ]; then
  cwd=$(pwd)
fi

debian_chroot=${debian_chroot:-}

# Extract context window fields (pre-calculated by Claude Code)
used_pct=$(echo "$input"       | jq -r '.context_window.used_percentage       // empty')
remaining_pct=$(echo "$input"  | jq -r '.context_window.remaining_percentage  // empty')
total_input=$(echo "$input"    | jq -r '.context_window.total_input_tokens    // empty')
window_size=$(echo "$input"    | jq -r '.context_window.context_window_size   // empty')

# Build the context suffix only when data is present (no messages yet → fields are null)
ctx=""
if [ -n "$used_pct" ] && [ -n "$remaining_pct" ] && [ -n "$total_input" ] && [ -n "$window_size" ]; then
  used_pct_r=$(printf '%.0f' "$used_pct")
  remaining_pct_r=$(printf '%.0f' "$remaining_pct")
  # Render as: [12k/200k tokens · 94% left]
  total_input_k=$(echo "$total_input $window_size" | awk '{printf "%dk/%dk", $1/1000, $2/1000}')
  ctx=$(printf " \033[00;33m[%s tokens \xc2\xb7 %s%% left]\033[00m" \
    "$total_input_k" "$remaining_pct_r")
fi

printf "%s\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m%s" \
  "${debian_chroot:+($debian_chroot)}" \
  "$(whoami)" \
  "$(hostname -s)" \
  "$cwd" \
  "$ctx"
