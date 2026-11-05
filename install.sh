#!/usr/bin/env bash
# AICS Pro Plugin installer for macOS.
#
#   curl -fsSL https://github.com/djkim-wbd/after-effects-aics-plugin-dist/releases/latest/download/install | bash
#
# Downloads the plugin, checks its SHA-256, copies it into After Effects, and
# turns on the CEP setting the panel needs. Close After Effects first.
#
# Environment overrides:
#   AICS_BASE_URL  where to fetch the zip and checksums from

set -euo pipefail

BASE_URL="${AICS_BASE_URL:-https://github.com/djkim-wbd/after-effects-aics-plugin-dist/releases/latest/download}"
BASE_URL="${BASE_URL%/}"
ZIP_NAME="AICS-Pro-Plugin.zip"
BUNDLE="com.aicspro.aftereffects"
DEST="$HOME/Library/Application Support/Adobe/CEP/extensions/$BUNDLE"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  GREEN=$'\033[32m'; RED=$'\033[31m'; CYAN=$'\033[36m'
else
  BOLD=""; DIM=""; RESET=""; GREEN=""; RED=""; CYAN=""
fi

WORK_DIR=""
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

step() { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
info() { printf '  %s▸%s %s\n' "$CYAN" "$RESET" "$1"; }

fail() {
  printf '\n  %s✗%s %s\n' "$RED" "$RESET" "$1" >&2
  shift
  for line in "$@"; do printf '    %s%s%s\n' "$DIM" "$line" "$RESET" >&2; done
  printf '\n'
  exit 1
}

printf '\n  %sAICS Pro Plugin%s — After Effects\n\n' "$BOLD" "$RESET"

[ "$(uname -s)" = "Darwin" ] ||
  fail "This installer is for Mac." \
       "On Windows, download AICS-Pro-Plugin.zip from the latest release" \
       "and double-click \"Install AICS Pro Plugin.bat\"."

command -v curl >/dev/null || fail "curl is missing."
command -v unzip >/dev/null || fail "unzip is missing."
command -v shasum >/dev/null || fail "shasum is missing."

WORK_DIR="$(mktemp -d -t aics-pro-plugin)"
info "Downloading…"
curl -fsSL "$BASE_URL/checksums.txt" -o "$WORK_DIR/checksums.txt"
curl -fsSL --progress-bar "$BASE_URL/$ZIP_NAME" -o "$WORK_DIR/$ZIP_NAME"

EXPECTED="$(awk -v name="$ZIP_NAME" '$2 == name { print $1; exit }' "$WORK_DIR/checksums.txt")"
[ -n "$EXPECTED" ] || fail "checksums.txt has no line for $ZIP_NAME."
GOT="$(shasum -a 256 "$WORK_DIR/$ZIP_NAME" | awk '{ print $1 }')"
[ "$GOT" = "$EXPECTED" ] ||
  fail "The download did not match the published checksum." \
       "Got      $GOT" \
       "Expected $EXPECTED"

step "Download verified"
unzip -q "$WORK_DIR/$ZIP_NAME" -d "$WORK_DIR/unpacked"

ZXP="$(find "$WORK_DIR/unpacked" -name "$BUNDLE-*.zxp" | sort | tail -1 || true)"
[ -n "$ZXP" ] || fail "The zip did not contain $BUNDLE-*.zxp."

rm -rf "$DEST"
mkdir -p "$DEST"
unzip -q "$ZXP" -d "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

for v in 9 10 11 12 13; do
  defaults write "com.adobe.CSXS.$v" PlayerDebugMode 1 2>/dev/null || true
done
killall cfprefsd 2>/dev/null || true

step "Installed to $DEST"

printf '\n  %sNext:%s\n' "$BOLD" "$RESET"
printf '    1. Open After Effects (quit it first if it was already running).\n'
printf '    2. Preferences → Scripting & Expressions → tick\n'
printf '       “Allow Scripts to Write Files and Access Network”.\n'
printf '    3. Window → Extensions → AICS Pro Plugin.\n'
printf '    4. In the panel’s Settings, paste your tool key and click Connect.\n\n'
