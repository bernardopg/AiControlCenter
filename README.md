<div align="center">

# AiControlCenter

**A workspace AI control surface for DankMaterialShell.**

A self-contained [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) **desktop widget** that renders a dense, technical-minimalist panel of AI quotas, telemetry, and provider health directly on your workspace.

[![CI](https://github.com/bernardopg/AiControlCenter/actions/workflows/ci.yml/badge.svg)](https://github.com/bernardopg/AiControlCenter/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/bernardopg/AiControlCenter)](./LICENSE)
[![Providers](https://img.shields.io/badge/providers-33-7C4DFF)](./docs/providers.md)
[![Languages](https://img.shields.io/badge/UI%20languages-5-00BFA5)](./docs/i18n.md)

[Install](#installation) · [Configuration](./docs/configuration.md) · [Providers](./docs/providers.md) · [Changelog](./CHANGELOG.md)

</div>

---

## What it is

AiControlCenter is the desktop-layer sibling of
[AiOverviewControl](https://github.com/bernardopg/AiOverviewControl). Where the
overview lives as a compact pill in your DankBar, AiControlCenter is a
**persistent panel on your workspace** — draggable, resizable, and always on.
It collects the same 33 AI providers and developer tools **locally and
independently**, normalizes the result, and renders one honest dashboard
without any external aggregation service.

It reports measured data when a supported source exists, and clearly labels
authentication-only or informational providers when it does not. No dashboard
scraping. No fabricated percentages. Ever.

## Highlights

| | |
| --- | --- |
| 🖥️ **Desktop-layer panel** | Lives on the workspace via wlr-layer-shell; free positioning, resize, and multi-monitor with persisted placement. |
| 📊 **33 providers, unified** | Codex, Claude, Copilot, OpenRouter, Gemini, 9Router and 27 more in one dense view. |
| 📈 **Rich telemetry** | Claude token/cost/model/project analytics, 9Router routed-provider telemetry, sparklines and trends. |
| 🔢 **Technical-minimalist UI** | Monospace numerics, status accents only, responsive 1–4 column reflow that adapts to widget width. |
| 🛡️ **Failure isolation** | One timeout or invalid credential never hides healthy providers. |
| 🔔 **Quota notifications** | Desktop alerts with global and per-provider thresholds, de-duplicated per quota window. |
| 🌍 **5 UI languages** | English, Português (BR), 简体中文, Español, and Deutsch. |
| 🔒 **Privacy first** | Local adapters, no paid endpoints just to test keys, secrets never displayed. |

## Requirements

- DankMaterialShell (≥ 1.2.0) running on Quickshell.
- `bash`, `jq`, and `curl`.
- Provider-specific CLIs or credentials only for providers you enable.

## Installation

### Git Checkout

```bash
git clone https://github.com/bernardopg/AiControlCenter.git \
  ~/.config/DankMaterialShell/plugins/AiControlCenter
chmod +x ~/.config/DankMaterialShell/plugins/AiControlCenter/providers/get-*
dms restart
```

Then enable **AiControlCenter** in DMS settings → Plugins, add the desktop
widget, and drag/resize it anywhere on your workspace. Detailed guidance in
[docs/installation.md](./docs/installation.md).

### Release Archive

Download the `.tar.gz` from the
[latest release](https://github.com/bernardopg/AiControlCenter/releases/latest),
extract it as `AiControlCenter` into the DMS plugin directory, restore the
executable bits (`chmod +x providers/get-*`), and restart DMS.

## Coverage model

Provider cards use one of these honest coverage levels: **Quota** (rate-limit
windows), **Balance** (prepaid credits), **Analytics** (consumption counters or
local data), **Authentication** (read-only credential check), and
**Informational** (official links when no read-only API exists). The full
matrix is in [docs/providers.md](./docs/providers.md).

## Configuration

All settings are stored through DMS and survive plugin upgrades. Notable
options: dashboard density, refresh interval, pill selection, per-provider
notification thresholds, usage-history retention, and desktop-specific
**panel opacity** and **control bar** visibility. See
[Configuration](./docs/configuration.md).

## Architecture

```text
AiControlCenterWidget.qml        DesktopPluginComponent — runtime + dashboard
AiControlCenterSettings.qml      Provider selection, health, appearance
AiControlCenterI18n.qml          Locale loading and interpolation
providers/get-provider-usage     Multi-provider dispatcher and history writer
providers/get-provider-health    Local prerequisite checks
providers/get-*-usage            Canonical single-provider entrypoints
```

The data engine is a faithful port of the AiOverviewControl pipeline; the
rendering is rewritten for the larger, persistent desktop canvas. See
[docs/architecture.md](./docs/architecture.md).

## Documentation

| Topic | Link |
| --- | --- |
| Installation | [docs/installation.md](./docs/installation.md) |
| Configuration | [docs/configuration.md](./docs/configuration.md) |
| Provider matrix | [docs/providers.md](./docs/providers.md) |
| Architecture | [docs/architecture.md](./docs/architecture.md) |
| Troubleshooting | [docs/troubleshooting.md](./docs/troubleshooting.md) |
| Changelog | [CHANGELOG.md](./CHANGELOG.md) |

---

<div align="center">

Released under the [MIT License](./LICENSE).

Made for the [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) community.

</div>
