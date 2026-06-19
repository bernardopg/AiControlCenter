# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A self-contained **DankMaterialShell (DMS) desktop-layer plugin** (Quickshell/QML + bash adapters) that renders a dense panel of AI-provider quotas, telemetry, and health on the workspace. No build step — it is interpreted QML plus executable shell scripts. Plugin id is **`aiControlCenter`** (camelCase, from `plugin.json` `id`); the folder is `AiControlCenter`. It is the desktop sibling of the DankBar plugin `aiOverviewControl` and a faithful port of its data pipeline with a rewritten desktop UI.

## Commands

Mirror CI (`.github/workflows/ci.yml`) before pushing — there are no unit tests, validation IS the test suite:

```bash
# QML lint (the three QML files)
qmllint AiControlCenterWidget.qml AiControlCenterSettings.qml AiControlCenterI18n.qml
# expect only unresolved-import warnings for DMS types; treat any *error* as fatal

# Shell adapters: syntax + lint + must stay executable
bash -n providers/get-* providers/send-quota-alert
shellcheck providers/get-* providers/send-quota-alert

# Manifest + i18n
jq --exit-status . plugin.json
for f in i18n/*.json; do jq --exit-status . "$f" >/dev/null; done
# i18n key parity: every locale must have exactly en.json's key set (CI fails on missing/extra)
```

Run a single provider end-to-end (this is how you "test" an adapter):

```bash
./providers/get-provider-usage "claude" ./providers/get-copilot-usage | jq .   # full dispatcher
./providers/get-claude-usage | jq .                                            # one adapter direct
./providers/get-provider-health "codex,claude,copilot" | jq .                  # prerequisite probe
```

Apply QML edits live (no shell restart, state mostly preserved):

```bash
qs -p /home/bitter/.config/quickshell/dms ipc call plugins reload aiControlCenter
# success line: PLUGIN_RELOAD_SUCCESS: aiControlCenter ; list with: ... ipc call plugins list
```

The desktop widget cannot be screenshotted from here — rely on the user to paste renders to verify visual changes. After editing a provider script restore exec bits if needed: `chmod +x providers/get-*`.

## Architecture

**Two-layer split: QML renders, bash measures.** The QML never normalizes provider data — it shells out and assigns the JSON verbatim.

- `AiControlCenterWidget.qml` (the bulk) — `DesktopPluginComponent`. Resolves its own plugin dir (`PluginService.getPluginPath` / QML-URL fallback → `_pluginDir`), runs adapters via Quickshell `Process`/`execDetached`, and renders. Inline `component` definitions (`ProviderCard`, `MetricTile`, `SectionHeader`, `Sparkline`, telemetry panels) live at the bottom of the file.
- `AiControlCenterSettings.qml` — provider selection, health UI, appearance; persists through DMS.
- `AiControlCenterI18n.qml` — `singleton` (see `qmldir`) loading `i18n/<locale>.json`; the widget's `t(key, fallback, params)` interpolates `{param}` placeholders. **`i18n/en.json` is the source of truth for keys**; all other locales must match it exactly (CI enforces parity).

**Data pipeline (runtime flow):**
1. Binary-detect probe checks the dispatcher is executable and `bash`/`jq`/`curl` exist; failure surfaces a helper-missing message, not a crash.
2. `providers/get-provider-usage <provider-csv> <copilot-helper>` is the dispatcher: one adapter per provider, each result validated with `jq`, flattened into one JSON array, history written (`AIOC_HISTORY_MAX` env).
3. QML assigns that array to `providers`, isolates per-provider errors, tracks stale timestamps, renders rows. **One adapter's timeout/bad-credential never hides healthy providers.**
4. Claude detail analytics and 9Router analytics run in **separate `Process`es** so their failure can't block the main fetch.

**Adapter contract:** every `providers/get-*-usage` is a standalone bash+jq script emitting canonical JSON (usage object, or `{provider,source,error:{code,kind,message}}` on failure — see `json_error` in the dispatcher). `get-provider-wrapper` is a thin single-provider entry that `exec`s the dispatcher. Adding a provider = new `get-<id>-usage` script wired into the dispatcher + matching i18n keys.

**Desktop lifecycle:** rendered on the wlr-layer-shell desktop layer; **fetching pauses when the widget isn't visible** (other monitor / hidden / zero size) and resumes on return — unlike the always-polling DankBar sibling. Process command arrays are snapshotted before execution to avoid reactive mutation mid-run.

## Conventions & gotchas

- **`Layout.leftMargin`/`Layout.rightMargin` are silently ignored** when set on a `RowLayout`/`ColumnLayout` whose direct parent is a `Column`/`Item` positioner, or that uses `anchors.fill`. Qt only honors Layout attached props inside a Layout parent. Use `anchors.*Margin` for anchored rows; wrap positioner-child rows in an `Item` with an anchored inner `RowLayout`.
- **Content is capped to a centered block** (`maxContentWidth` 820 → `contentWidth`): the `shell` Column is centered and clamped while `surface` fills the whole frame, so an over-stretched desktop frame stays a tidy panel. Column-count decisions derive from `contentWidth`, not `widgetWidth`.
- **Frame height is host-driven** (`DesktopPluginWrapper` reads the user's saved resize). The plugin cannot auto-shrink to content; a tall empty area means the user dragged the frame large.
- Coverage is honest by design: report measured data only when a read-only source exists, otherwise label Authentication/Informational. No dashboard scraping, no fabricated percentages (see README "Coverage model" and `docs/providers.md`).
- DMS theme tokens come from `~/.config/quickshell/dms/Common/Theme.qml` (`withAlpha(c,a) = Qt.rgba(c.r,c.g,c.b,a)`) and `StockThemes.js`. Settings keys + defaults table: `docs/architecture.md`. Per-plugin persisted settings: `~/.config/DankMaterialShell/plugin_settings.json`.

## Git

Do not add `Co-Authored-By` trailers. Conventional Commits (`fix(widget): …`, `feat: …`). `requires_dms: >=1.2.0`; `plugin.json` `version` must stay semver (CI checks).
