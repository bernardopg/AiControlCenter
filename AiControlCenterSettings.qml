import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "aiControlCenter"

    readonly property string i18nLocale: AiControlCenterI18n.normalizedLocale
    property var selectedIds: normalizeProviderSelection(loadValue("providerSelection", "codex,claude,copilot"))
    property var pinnedIds: normalizeCsvList(loadValue("pinnedProviders", ""))

    function t(key, fallback, params) {
        root.i18nLocale
        return AiControlCenterI18n.tr(key, fallback, params)
    }

    function normalizeCsvList(value) {
        const parts = String(value || "").split(",")
        const result = []
        for (let i = 0; i < parts.length; i++) {
            const id = parts[i].trim().toLowerCase()
            if (id.length > 0 && result.indexOf(id) < 0) result.push(id)
        }
        return result
    }

    function normalizeProviderSelection(value) {
        const parts = String(value || "").split(",")
        const result = []
        for (let i = 0; i < parts.length; i++) {
            const id = parts[i].trim().toLowerCase()
            if (id.length > 0 && result.indexOf(id) < 0) result.push(id)
        }
        return result.length > 0 ? result : ["codex"]
    }

    function isSelected(id) { return selectedIds.indexOf(id) >= 0 }
    function isPinned(id) { return pinnedIds.indexOf(id) >= 0 }

    function toggleProvider(id) {
        const result = selectedIds.slice()
        const index = result.indexOf(id)
        if (index >= 0 && result.length > 1) result.splice(index, 1)
        else if (index < 0) result.push(id)
        selectedIds = result
        saveValue("providerSelection", result.join(","))
        runHealth()
    }

    function togglePinned(id) {
        const result = pinnedIds.slice()
        const index = result.indexOf(id)
        if (index >= 0) result.splice(index, 1)
        else result.push(id)
        pinnedIds = result
        saveValue("pinnedProviders", result.join(","))
    }

    property var providerHealth: ({})
    property string healthBuffer: ""
    property string healthScript: ""

    readonly property int readyCount: {
        let n = 0
        for (let i = 0; i < selectedIds.length; i++) {
            const health = providerHealth[selectedIds[i]]
            if (health && health.status === "ready") n++
        }
        return n
    }
    readonly property int missingCount: {
        let n = 0
        for (let i = 0; i < selectedIds.length; i++) {
            const health = providerHealth[selectedIds[i]]
            if (health && health.status === "missing") n++
        }
        return n
    }

    readonly property var allProviders: [
        { id:"codex", name:"Codex", icon:"data_object", mode:"telemetry", requirement:"codex CLI", envVar:"", note:"Official app-server rate limits" },
        { id:"claude", name:"Claude", icon:"psychology", mode:"telemetry", requirement:"claude CLI or ~/.claude", envVar:"", note:"Local analytics and authenticated usage" },
        { id:"copilot", name:"Copilot", icon:"hub", mode:"telemetry", requirement:"gh CLI or GitHub token", envVar:"COPILOT_GITHUB_TOKEN", note:"Authenticated Copilot quota from the GitHub session" },
        { id:"gemini", name:"Gemini", icon:"auto_awesome", mode:"telemetry", requirement:"gemini CLI or API key", envVar:"GEMINI_API_KEY", note:"Authentication status; quota remains in AI Studio" },
        { id:"9router", name:"9Router", icon:"share", mode:"telemetry", requirement:"local 9Router database", envVar:"", note:"Local requests, tokens and cost" },
        { id:"openrouter", name:"OpenRouter", icon:"route", mode:"telemetry", requirement:"API key or 9Router data", envVar:"OPENROUTER_API_KEY", note:"Official key usage and limits" },
        { id:"deepseek", name:"DeepSeek", icon:"tsunami", mode:"telemetry", requirement:"API key", envVar:"DEEPSEEK_API_KEY", note:"Official account balance" },
        { id:"kimi", name:"Kimi", icon:"dark_mode", mode:"telemetry", requirement:"API key", envVar:"MOONSHOT_API_KEY", note:"Official account balance (USD/CNY)" },
        { id:"minimax", name:"MiniMax", icon:"grid_view", mode:"telemetry", requirement:"API key", envVar:"MINIMAX_API_KEY", note:"Official models API authentication check" },
        { id:"glm", name:"GLM", icon:"bubble_chart", mode:"telemetry", requirement:"API key", envVar:"GLM_API_KEY", note:"China (Zhipu) models API authentication check" },
        { id:"zai", name:"Z.ai", icon:"bubble_chart", mode:"telemetry", requirement:"API key", envVar:"ZAI_API_KEY", note:"Official /models auth check" },
        { id:"mistral", name:"Mistral", icon:"air", mode:"telemetry", requirement:"API key", envVar:"MISTRAL_API_KEY", note:"Official models API authentication check" },
        { id:"qwen", name:"Qwen", icon:"cloud", mode:"telemetry", requirement:"API key", envVar:"DASHSCOPE_API_KEY", note:"DashScope models API authentication check" },
        { id:"nvidia", name:"NVIDIA NIM", icon:"memory", mode:"telemetry", requirement:"API key", envVar:"NVIDIA_API_KEY", note:"Official models API authentication check" },
        { id:"cloudflare", name:"Cloudflare AI", icon:"shield", mode:"telemetry", requirement:"API token", envVar:"CLOUDFLARE_AI_TOKEN", note:"Token verify + Workers AI analytics" },
        { id:"vertexai", name:"Vertex AI", icon:"hexagon", mode:"telemetry", requirement:"gcloud CLI", envVar:"GOOGLE_CLOUD_PROJECT", note:"Official gcloud authentication status" },
        { id:"byteplus", name:"BytePlus Ark", icon:"bolt", mode:"telemetry", requirement:"API key", envVar:"BYTEPLUS_API_KEY", note:"Official models API authentication check" },
        { id:"ollama", name:"Ollama", icon:"dns", mode:"telemetry", requirement:"local Ollama server", envVar:"OLLAMA_HOST", note:"Official local tags and running-model APIs" },
        { id:"together", name:"Together AI", icon:"join_inner", mode:"telemetry", requirement:"API key", envVar:"TOGETHER_API_KEY", note:"Official credit balance" },
        { id:"groq", name:"Groq", icon:"fast_forward", mode:"telemetry", requirement:"API key", envVar:"GROQ_API_KEY", note:"Official models API authentication check" },
        { id:"cohere", name:"Cohere", icon:"waves", mode:"telemetry", requirement:"API key", envVar:"COHERE_API_KEY", note:"Official models API authentication check" },
        { id:"replicate", name:"Replicate", icon:"content_copy", mode:"telemetry", requirement:"API token", envVar:"REPLICATE_API_TOKEN", note:"Official account API authentication check" },
        { id:"fireworks", name:"Fireworks AI", icon:"local_fire_department", mode:"telemetry", requirement:"API key", envVar:"FIREWORKS_API_KEY", note:"Official inference models authentication check" },
        { id:"xai", name:"xAI (Grok)", icon:"bolt", mode:"telemetry", requirement:"API key", envVar:"XAI_API_KEY", note:"Official /v1/api-key authentication check" },
        { id:"kilo", name:"Kilo", icon:"speed", mode:"telemetry", requirement:"API key", envVar:"KILO_API_KEY", note:"Gateway models API authentication check" },
        { id:"ai21", name:"AI21", icon:"looks_21", mode:"telemetry", requirement:"API key", envVar:"AI21_API_KEY", note:"Configured status; no documented read-only usage API" },
        { id:"perplexity", name:"Perplexity", icon:"travel_explore", mode:"informational", requirement:"none", envVar:"", note:"No public read-only quota API" },
        { id:"cursor", name:"Cursor", icon:"ads_click", mode:"informational", requirement:"none", envVar:"", note:"No public read-only quota API" },
        { id:"cline", name:"Cline", icon:"terminal", mode:"informational", requirement:"none", envVar:"", note:"No public read-only quota API" },
        { id:"opencode", name:"OpenCode", icon:"code", mode:"informational", requirement:"none", envVar:"", note:"Usage belongs to configured upstream providers" },
        { id:"kiro", name:"Kiro", icon:"tune", mode:"informational", requirement:"none", envVar:"", note:"Subscription-only IDE; no public API" },
        { id:"warp", name:"Warp", icon:"rocket_launch", mode:"informational", requirement:"none", envVar:"", note:"No public read-only quota API" },
        { id:"amp", name:"Amp", icon:"electric_bolt", mode:"informational", requirement:"none", envVar:"", note:"No public read-only quota API" }
    ]

    readonly property var telemetryProviders: allProviders.filter(function(p) { return p.mode === "telemetry" })
    readonly property var informationalProviders: allProviders.filter(function(p) { return p.mode === "informational" })

    function healthFor(id) {
        return providerHealth[id] || { status: "unknown", detail: t("settings.health.pending", "Not checked") }
    }

    function healthColor(id) {
        const s = healthFor(id).status
        if (s === "ready") return Theme.success
        if (s === "missing") return Theme.warning
        return Theme.outlineVariant
    }

    function runHealth() {
        if (!healthScript || healthProcess.running) return
        healthBuffer = ""
        healthProcess.command = ["bash", healthScript, selectedIds.join(",")]
        healthProcess.running = true
    }

    Component.onCompleted: {
        const url = Qt.resolvedUrl("providers/get-provider-health").toString()
        healthScript = url.startsWith("file://") ? url.substring(7) : url
        runHealth()
    }

    Process {
        id: healthProcess
        stdout: SplitParser { splitMarker: ""; onRead: data => root.healthBuffer += data }
        onExited: code => {
            if (code !== 0 || root.healthBuffer.length === 0) return
            try {
                const items = JSON.parse(root.healthBuffer)
                const map = {}
                for (let i = 0; i < items.length; i++) map[items[i].provider] = items[i]
                root.providerHealth = map
            } catch (error) {
                root.providerHealth = {}
            }
        }
    }

    // ===================== UI =====================
    StyledText {
        width: parent.width
        text: t("app.title", "AI Control Center")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }
    StyledText {
        width: parent.width
        text: t("app.subtitle", "Workspace AI control surface")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // ---------- Interface ----------
    SectionLabel { text: t("settings.section.interface", "Interface") }
    SelectionSetting {
        settingKey: "languageOverride"
        label: t("settings.language.label", "Language")
        description: t("settings.language.description", "UI language for this plugin. Auto follows system locale.")
        options: [
            { label: "Auto", value: "auto" },
            { label: "English", value: "en_US" },
            { label: "Português (BR)", value: "pt_BR" },
            { label: "简体中文", value: "zh_CN" },
            { label: "Español", value: "es_ES" },
            { label: "Deutsch", value: "de_DE" }
        ]
        defaultValue: "auto"
    }
    SelectionSetting {
        settingKey: "densityMode"
        label: t("settings.density.label", "Dashboard density")
        description: t("settings.density.description", "Comfortable keeps full previews. Compact reduces card height and visual detail.")
        options: [
            { label: t("panel.comfortable", "Comfortable"), value: "comfortable" },
            { label: t("panel.compact", "Compact"), value: "compact" }
        ]
        defaultValue: "comfortable"
    }
    SelectionSetting {
        settingKey: "refreshInterval"
        label: t("settings.refresh_interval", "Refresh interval")
        description: t("settings.refresh_description", "How often the plugin queries selected local adapters and provider APIs.")
        options: [
            { label: "1 min", value: "60000" },
            { label: "2 min", value: "120000" },
            { label: "5 min", value: "300000" },
            { label: "15 min", value: "900000" },
            { label: "30 min", value: "1800000" }
        ]
        defaultValue: "120000"
    }
    ToggleSetting {
        settingKey: "showErrorProviders"
        label: t("settings.show_errors", "Show providers with errors")
        description: t("settings.show_errors_desc", "Keep authentication and configuration failures visible in the dashboard.")
        defaultValue: true
    }
    ToggleSetting {
        settingKey: "showClaudeProjects"
        label: t("settings.show_projects", "Show Claude projects")
        description: t("settings.show_projects_desc", "List the week's top projects inside the Claude card.")
        defaultValue: true
    }

    // ---------- Appearance (desktop) ----------
    SectionLabel { text: t("settings.appearance", "Appearance") }
    SliderSetting {
        settingKey: "backgroundOpacity"
        label: t("settings.background_opacity", "Panel opacity")
        description: t("settings.background_opacity_desc", "Background transparency of the desktop panel over the wallpaper.")
        defaultValue: 72
        minimum: 0
        maximum: 100
        unit: "%"
    }
    ToggleSetting {
        settingKey: "showHeader"
        label: t("settings.show_header", "Show control bar")
        description: t("settings.show_header_desc", "Top bar with search, status filters and refresh control.")
        defaultValue: true
    }

    // ---------- Providers ----------
    SectionLabel { text: t("card.providers", "Providers") }
    StyledText {
        width: parent.width
        text: `${readyCount} ${t("settings.health.ready_count", "{count} ready", { count: readyCount })} · ${missingCount} ${t("settings.health.missing_count", "{count} missing", { count: missingCount })}`
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        visible: selectedIds.length > 0
    }
    StyledText {
        width: parent.width
        text: t("settings.telemetry_providers_desc", "Adapters backed by official CLIs, documented APIs, or local usage stores.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: telemetryProviders
        delegate: ProviderRow {
            providerId: modelData.id
            providerName: modelData.name
            providerIcon: modelData.icon
            providerNote: modelData.note
            envVar: modelData.envVar
            selected: isSelected(modelData.id)
            pinned: isPinned(modelData.id)
            healthStatus: healthFor(modelData.id).status
            healthDetail: healthFor(modelData.id).detail
            healthColor: healthColor(modelData.id)
            onToggleSelected: toggleProvider(modelData.id)
            onTogglePinned: togglePinned(modelData.id)
        }
    }
    StyledText {
        width: parent.width
        text: t("settings.informational_providers", "Informational providers")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
        topPadding: Theme.spacingM
    }
    StyledText {
        width: parent.width
        text: t("settings.informational_providers_desc", "These providers expose no public read-only quota API. Their cards point to the official usage surface.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: informationalProviders
        delegate: ProviderRow {
            providerId: modelData.id
            providerName: modelData.name
            providerIcon: modelData.icon
            providerNote: modelData.note
            envVar: modelData.envVar
            selected: isSelected(modelData.id)
            pinned: isPinned(modelData.id)
            healthStatus: "informational"
            healthDetail: ""
            healthColor: Theme.outlineVariant
            onToggleSelected: toggleProvider(modelData.id)
            onTogglePinned: togglePinned(modelData.id)
        }
    }

    // ---------- Notifications ----------
    SectionLabel { text: t("settings.notify.label", "Quota notifications") }
    ToggleSetting {
        settingKey: "quotaNotifications"
        label: t("settings.notify.label", "Quota notifications")
        description: t("settings.notify.description", "Send a desktop notification when a provider crosses the threshold.")
        defaultValue: true
    }
    SelectionSetting {
        settingKey: "notifyThreshold"
        label: t("settings.notify.threshold", "Notification threshold")
        description: t("settings.notify.threshold_desc", "Usage percent that triggers a notification.")
        options: [
            { label: "75%", value: "75" },
            { label: "85%", value: "85" },
            { label: "95%", value: "95" }
        ]
        defaultValue: "85"
    }
    StringSetting {
        settingKey: "notifyThresholds"
        label: t("settings.notify.overrides", "Per-provider threshold overrides")
        description: t("settings.notify.overrides_desc", "Comma-separated provider:percent pairs that beat the global threshold.")
        placeholder: "claude:90,codex:75"
        defaultValue: ""
    }
    SelectionSetting {
        settingKey: "notifyCooldownMinutes"
        label: t("settings.notify.cooldown", "Re-alert interval")
        description: t("settings.notify.cooldown_desc", "0 alerts once per quota window; other values repeat the alert after that many minutes while usage stays above the threshold.")
        options: [
            { label: t("status.reset", "reset") + " (0)", value: "0" },
            { label: "15 min", value: "15" },
            { label: "30 min", value: "30" },
            { label: "60 min", value: "60" }
        ]
        defaultValue: "0"
    }

    // ---------- History ----------
    SectionLabel { text: t("settings.history_retention", "Usage history retention") }
    SelectionSetting {
        settingKey: "historyRetention"
        label: t("settings.history_retention", "Usage history retention")
        description: t("settings.history_retention_desc", "Snapshots kept per trim of the local usage history (sparklines and trends).")
        options: [
            { label: "500", value: "500" },
            { label: "2,000", value: "2000" },
            { label: "10,000", value: "10000" }
        ]
        defaultValue: "2000"
    }

    // ---------- Diagnostics ----------
    SectionLabel { text: t("settings.diagnostics", "Diagnostics and tests") }
    StyledText {
        width: parent.width
        text: t("settings.diagnostics_desc", "Commands for validating the plugin-managed pipeline.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: [
            { label: t("settings.test_deps", "Check core dependencies"), cmd: "command -v bash jq curl" },
            { label: t("settings.test_health", "Check provider prerequisites"), cmd: "./providers/get-provider-health \"" + selectedIds.join(",") + "\" | jq ." },
            { label: t("settings.test_backend", "Test selected providers"), cmd: "./providers/get-provider-usage \"" + selectedIds.join(",") + "\" ./providers/get-copilot-usage | jq ." },
            { label: t("settings.test_qml", "Validate QML"), cmd: "qmllint AiControlCenter*.qml" }
        ]
        delegate: DiagnosticRow { labelText: modelData.label; command: modelData.cmd }
    }

    // ===================== Inline components =====================
    component SectionLabel : StyledText {
        property string text: ""
        width: parent.width
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingL
        bottomPadding: Theme.spacingXS
    }

    component ProviderRow : Rectangle {
        id: prow
        property string providerId: ""
        property string providerName: ""
        property string providerIcon: ""
        property string providerNote: ""
        property string envVar: ""
        property bool selected: false
        property bool pinned: false
        property string healthStatus: "unknown"
        property string healthDetail: ""
        property color healthColor: Theme.outlineVariant
        signal toggleSelected()
        signal togglePinned()
        width: parent.width
        height: 52
        radius: Theme.cornerRadius
        color: selected ? Theme.withAlpha(Theme.primary, 0.08) : Theme.surfaceContainerHigh
        border.width: 1
        border.color: selected ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.outlineVariant, 0.4)
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: Theme.spacingS
            Rectangle {
                implicitWidth: 34; implicitHeight: 34; radius: 8
                Layout.alignment: Qt.AlignVCenter
                color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.7)
                DankIcon { anchors.centerIn: parent; name: prow.providerIcon; size: 18; color: Theme.surfaceText }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1
                RowLayout {
                    spacing: Theme.spacingS
                    StyledText { text: prow.providerName; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.DemiBold; color: Theme.surfaceText }
                    StyledText { text: prow.envVar; visible: prow.envVar.length > 0; font.pixelSize: Theme.fontSizeSmall - 3; font.family: monoFontFamily; color: Theme.surfaceVariantText; Layout.leftMargin: 2 }
                    Rectangle { // health dot
                        implicitWidth: 8; implicitHeight: 8; radius: 4
                        Layout.alignment: Qt.AlignVCenter
                        visible: prow.healthStatus !== "informational" && prow.healthStatus !== "unknown"
                        color: prow.healthColor
                    }
                }
                StyledText { text: prow.providerNote; font.pixelSize: Theme.fontSizeSmall - 2; color: Theme.surfaceVariantText; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            DankIcon { // pin
                name: "push_pin"; size: 16
                Layout.alignment: Qt.AlignVCenter
                color: prow.pinned ? Theme.primary : (pinArea.containsMouse ? Theme.surfaceText : Theme.outlineVariant)
                opacity: prow.pinned ? 1 : 0.5
                MouseArea { id: pinArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: prow.togglePinned() }
            }
            Rectangle { // toggle
                implicitWidth: 40; implicitHeight: 22; radius: 11
                Layout.alignment: Qt.AlignVCenter
                color: prow.selected ? Theme.primary : Theme.withAlpha(Theme.outlineVariant, 0.4)
                Rectangle { x: prow.selected ? parent.width - width - 3 : 3; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 8; color: Theme.surfaceText; Behavior on x { NumberAnimation { duration: 140 } } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: prow.toggleSelected() }
            }
        }
        readonly property string monoFontFamily: Theme.monoFontFamily || "monospace"
    }

    component DiagnosticRow : Rectangle {
        property string labelText: ""
        property string command: ""
        width: parent.width
        height: diagCol.height + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.withAlpha(Theme.outlineVariant, 0.4)
        ColumnLayout {
            id: diagCol
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Theme.spacingS
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS
                StyledText { text: labelText; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; Layout.alignment: Qt.AlignVCenter }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: copyLabel.implicitWidth + 16; implicitHeight: 22; radius: 6
                    Layout.alignment: Qt.AlignVCenter
                    color: copyArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.18) : Theme.withAlpha(Theme.outlineVariant, 0.3)
                    StyledText { id: copyLabel; anchors.centerIn: parent; text: root.t("settings.copy_command", "Copy command"); font.pixelSize: Theme.fontSizeSmall - 2; color: copyArea.containsMouse ? Theme.primary : Theme.surfaceVariantText }
                    MouseArea { id: copyArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["sh", "-c", "echo -n '" + command + "' | wl-copy"]) }
                }
            }
            StyledText { text: command; font.pixelSize: Theme.fontSizeSmall - 3; font.family: monoFontFamily; color: Theme.surfaceVariantText; wrapMode: Text.NoWrap; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        readonly property string monoFontFamily: Theme.monoFontFamily || "monospace"
    }
}
