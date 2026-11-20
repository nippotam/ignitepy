#!/usr/bin/env bash
# install.sh — install the `ignitepy` command.
#
# Remote install:
#   curl -fsSL https://raw.githubusercontent.com/nippotam/ignitepy/main/install.sh | bash
#
# Local install (from a clone of the repo):
#   ./install.sh
#
# Options:
#   --uninstall   Remove ignitepy
#   --no-path     Do not edit your shell config file
#   -h, --help    Show this help
#
# Environment variables:
#   IGNITEPY_INSTALL_DIR  Where to install (default: ~/.local/bin)
#   IGNITEPY_REPO         GitHub repo as user/name (default: nippotam/ignitepy)
#   IGNITEPY_BRANCH       Branch to download from (default: main)
#   IGNITEPY_URL          Full URL of the script, overrides repo and branch
set -euo pipefail

REPO="${IGNITEPY_REPO:-nippotam/ignitepy}"
BRANCH="${IGNITEPY_BRANCH:-main}"
DEST_DIR="${IGNITEPY_INSTALL_DIR:-$HOME/.local/bin}"
URL="${IGNITEPY_URL:-https://raw.githubusercontent.com/$REPO/$BRANCH/ignitepy}"
TARGET="$DEST_DIR/ignitepy"

uninstall=0
edit_path=1

say()  { printf '%s\n' "$*"; }
die()  { printf 'install: error: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]:-$0}" 2>/dev/null | sed 's/^# \{0,1\}//' \
    || say "Usage: install.sh [--uninstall] [--no-path]"
}

for arg in "$@"; do
  case "$arg" in
    --uninstall) uninstall=1 ;;
    --no-path)   edit_path=0 ;;
    -h|--help)   usage; exit 0 ;;
    *) die "unknown option '$arg' (try --help)" ;;
  esac
done

# --- Uninstall
if [ "$uninstall" -eq 1 ]; then
  if [ -f "$TARGET" ]; then
    rm -f "$TARGET"
    say "✅ Removed $TARGET"
  else
    say "Nothing to remove: $TARGET does not exist"
  fi
  exit 0
fi

# --- Get the script: from the local clone if present, otherwise download it
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# BASH_SOURCE is empty when piped through `curl | bash`, so we only use local
# files when the installer itself is a real file (i.e. run from a clone).
src_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$src_dir" ] && [ -f "$src_dir/ignitepy" ]; then
  say "▶ Installing ignitepy from $src_dir"
  cp "$src_dir/ignitepy" "$tmp"
else
  command -v curl >/dev/null || die "curl not found"
  say "▶ Downloading ignitepy from $URL"
  curl -fsSL "$URL" -o "$tmp" || die "download failed. Check the URL and that the repo is public."
fi

head -n 1 "$tmp" | grep -q '^#!' || die "downloaded file does not look like a script"

mkdir -p "$DEST_DIR"
install -m 755 "$tmp" "$TARGET"
say "✅ Installed $TARGET"

# --- Make sure the install folder is on PATH
case ":$PATH:" in
  *":$DEST_DIR:"*) on_path=1 ;;
  *)               on_path=0 ;;
esac

if [ "$on_path" -eq 0 ]; then
  shell_name="$(basename "${SHELL:-}")"
  case "$shell_name" in
    zsh)  rc="$HOME/.zshrc" ;;
    bash) if [ "$(uname -s)" = "Darwin" ]; then rc="$HOME/.bash_profile"; else rc="$HOME/.bashrc"; fi ;;
    *)    rc="" ;;
  esac
  line="export PATH=\"$DEST_DIR:\$PATH\""

  if [ "$edit_path" -eq 1 ] && [ -n "$rc" ]; then
    if ! grep -qsF "$line" "$rc"; then
      printf '\n# Added by the ignitepy installer\n%s\n' "$line" >> "$rc"
      say "✅ Added $DEST_DIR to PATH in $rc"
    fi
    say "ℹ Open a new terminal, or run: source $rc"
  else
    say "⚠ $DEST_DIR is not on your PATH. Add this line to your shell config:"
    say "    $line"
  fi
fi

# --- Prerequisites
command -v uv  >/dev/null || say "⚠ uv not found. Install it: curl -LsSf https://astral.sh/uv/install.sh | sh"
command -v git >/dev/null || say "⚠ git not found. Install it from https://git-scm.com/downloads"

say ""
say "Try it:  ignitepy --help"
