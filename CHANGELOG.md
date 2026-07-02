# Changelog

All notable changes to AiControlCenter are documented here.
This project adheres to [Semantic Versioning](https://semver.org/).

## [1.2.0] — 2026-07-02

### Added
- **Antigravity: multiple accounts / IDEs, side by side.** Each Antigravity install keeps its own `state.vscdb` under a distinct config dir, so two IDEs or two Google accounts are now discovered independently, refreshed separately, deduped by email, and rendered as one block per account in the expanded card (install label, account email, per-model quota bars, and the pool description) — an unused account and a maxed-out one sit next to each other. The compact card mirrors the most-constrained account. Quota now comes from `v1internal:retrieveUserQuotaSummary`, the exact endpoint the IDE statusline renders (per-week + per-5-hour pools, human "Quota resets in …" strings), replacing `fetchAvailableModels`. Settings copy updated; refresh-token recovery handles both the current `antigravityUnifiedStateSync.oauthToken` and the older `jetskiStateSync.agentManagerInitState` layouts.
- **Antigravity: real per-model quota (promoted from Informational to Quota).** The adapter now recovers the long-lived OAuth refresh token from the signed-in IDE state (`~/.config/Antigravity IDE/…` `antigravityUnifiedStateSync.oauthToken`, with legacy path and desktop-keyring fallbacks), mints a fresh access token via Google's public token endpoint (Cloud Code client credentials from the IDE bundle), and reads per-model quota (`remainingFraction` + `resetTime`) from `cloudcode-pa.googleapis.com` — the same read-only backend the IDE and `gemini-cli` use. Families (Claude Opus/Sonnet, Gemini 3.x, GPT-OSS) map to the card's three windows; the account label is the email from the refreshed `id_token`. Settings entry is now `telemetry`; the health probe checks both state-DB paths. Secrets never touch the command line, stdout, or a temp file. Requires `sqlite3`. (Replaces the earlier informational-only stub.)
- **Claude: model-scoped weekly limits (Claude 5 rollout).** `get-claude-usage` now parses the canonical `limits[]` array from the OAuth usage endpoint (`session`, `weekly_all`, `weekly_scoped`) and surfaces the per-model weekly window (e.g. the weekly Fable allowance) as the card's tertiary window and as a dedicated metric tile, with fallback to the legacy flat `five_hour`/`seven_day` objects. Extra-usage credit state (`monthly_limit`, `used_credits`, currency, utilization) is exported too.
- **Copilot: plan-aware account label.** The adapter decodes `access_type_sku` (e.g. `free_educational_quota` → "Education") and `copilot_plan`, showing "login · Plan" on the card, and labels the primary window "Premium requests · AI credits" on accounts migrated to GitHub's usage-based billing (`token_based_billing`, effective 2026-06-01).

### Fixed
- **Copilot: unlimited windows no longer render as "0 / 0 remaining".** Ported the AiOverviewControl handling: `unlimited: true` snapshots (chat/completions on most plans) are suppressed instead of shown as exhausted, `has_quota: false` maps to 100% used, overage counts are appended, and the reset date now comes from the top-level `quota_reset_date_utc`.
- **Z.ai: real subscription quota instead of an auth-only note.** `fetch_zai_native` now queries `GET /api/monitor/usage/quota/limit` (zero tokens) and renders the GLM Coding Plan windows — 5-hour, weekly, monthly MCP tool pool (labelled "MCP" with call counts, e.g. "6 / 100") and total-token allotment — sorted most-critical-first, with the detected plan tier ("GLM Coding Lite/Pro/Max") as the account label and an auth-only `/models` fallback.

## [1.1.0] — 2026-06-19

### Fixed
- Horizontal padding restored across the panel: `Layout.leftMargin`/`Layout.rightMargin` were no-ops on `RowLayout`s parented to a positioner or using `anchors.fill`, leaving the title, search, footer, card rows and section headers jammed against the border and misaligned with their inset grids.
- Daily token chart no longer renders as floating slab-wide blocks: added a per-day baseline and minimum bar height, raised bar contrast, capped bar width, and constrained the chart to a compact centered block.

### Changed
- Over-stretched desktop frames now stay a tidy, centered panel: content is capped to a maximum width (`maxContentWidth`) while the surface still fills the frame; column counts derive from the capped content width instead of the raw frame width.
- Default panel opacity raised 72 → 92 for legibility over bright wallpapers.

### Added
- `CLAUDE.md` with build/validation commands, runtime architecture, the provider-adapter JSON contract, and layout gotchas.

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
