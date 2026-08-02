#!/usr/bin/env bash
# usage-models-refresh.sh — caches per-model weekly limits (Fable, ...)
#
# Claude Code's statusLine payload only carries five_hour and seven_day, so the
# model-scoped weekly windows are read from the account usage endpoint and
# cached in ~/.claude/.claude-usage-models.json:
#
#   {"updated_at": 1785675714,
#    "models": [{"display_name":"Fable","used_percentage":71,"resets_at":1785916800}]}
#
# OPT-IN: this reads the Claude Code OAuth token (login keychain, falling back
# to ~/.claude/.credentials.json) and calls api.anthropic.com. It does nothing
# unless the marker file exists:
#
#   touch ~/.claude/.claude-usage-models-optin      # enable
#   rm    ~/.claude/.claude-usage-models-optin      # disable
#
# (The ClaudeUsageBar menu app toggles the same file via "Per-Model Limits".)
#
# Self-throttling: exits without touching the network while the cache is fresh.
# Exit codes mirror ClaudeUsageBar --refresh-models: 0 = rewritten, 2 = fresh,
# 3 = not opted in, 1 = failed (cache is left alone, so an expired token never
# blanks the row).
#
# Usage: bash usage-models-refresh.sh [--force]
#
# Project: https://github.com/ChrisPiz/Claude-Code-Usage-Bar

set -uo pipefail

CACHE_FILE="$HOME/.claude/.claude-usage-models.json"
OPTIN_FILE="$HOME/.claude/.claude-usage-models-optin"
CREDENTIALS_FILE="$HOME/.claude/.credentials.json"
TTL=300
API_URL="https://api.anthropic.com/api/oauth/usage"
KEYCHAIN_SERVICE="Claude Code-credentials"
JQ=$(command -v jq || echo /usr/bin/jq)

[ -x "$JQ" ] || exit 1
[ -f "$OPTIN_FILE" ] || exit 3

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

NOW=$(date +%s)

if [ "$FORCE" -eq 0 ] && [ -f "$CACHE_FILE" ]; then
  UPDATED=$("$JQ" -r '.updated_at // 0' "$CACHE_FILE" 2>/dev/null || echo 0)
  [ $((NOW - UPDATED)) -lt "$TTL" ] && exit 2
fi

# Same keychain item Claude Code itself reads, via the same binary, so no extra
# keychain prompt appears. Fallback: the plaintext credentials file used by
# installs where Claude Code doesn't store the token in the keychain.
TOKEN=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null \
  | "$JQ" -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
if [ -z "$TOKEN" ] && [ -f "$CREDENTIALS_FILE" ]; then
  TOKEN=$("$JQ" -r '.claudeAiOauth.accessToken // empty' "$CREDENTIALS_FILE" 2>/dev/null)
fi
[ -z "$TOKEN" ] && exit 1

# Token goes to curl via a stdin config file, NOT -H on the command line, so it
# never shows up in `ps` output. -4 avoids the long IPv6 fallback wait on
# networks that blackhole AAAA.
RESPONSE=$(curl -s4 --max-time 10 \
  -H "Content-Type: application/json" \
  --config - "$API_URL" 2>/dev/null <<EOF
header = "Authorization: Bearer $TOKEN"
EOF
)
[ -z "$RESPONSE" ] && exit 1

# fromdateiso8601 only eats "...Z", so drop the fractional seconds and fold the
# +00:00 offset the API sends; an unexpected offset just leaves resets_at null.
# Rounded to the minute because the API says 07:59:59 for the window the
# statusLine payload calls 08:00:00, and the two sit one row apart in the menu.
MODELS=$("$JQ" -c '
  [ (.limits // [])[]
    | select(.kind == "weekly_scoped")
    | select((.scope.model.display_name // "") != "")
    | select(.percent != null)
    | {display_name: .scope.model.display_name,
       used_percentage: .percent,
       resets_at: (if .resets_at
                   then ((.resets_at | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z")) as $t
                         | try (($t | fromdateiso8601 | . + 30) / 60 | floor | . * 60) catch null)
                   else null end)}
  ]' <<< "$RESPONSE" 2>/dev/null)
[ -z "$MODELS" ] && exit 1

TMP="$CACHE_FILE.tmp.$$"
"$JQ" -n --argjson ts "$NOW" --argjson models "$MODELS" \
  '{updated_at: $ts, models: $models}' > "$TMP" 2>/dev/null \
  && mv -f "$TMP" "$CACHE_FILE" || { rm -f "$TMP"; exit 1; }

exit 0
