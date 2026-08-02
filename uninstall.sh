#!/usr/bin/env bash
# uninstall.sh — removes claude-usage-bar from the system

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
HOOKS_DEST="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
STATE_FILE="$CLAUDE_DIR/.claude-usage-state.json"
MODEL_STATE_FILE="$CLAUDE_DIR/.claude-usage-models.json"
JQ=$(command -v jq || echo "/usr/bin/jq")

SWIFTBAR_DIR="$HOME/Library/Application Support/SwiftBar"
XBAR_DIR="$HOME/Library/Application Support/xbar/plugins"
CAVEMAN_SCRIPT="/Users/$(whoami)/.claude/plugins/cache/caveman"

echo "claude-usage-bar uninstaller"
echo ""

# ── Remove hook scripts ───────────────────────────────────────────────────────
for f in usage-statusline.sh usage-models-refresh.sh claude-usage-bar.1m.sh; do
  if [ -f "$HOOKS_DEST/$f" ]; then
    rm "$HOOKS_DEST/$f"
    echo "  ✓ Removed $HOOKS_DEST/$f"
  fi
done

# ── Remove state file ─────────────────────────────────────────────────────────
if [ -f "$STATE_FILE" ]; then
  rm "$STATE_FILE"
  echo "  ✓ Removed state file"
fi
if [ -f "$MODEL_STATE_FILE" ]; then
  rm "$MODEL_STATE_FILE"
  echo "  ✓ Removed model usage cache"
fi
if [ -f "$CLAUDE_DIR/.claude-usage-models-optin" ]; then
  rm "$CLAUDE_DIR/.claude-usage-models-optin"
  echo "  ✓ Removed per-model opt-in marker"
fi

# ── Remove / restore settings.json entry ─────────────────────────────────────
if [ -f "$SETTINGS" ]; then
  CURRENT_CMD=$("$JQ" -r '.statusLine.command // .statusLine // empty' "$SETTINGS" 2>/dev/null || echo "")

  if echo "$CURRENT_CMD" | grep -q "usage-statusline.sh"; then
    # Check if caveman is still around — restore its entry if so
    CAVEMAN_HOOK=$(find "$CLAUDE_DIR/plugins/cache/caveman" -name "caveman-statusline.sh" 2>/dev/null | head -1 || echo "")

    if [ -n "$CAVEMAN_HOOK" ] && [ -f "$CAVEMAN_HOOK" ]; then
      "$JQ" --arg cmd "bash \"$CAVEMAN_HOOK\"" \
        '.statusLine = {type: "command", command: $cmd}' \
        "$SETTINGS" > /tmp/claude-settings.tmp && mv /tmp/claude-settings.tmp "$SETTINGS"
      echo "  ✓ Restored caveman statusLine"
    else
      "$JQ" 'del(.statusLine)' \
        "$SETTINGS" > /tmp/claude-settings.tmp && mv /tmp/claude-settings.tmp "$SETTINGS"
      echo "  ✓ Removed statusLine from settings.json"
    fi
  else
    echo "  ℹ  statusLine not managed by claude-usage-bar — not modified"
  fi
fi

# ── Kill and remove native app ────────────────────────────────────────────────
APP_DEST="$HOME/Applications/ClaudeUsageBar.app"
pkill -x ClaudeUsageBar 2>/dev/null && echo "  ✓ Stopped ClaudeUsageBar" || true
if [ -d "$APP_DEST" ]; then
  rm -rf "$APP_DEST"
  echo "  ✓ Removed $APP_DEST"
fi

# ── Remove SwiftBar/xbar plugin ───────────────────────────────────────────────
for dir in "$SWIFTBAR_DIR" "$XBAR_DIR" "$HOME/Documents/SwiftBar"; do
  if [ -f "$dir/claude-usage-bar.1m.sh" ]; then
    rm "$dir/claude-usage-bar.1m.sh"
    echo "  ✓ Removed plugin from $dir"
  fi
done

echo ""
echo "Done. Restart Claude Code to apply changes."
