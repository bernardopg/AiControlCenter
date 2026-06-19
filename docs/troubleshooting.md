# Troubleshooting

## The widget shows "Awaiting telemetry"

- Run the diagnostic commands in **Settings → Diagnostics**.
- Verify `command -v bash jq curl`.
- Authenticate the configured provider CLIs (`codex login`, `claude auth status`, `gh auth login`).

## A provider card shows an error

- Click **Retry** on the card, or use the per-provider threshold/health row in settings.
- Check the corresponding environment variable is exported in the process that starts DMS (graphical sessions do not inherit interactive-shell exports).
- Errors are isolated: one failed provider never hides healthy ones.

## Cards look empty or stale

- Data is marked stale after **twice** the refresh interval. Lower the interval or trigger a manual refresh from the control bar.
- Claude and 9Router analytics run in separate processes; a failure there only affects their telemetry panel.

## The panel does not update

- Desktop widgets pause fetching when not visible (hidden, on another monitor, or zero-sized). Move/resize it onto a visible area.
- Hot-reload after edits: `dms ipc call plugins reload aiControlCenter`.

## Notifications do not fire

- Confirm **Quota notifications** is enabled and the threshold is below the provider's current usage.
- Alerts are de-duplicated per quota window on disk (`~/.cache/AiControlCenter`); a new reset window re-arms them.

## Inspecting state

```bash
# Plugin settings (DMS-owned)
jq '.aiControlCenter // empty' ~/.config/DankMaterialShell/plugin_settings.json
# Local usage history
./providers/get-usage-history | jq .
```
