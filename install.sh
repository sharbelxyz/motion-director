#!/usr/bin/env bash
# Install the motion-director skill into the AI agents on this machine.
#
#   curl -fsSL https://raw.githubusercontent.com/sharbelxyz/motion-director/main/install.sh | bash
#   ./install.sh                      every agent it finds (Claude Code, Codex, Hermes)
#   ./install.sh --claude             just one (or --codex, --hermes)
#   ./install.sh --dir <skills dir>   any other agent that reads SKILL.md folders
#
# Run it again to update. An existing copy is moved to ~/motion-director/backups first,
# never deleted.
set -euo pipefail

REPO="https://github.com/sharbelxyz/motion-director"
NAME="motion-director"
DATA="${MOTION_DIRECTOR_HOME:-$HOME/motion-director}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"

say() { printf '%s\n' "$*"; }

# ---- where the skill comes from: this checkout, or a fresh shallow clone
here=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$here" ] && [ -f "$here/skills/$NAME/SKILL.md" ]; then
  SRC="$here/skills/$NAME"
else
  command -v git >/dev/null 2>&1 || { say "git is needed to download the skill: https://git-scm.com"; exit 1; }
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  say "Downloading $NAME..."
  git clone --depth 1 -q "$REPO" "$tmp/repo"
  SRC="$tmp/repo/skills/$NAME"
fi

# ---- which agents
targets=()
while [ $# -gt 0 ]; do
  case "$1" in
    --claude) targets+=("Claude Code|$HOME/.claude/skills") ;;
    --codex)  targets+=("Codex|$CODEX_DIR/skills") ;;
    --hermes) targets+=("Hermes|$HOME/.hermes/skills/creative") ;;
    --dir)    shift; targets+=("custom|${1:?--dir needs a folder}") ;;
    -h|--help) sed -n '2,11p' "$0" 2>/dev/null || true; exit 0 ;;
    *) say "unknown option: $1"; exit 1 ;;
  esac
  shift
done
if [ ${#targets[@]} -eq 0 ]; then
  [ -d "$HOME/.claude" ] && targets+=("Claude Code|$HOME/.claude/skills")
  [ -d "$CODEX_DIR" ]    && targets+=("Codex|$CODEX_DIR/skills")
  [ -d "$HOME/.hermes" ] && targets+=("Hermes|$HOME/.hermes/skills/creative")
  if [ ${#targets[@]} -eq 0 ]; then
    say "No Claude Code, Codex or Hermes folder found, so installing for Claude Code (~/.claude/skills)."
    say "For another agent, run again with --dir <its skills folder>."
    targets+=("Claude Code|$HOME/.claude/skills")
  fi
fi

# ---- copy
stamp="$(date +%Y%m%d-%H%M%S)"
for t in "${targets[@]}"; do
  label="${t%%|*}"; dir="${t#*|}"
  mkdir -p "$dir"
  if [ -e "$dir/$NAME" ]; then
    mkdir -p "$DATA/backups"
    mv "$dir/$NAME" "$DATA/backups/$NAME-$(echo "$label" | tr ' A-Z' '-a-z')-$stamp"
    say "  previous $label copy moved to $DATA/backups/"
  fi
  cp -R "$SRC" "$dir/$NAME"
  say "Installed for $label: $dir/$NAME"
done

# ---- what is still missing on this machine (report only; the agent fixes it on first run)
say ""
if command -v node >/dev/null 2>&1; then
  node "$SRC/scripts/check-setup.mjs" || true
else
  say "Node.js 22+ is not installed yet. macOS: brew install node ffmpeg   Other: https://nodejs.org"
fi

say ""
say "Done. Open your agent and say:"
say ""
say "    set up motion director"
say ""
say "It checks your machine, learns your brand from your website, and renders a first"
say "graphic in your colours so you can see it working."
