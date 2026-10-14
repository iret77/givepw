#!/usr/bin/env bash
# install.sh — install givepw into ~/.local/bin (or $GIVEPW_BIN_DIR).
#
#   curl -fsSL https://raw.githubusercontent.com/iret77/givepw/main/install.sh | bash
#
# GIVEPW_REF picks a branch or tag (default main).
set -euo pipefail

ref="${GIVEPW_REF:-main}"
dir="${GIVEPW_BIN_DIR:-$HOME/.local/bin}"
url="https://raw.githubusercontent.com/iret77/givepw/$ref/givepw"

command -v curl >/dev/null 2>&1 || { echo "install.sh: curl not found" >&2; exit 1; }
mkdir -p "$dir"
tmp=$(mktemp "${TMPDIR:-/tmp}/givepw.XXXXXX")
trap 'rm -f "$tmp"' EXIT

curl -fsSL "$url" -o "$tmp"
head -n 1 "$tmp" | grep -q '^#!/usr/bin/env bash' || { echo "install.sh: $url does not look like givepw" >&2; exit 1; }
bash -n "$tmp"
chmod 0755 "$tmp"
mv -f "$tmp" "$dir/givepw"
trap - EXIT

echo "$("$dir/givepw" --version) installed to $dir/givepw"
case ":$PATH:" in *":$dir:"*) ;; *) echo "Note: $dir is not on your PATH." ;; esac
