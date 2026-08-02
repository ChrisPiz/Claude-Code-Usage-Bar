Claude Code usage and live system status in your macOS menu bar.

> Available in English and Spanish / Disponible en inglés y español.

![screenshot](docs/screenshot.png)

## What it does

ClaudeUsageBar shows your Claude Code usage and the live Claude system status in the macOS menu bar.

- **Usage** — current session (5h) and weekly limits with reset times
- **System status** — live status for Claude Code and Claude API from status.claude.com, updated every 5 minutes
- **Incident alerts** — macOS notifications when a new incident is detected (toggle in menu)
- **Badge icon** — red dot on the menu bar icon when there is an active incident

Open it once, keep it in the menu bar, and check your usage without opening Claude settings.

---

## Requirements

- macOS 13+
- [Claude Code](https://claude.ai/code) with a Pro or Team subscription

---

## Install

### Download the DMG

Download `ClaudeUsageBar.dmg` from the [latest release](https://github.com/ChrisPiz/Claude-Code-Usage-Bar/releases/latest), open it, and drag `ClaudeUsageBar.app` to `Applications`.

Open the app once. It configures Claude Code automatically.

Restart Claude Code, then send any message. The menu bar percentage updates after Claude Code returns usage data.

If you already have a custom Claude Code `statusLine`, the app will not overwrite it.

Unsigned local builds may require right-click → Open. Public releases should be signed and notarized.

---

## Auto-start on login

Add the app to Login Items so it launches automatically:

**System Settings → General → Login Items → +** → select `/Applications/ClaudeUsageBar.app`

---

## Advanced

If you already have a custom `statusLine` script, the app won't overwrite it. Add this snippet to your existing script:

```bash
# claude-usage-bar state update
USAGE_BAR="/Applications/ClaudeUsageBar.app/Contents/MacOS/ClaudeUsageBar"
if [ -x "$USAGE_BAR" ]; then
  cat | "$USAGE_BAR" --statusline >/dev/null
  printf '%s\n' "$your_existing_output"
fi
```

---

## Per-model weekly limits (opt-in)

Some plans have an extra weekly window scoped to a single model (e.g. **Fable**). Claude Code's statusLine payload doesn't include it, so showing it requires querying the account usage endpoint with your Claude Code OAuth token (read from the login keychain, falling back to `~/.claude/.credentials.json`). Because that touches your credentials, the feature is **off by default**.

Enable it from the menu bar (**Per-Model Limits**) or manually:

```bash
touch ~/.claude/.claude-usage-models-optin
```

You'll get an extra badge in the statusline (`7dF:71%`) and a "Weekly (Fable)" row in the menu. Results are cached in `~/.claude/.claude-usage-models.json` for 5 minutes; if the data can't be refreshed for over 6 hours (expired token, offline) badges are hidden and menu rows are marked stale. Disable it the same way (toggle off, or delete the marker file); the token itself is never stored anywhere.

---

## Building a DMG

For maintainers:

```bash
bash build.sh
```

The build writes:

- `dist/ClaudeUsageBar.app`
- `dist/ClaudeUsageBar.dmg`

Set `CODE_SIGN_IDENTITY` to sign with a Developer ID certificate. Without it, the app is ad-hoc signed for local testing.

---

## Uninstall

Quit `ClaudeUsageBar`, delete it from `Applications`, and remove the `statusLine` entry from `~/.claude/settings.json`.

---

## License

MIT

Independent project. Not affiliated with, endorsed by, or sponsored by Anthropic, Claude, or Claude Code.
