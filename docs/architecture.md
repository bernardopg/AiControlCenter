# Architecture

## Components

```text
AiControlCenterWidget.qml        DesktopPluginComponent — runtime orchestration and dashboard
AiControlCenterSettings.qml      Provider selection, health UI, appearance
AiControlCenterI18n.qml          Locale loading and interpolation
providers/get-provider-usage     Multi-provider dispatcher and history writer
providers/get-provider-health    Prerequisite checks for settings
providers/get-codex-usage        Codex app-server protocol bridge
providers/get-claude-usage       Claude local analytics and quota bridge
providers/get-copilot-usage      Authenticated GitHub Copilot quota bridge
providers/get-provider-wrapper   Single-provider wrapper
providers/get-*-usage            Canonical provider entrypoints
```

## Runtime flow

1. The widget resolves its own plugin directory via `PluginService.getPluginPath` (or its QML URL fallback).
2. A binary-detect probe verifies the dispatcher is executable and `bash`, `jq`, `curl` are present.
3. On success it executes `get-provider-usage <provider-csv> <copilot-helper>` with `AIOC_HISTORY_MAX` in the environment.
4. The dispatcher calls one adapter per provider and validates every result with `jq`.
5. QML assigns the flattened JSON array to `providers` (no in-widget normalization), isolates errors, updates stale timestamps, and renders rows.
6. Claude details and 9Router analytics run in separate processes so their failure cannot block other providers.

## Desktop lifecycle

- The widget is a `DesktopPluginComponent` rendered on the wlr-layer-shell desktop layer.
- Fetching is **paused when the widget is not visible** (different monitor, hidden, or zero size) and resumed on return — unlike the DankBar sibling which always polls.
- `minWidth`/`minHeight`/`defaultWidth`/`defaultHeight` constrain sizing; the layout reflows columns from 1 (≤460px) to 4 (≥1000px) wide.

## Provider contract

The dispatcher emits the same normalized schema consumed by the dashboard:

```text
provider
source
usage.identity.providerID / accountEmail / loginMethod
usage.primary / secondary / tertiary
  usedPercent
  windowMinutes
  resetsAt
  resetDescription
  displayValue (optional)
usage.updatedAt
credits.remaining
```

Errors return `{ "provider", "source", "error": { "code", "kind", "message" } }`.

## Resilience

- Overall collection timeout: 45 seconds (request-id guarded so a killed process can't clobber fresh state).
- Provider failures are data, not dispatcher failures.
- Temporary files live in one per-run directory and are removed on exit.
- Informational providers return a valid `usage` object with zero percent.
- The dashboard marks data stale after two refresh intervals.
- Process command arrays are snapshotted before execution to avoid reactive mutation.

## Settings keys

| Key | Default | Purpose |
| --- | --- | --- |
| `providerSelection` | `codex,claude,copilot` | Comma-separated provider IDs. |
| `refreshInterval` | `120000` | Poll interval in milliseconds. |
| `showErrorProviders` | `true` | Keep provider failures visible. |
| `densityMode` | `comfortable` | Comfortable or compact row layout. |
| `languageOverride` | `auto` | Plugin locale override. |
| `backgroundOpacity` | `92` | Desktop panel opacity (0–100). |
| `showHeader` | `true` | Control bar visibility. |
| `pinnedProviders` | empty | Comma-separated pinned provider IDs. |
| `quotaNotifications` | `true` | Desktop alert toggle. |
| `notifyThreshold` | `85` | Global notification threshold. |
| `notifyThresholds` | empty | Per-provider `id:percent` overrides. |
| `notifyCooldownMinutes` | `0` | 0 = once per quota window. |
| `historyRetention` | `2000` | Snapshots kept per trim. |

Legacy settings unknown to the current code are ignored.

## Validation

```bash
bash -n providers/get-*
shellcheck providers/get-*
qmllint AiControlCenterWidget.qml AiControlCenterSettings.qml AiControlCenterI18n.qml
./providers/get-provider-health "codex,claude,copilot" | jq .
./providers/get-provider-usage "codex,claude,copilot" ./providers/get-copilot-usage | jq .
```
