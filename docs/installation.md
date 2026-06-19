# Installation

## Install from a checkout

```bash
mkdir -p ~/.config/DankMaterialShell/plugins/AiControlCenter
cp -a AiControlCenterWidget.qml AiControlCenterSettings.qml \
  AiControlCenterI18n.qml plugin.json qmldir providers README.md CHANGELOG.md LICENSE docs i18n \
  ~/.config/DankMaterialShell/plugins/AiControlCenter/
chmod +x ~/.config/DankMaterialShell/plugins/AiControlCenter/providers/get-*
dms restart
```

Or clone directly:

```bash
git clone https://github.com/bernardopg/AiControlCenter.git \
  ~/.config/DankMaterialShell/plugins/AiControlCenter
chmod +x ~/.config/DankMaterialShell/plugins/AiControlCenter/providers/get-*
dms restart
```

## Core dependencies

```bash
command -v bash jq curl
```

Only enabled providers need their provider-specific CLI or credentials.

## Initial authentication (optional, per provider)

```bash
codex login
claude auth status
gh auth login
```

## Enable

1. Open DMS **Settings → Plugins**.
2. Click **Scan for Plugins**.
3. Toggle **AiControlCenter** on.
4. Add the desktop widget and position/resize it on your workspace.
5. Restart if needed: `dms restart`.

## First validation

```bash
cd ~/.config/DankMaterialShell/plugins/AiControlCenter
./providers/get-provider-health "codex,claude,copilot" | jq .
./providers/get-provider-usage "codex,claude,copilot" ./providers/get-copilot-usage | jq .
```

## Upgrade

Replace tracked plugin files, preserve the DMS settings store, restore
executable bits, and restart DMS:

```bash
chmod +x ~/.config/DankMaterialShell/plugins/AiControlCenter/providers/get-*
dms restart
```
