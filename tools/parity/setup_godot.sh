#!/usr/bin/env bash
# Install Godot 4.7.2 (Linux, headless-capable) and its Web export templates
# if they are missing, then print the Godot binary path. Safe to run often.
#   GODOT_DIR      where the binary goes      (default /opt/godot)
#   TEMPLATES_DIR  where templates go         (default ~/.local/share/godot/export_templates/4.7.2.stable)
set -euo pipefail
VER=4.7.2
URL="https://github.com/godotengine/godot/releases/download/${VER}-stable"
GODOT_DIR="${GODOT_DIR:-/opt/godot}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$HOME/.local/share/godot/export_templates/${VER}.stable}"
BIN="$GODOT_DIR/Godot_v${VER}-stable_linux.x86_64"
log() { echo "[setup_godot] $*" >&2; }

if [ ! -x "$BIN" ]; then
  log "downloading Godot $VER"
  mkdir -p "$GODOT_DIR"; tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/godot.zip" "$URL/Godot_v${VER}-stable_linux.x86_64.zip"
  unzip -oq "$tmp/godot.zip" -d "$GODOT_DIR"; rm -rf "$tmp"
  chmod +x "$BIN"
fi
if [ -w /usr/local/bin ] && [ "$(readlink -f /usr/local/bin/godot 2>/dev/null)" != "$BIN" ]; then
  ln -sf "$BIN" /usr/local/bin/godot
fi
if [ ! -f "$TEMPLATES_DIR/web_nothreads_release.zip" ]; then
  log "downloading export templates (large, keeps only the Web ones)"
  mkdir -p "$TEMPLATES_DIR"; tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/tpl.tpz" "$URL/Godot_v${VER}-stable_export_templates.tpz"
  unzip -joq "$tmp/tpl.tpz" 'templates/web_nothreads_*' 'templates/version.txt' -d "$TEMPLATES_DIR"
  rm -rf "$tmp"
fi
echo "$BIN"
