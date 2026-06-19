# Changelog

All notable changes to AiControlCenter are documented here.
This project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-06-19

### Added
- Initial release as a **desktop-layer (workspace)** widget for DankMaterialShell (`type: "desktop"`, capability `desktop-widget`).
- Technical-minimalist UI: dense provider rows, monospace numerics, status-only accents, responsive 1–4 column reflow based on widget width.
- Hero strip with global usage bar, notification-threshold tick, and active/issues/critical stat badges.
- Expandable provider cards: sparkline (history), window rows (label · usage · reset), identity, credits, console deep-links, per-provider retry on error.
- Claude Code telemetry panel: today/week/month cost & tokens, projected month, 5h/7d utilization, extra-usage flag, daily token bars, top models and top projects.
- 9Router telemetry panel: today/week/month cost & requests, week tokens.
- Provider manager with health checks, pinning, status filters (All/Live/Issues), and name search.
- Quota notifications with global threshold, per-provider overrides, and re-alert cooldown.
- Local usage history with configurable retention → sparklines and trend arrows.
- 33 provider adapters (faithful port of the AiOverviewControl pipeline) with isolated cache at `~/.cache/AiControlCenter`.
- 5 UI languages: English, Português (BR), 简体中文, Español, Deutsch.
- Desktop appearance controls: panel opacity slider and control-bar visibility toggle.
- CI: manifest + semver, i18n syntax & key parity, bash syntax, shellcheck, script permissions, QML lint.

### Notes
- Shares the same provider-adapter contract as AiOverviewControl but runs as an independent plugin with its own cache, state, and Codex client identity.
