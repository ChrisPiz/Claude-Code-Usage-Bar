#!/usr/bin/env bash
# install.sh — claude-usage-bar installer
#
# Usage (from clone):  bash install.sh
# Usage (one-liner):   bash <(curl -s https://raw.githubusercontent.com/ChrisPiz/Claude-Code-Usage-Bar/main/install.sh)

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/ChrisPiz/Claude-Code-Usage-Bar/main"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DEST="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
JQ="/usr/bin/jq"

APP_NAME="ClaudeUsageBar"
INSTALL_DIR="$HOME/Applications"
APP_DEST="$INSTALL_DIR/$APP_NAME.app"

SWIFTBAR_DIR="$HOME/Documents/SwiftBar"
SWIFTBAR_LIBRARY="$HOME/Library/Application Support/SwiftBar"
XBAR_DIR="$HOME/Library/Application Support/xbar/plugins"

# ── Resolve script location ──────────────────────────────────────────────────
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  LOCAL_HOOKS="$SCRIPT_DIR/hooks"
  LOCAL_SRC="$SCRIPT_DIR/src"
  LOCAL_BUILD="$SCRIPT_DIR/build.sh"
else
  LOCAL_HOOKS=""
  LOCAL_SRC=""
  LOCAL_BUILD=""
fi

echo "claude-usage-bar installer"
echo ""

# ── Preflight checks ─────────────────────────────────────────────────────────
if ! command -v "$JQ" &>/dev/null && ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi
JQ=$(command -v jq)

if [ ! -f "$SETTINGS" ]; then
  echo "Error: ~/.claude/settings.json not found. Is Claude Code installed?"
  exit 1
fi

# ── Install hook scripts to ~/.claude/hooks/ ─────────────────────────────────
mkdir -p "$HOOKS_DEST"

install_script() {
  local name="$1"
  local dest="$HOOKS_DEST/$name"

  if [ -n "$LOCAL_HOOKS" ] && [ -f "$LOCAL_HOOKS/$name" ]; then
    cp "$LOCAL_HOOKS/$name" "$dest"
  else
    curl -fsSL "$REPO_RAW/hooks/$name" -o "$dest"
  fi
  chmod +x "$dest"
}

echo "Installing scripts to $HOOKS_DEST ..."
install_script "usage-statusline.sh"
install_script "usage-models-refresh.sh"
install_script "claude-usage-bar.1m.sh"
echo "  ✓ usage-statusline.sh"
echo "  ✓ usage-models-refresh.sh"
echo "  ✓ claude-usage-bar.1m.sh"

# ── Wire settings.json ───────────────────────────────────────────────────────
HOOK_PATH="$HOOKS_DEST/usage-statusline.sh"
HOOK_CMD="bash \"$HOOK_PATH\""

echo ""
echo "Configuring statusLine in settings.json ..."

CURRENT_CMD=$("$JQ" -r '.statusLine.command // .statusLine // empty' "$SETTINGS" 2>/dev/null || echo "")

if [ -z "$CURRENT_CMD" ]; then
  "$JQ" --arg cmd "$HOOK_CMD" \
    '. + {statusLine: {type: "command", command: $cmd}}' \
    "$SETTINGS" > /tmp/claude-settings.tmp && mv /tmp/claude-settings.tmp "$SETTINGS"
  echo "  ✓ statusLine configured"

elif echo "$CURRENT_CMD" | grep -q "usage-statusline.sh"; then
  "$JQ" --arg cmd "$HOOK_CMD" \
    '.statusLine.command = $cmd' \
    "$SETTINGS" > /tmp/claude-settings.tmp && mv /tmp/claude-settings.tmp "$SETTINGS"
  echo "  ✓ statusLine updated (already installed)"

elif echo "$CURRENT_CMD" | grep -q "caveman-statusline.sh"; then
  "$JQ" --arg cmd "$HOOK_CMD" \
    '.statusLine = {type: "command", command: $cmd}' \
    "$SETTINGS" > /tmp/claude-settings.tmp && mv /tmp/claude-settings.tmp "$SETTINGS"
  echo "  ✓ Replaced caveman statusLine (usage-statusline.sh includes caveman badge)"

else
  echo "  ⚠  Custom statusLine detected — NOT overwritten."
  echo ""
  echo "  Add this to your existing statusline script to include usage badges:"
  echo ""
  echo "    # claude-usage-bar integration"
  echo "    source \"$HOOK_PATH\""
  echo ""
  echo "  Or see README for manual merge instructions."
fi

# ── Build and launch native menu bar app ────────────────────────────────────
echo ""

if [ "${SKIP_BUILD:-0}" = "1" ]; then
  echo "SKIP_BUILD=1 — skipping app build."
  if [ -d "$APP_DEST" ]; then
    pkill -x ClaudeUsageBar 2>/dev/null || true
    open "$APP_DEST"
    echo "  ✓ Launched existing $APP_DEST"
  else
    echo "  ⚠  $APP_DEST not found. Download from:"
    echo "  https://github.com/ChrisPiz/Claude-Code-Usage-Bar/releases/latest"
  fi
else
echo "Building ClaudeUsageBar.app ..."
if ! command -v swiftc &>/dev/null; then
  echo "  ⚠  swiftc not found — skipping native app build."
  echo "  Install Xcode Command Line Tools:  xcode-select --install"
else
  BUILD_TMP="/tmp/${APP_NAME}_build"
  MACOS_DIR="$APP_DEST/Contents/MacOS"

  rm -rf "$BUILD_TMP" && mkdir -p "$BUILD_TMP"
  mkdir -p "$MACOS_DIR"

  # Download or copy Swift source
  SWIFT_SRC="$BUILD_TMP/ClaudeUsageBar.swift"
  if [ -n "$LOCAL_SRC" ] && [ -f "$LOCAL_SRC/ClaudeUsageBar.swift" ]; then
    cp "$LOCAL_SRC/ClaudeUsageBar.swift" "$SWIFT_SRC"
  else
    curl -fsSL "$REPO_RAW/src/ClaudeUsageBar.swift" -o "$SWIFT_SRC"
  fi

  swiftc "$SWIFT_SRC" -o "$BUILD_TMP/$APP_NAME" -O 2>&1 | grep -v "^$" || true

  cp "$BUILD_TMP/$APP_NAME" "$MACOS_DIR/$APP_NAME"
  chmod +x "$MACOS_DIR/$APP_NAME"

  mkdir -p "$APP_DEST/Contents"
  cat > "$APP_DEST/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>           <string>ClaudeUsageBar</string>
  <key>CFBundleIdentifier</key>     <string>com.chrispiz.claude-usage-bar</string>
  <key>CFBundleVersion</key>        <string>1.0</string>
  <key>CFBundleExecutable</key>     <string>ClaudeUsageBar</string>
  <key>CFBundlePackageType</key>    <string>APPL</string>
  <key>LSUIElement</key>            <true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key> <string>13.0</string>
</dict>
</plist>
PLIST

  rm -rf "$BUILD_TMP"

  # Kill any previous instance
  pkill -x ClaudeUsageBar 2>/dev/null || true

  open "$APP_DEST"
  echo "  ✓ ClaudeUsageBar.app built and launched → $APP_DEST"
  echo "  ℹ  Add to Login Items: System Settings → General → Login Items"
fi
fi  # end SKIP_BUILD check

# ── Install SwiftBar plugin (optional) ──────────────────────────────────────
PLUGIN_SRC="$HOOKS_DEST/claude-usage-bar.1m.sh"

if [ -d "$SWIFTBAR_DIR" ] || [ -d "$SWIFTBAR_LIBRARY" ]; then
  echo ""
  TARGET_DIR="$SWIFTBAR_DIR"
  [ ! -d "$TARGET_DIR" ] && TARGET_DIR="$SWIFTBAR_LIBRARY"
  mkdir -p "$TARGET_DIR"
  cp "$PLUGIN_SRC" "$TARGET_DIR/claude-usage-bar.1m.sh"
  echo "  ✓ SwiftBar plugin also installed → $TARGET_DIR"
elif [ -d "$XBAR_DIR" ]; then
  echo ""
  cp "$PLUGIN_SRC" "$XBAR_DIR/claude-usage-bar.1m.sh"
  echo "  ✓ xbar plugin also installed → $XBAR_DIR"
fi

echo ""
echo "Done! Send a message in Claude Code to see the usage badges."
echo ""
echo "Optional: per-model weekly limits (e.g. Fable) in the badges and menu."
echo "This reads your Claude Code OAuth token to query the account usage API,"
echo "so it is OFF by default. Enable via the menu bar toggle (Per-Model"
echo "Limits) or:  touch ~/.claude/.claude-usage-models-optin"
