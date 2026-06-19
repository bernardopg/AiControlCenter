import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// AiControlCenter — a workspace (desktop-layer) AI control surface.
// Technical-minimalist: dense rows, monospace numerics, status accents only,
// decoration kept to a minimum. Data engine is a faithful port of the
// AiOverviewControl provider pipeline; all rendering is rewritten for the
// larger, persistent desktop canvas.
DesktopPluginComponent {
    id: root

    // --- Desktop sizing ---
    minWidth: 320
    minHeight: 260

    // --- Appearance (desktop-specific) ---
    property real backgroundOpacity: {
        const v = pluginData.backgroundOpacity
        const n = v === undefined || v === null ? 72 : parseInt(v)
        return Number.isFinite(n) ? Math.max(0, Math.min(100, n)) / 100 : 0.72
    }
    property bool showHeader: pluginData.showHeader === undefined ? true : String(pluginData.showHeader) !== "false"
    property int cornerRadius: Theme.cornerRadius
    property string monoFontFamily: Theme.monoFontFamily || "monospace"

    // --- Data state (ported verbatim from AiOverviewControl) ---
    property var providers: []
    property bool isLoading: false
    property bool hasError: false
    property string errorMessage: ""
    property string lastUpdated: ""
    property real lastUpdatedMs: 0
    property string rawJsonBuffer: ""
    property string rawStderrBuffer: ""
    property bool binaryReady: false
    property int fetchTimeoutMs: 45000
    property bool usageDidTimeout: false
    property int usageRequestId: 0
    property int timedOutRequestId: -1
    property string providerSelection: (pluginData.providerSelection || "codex,claude,copilot").trim()
    property bool showErrorProviders: String(pluginData.showErrorProviders ?? "true") === "true"
    property string densityMode: pluginData.densityMode || "comfortable"
    property string providerFilter: ""
    property string providerStatusFilter: "all"
    property string focusedProviderId: ""
    property bool allExpanded: false
    property var usageHistory: ({})
    property string historyBuffer: ""
    property string retryBuffer: ""
    property string retryingProviderId: ""
    property var notifiedMap: ({})
    property bool notifyEnabled: String(pluginData.quotaNotifications ?? "true") === "true"
    property int notifyThreshold: {
        const parsed = parseInt(pluginData.notifyThreshold || "85")
        return Number.isFinite(parsed) && parsed > 0 && parsed <= 100 ? parsed : 85
    }
    property bool showClaudeProjects: String(pluginData.showClaudeProjects ?? "true") === "true"
    readonly property var notifyThresholdOverrides: {
        const raw = String(pluginData.notifyThresholds || "").trim()
        const map = {}
        if (raw.length === 0) return map
        const pairs = raw.split(",")
        for (let i = 0; i < pairs.length; i++) {
            const kv = pairs[i].split(":")
            if (kv.length !== 2) continue
            const id = kv[0].trim().toLowerCase()
            const value = parseInt(kv[1].trim())
            if (id.length > 0 && Number.isFinite(value) && value > 0 && value <= 100) map[id] = value
        }
        return map
    }
    function thresholdFor(providerId) {
        const override = notifyThresholdOverrides[normalizeProviderId(providerId)]
        return override !== undefined ? override : notifyThreshold
    }
    readonly property int notifyCooldownSecs: {
        const parsed = parseInt(pluginData.notifyCooldownMinutes || "0")
        if (!Number.isFinite(parsed) || parsed <= 0) return 999999999
        return parsed * 60
    }
    property string pinnedProvidersCsv: (pluginData.pinnedProviders || "").trim()
    readonly property var pinnedProviders: {
        const parts = pinnedProvidersCsv.split(",")
        const result = []
        for (let i = 0; i < parts.length; i++) {
            const id = parts[i].trim().toLowerCase()
            if (id.length > 0 && result.indexOf(id) < 0) result.push(id)
        }
        return result
    }
    property string claudeRawBuffer: ""
    property bool claudeStatsError: false
    property string claudeSubscriptionType: ""
    property string claudeRateLimitTier: ""
    property real claudeFiveHourUtil: 0
    property string claudeFiveHourReset: ""
    property real claudeSevenDayUtil: 0
    property string claudeSevenDayReset: ""
    property bool claudeExtraUsageEnabled: false
    property int claudeWeekMessages: 0
    property int claudeWeekSessions: 0
    property real claudeWeekTokens: 0
    property real claudeMonthTokens: 0
    property int claudeAlltimeSessions: 0
    property int claudeAlltimeMessages: 0
    property string claudeFirstSession: ""
    property real claudeTodayCost: 0
    property real claudeWeekCost: 0
    property real claudeMonthCost: 0
    property var claudeDailyTokens: [0, 0, 0, 0, 0, 0, 0]
    property var claudeDailyCosts: [0, 0, 0, 0, 0, 0, 0]
    property var dayLabels: [Qt.locale(root.i18nLocale).dayName(1, Locale.ShortFormat), Qt.locale(root.i18nLocale).dayName(2, Locale.ShortFormat), Qt.locale(root.i18nLocale).dayName(3, Locale.ShortFormat), Qt.locale(root.i18nLocale).dayName(4, Locale.ShortFormat), Qt.locale(root.i18nLocale).dayName(5, Locale.ShortFormat), Qt.locale(root.i18nLocale).dayName(6, Locale.ShortFormat), Qt.locale(root.i18nLocale).dayName(0, Locale.ShortFormat)]
    readonly property int currentWeekdayIndex: (new Date().getDay() + 6) % 7
    readonly property string i18nLocale: AiControlCenterI18n.normalizedLocale

    function t(key, fallback, params) {
        root.i18nLocale
        return AiControlCenterI18n.tr(key, fallback, params)
    }

    property int refreshIntervalMs: {
        const val = pluginData.refreshInterval
        const parsed = val ? parseInt(val) : 120000
        return Number.isFinite(parsed) ? parsed : 120000
    }
    property string _pluginDir: ""
    property string providerUsageScript: _pluginDir + "/providers/get-provider-usage"
    property string claudeUsageScript: _pluginDir + "/providers/get-claude-usage"
    property string copilotUsageScript: _pluginDir + "/providers/get-copilot-usage"
    property string usageHistoryScript: _pluginDir + "/providers/get-usage-history"
    property string notifyAlertScript: _pluginDir + "/providers/send-quota-alert"
    property string nineRouterAnalyticsScript: _pluginDir + "/providers/get-9router-analytics"
    property var nineStats: null
    property string nineStatsBuffer: ""
    readonly property string pluginKey: pluginId || "aiControlCenter"

    readonly property var availableProviderOptions: [
        "codex", "claude", "copilot", "gemini", "9router", "openrouter",
        "deepseek", "kimi", "mistral", "glm", "zai", "minimax", "qwen",
        "nvidia", "cloudflare", "vertexai", "byteplus", "ollama", "together",
        "groq", "cohere", "replicate", "fireworks", "ai21", "xai", "kilo",
        "perplexity", "cursor", "cline", "opencode", "kiro", "warp", "amp"
    ]

    property var usageCommand: ["bash", root.providerUsageScript, root.selectedProviders.join(","), root.copilotUsageScript]
    property string historyRetention: {
        const parsed = parseInt(pluginData.historyRetention || "2000")
        return String(Number.isFinite(parsed) && parsed >= 50 ? parsed : 2000)
    }

    // Visibility / lifecycle (desktop best practice: pause when hidden)
    property var windowRef: null
    function isRunnable() {
        const win = root.windowRef
        const winVisible = win === null ? true : !!win.visible
        return root.visible && winVisible && root.widgetWidth > 0 && root.widgetHeight > 0
    }

    ListModel { id: claudeModelList }
    ListModel { id: claudeProjectList }

    readonly property var selectedProviders: {
        const parts = providerSelection.split(",")
        const result = []
        for (let i = 0; i < parts.length; i++) {
            const value = parts[i].trim().toLowerCase()
            if (value.length > 0 && result.indexOf(value) < 0) result.push(value)
        }
        return result.length > 0 ? result : ["codex"]
    }
    readonly property var successfulProviders: {
        const result = []
        for (let i = 0; i < providers.length; i++) {
            const provider = providers[i]
            if (provider && provider.usage && !provider.error) result.push(provider)
        }
        return result
    }
    readonly property var errorProviders: {
        const result = []
        for (let i = 0; i < providers.length; i++) {
            const provider = providers[i]
            if (provider && provider.error) result.push(provider)
        }
        return result
    }
    readonly property int criticalCount: {
        let n = 0
        for (let i = 0; i < successfulProviders.length; i++) {
            if (providerPercent(successfulProviders[i]) >= 80) n++
        }
        return n
    }
    readonly property var displayProviders: {
        if (showErrorProviders) return providers
        const result = []
        for (let i = 0; i < providers.length; i++) {
            const provider = providers[i]
            if (provider && !provider.error) result.push(provider)
        }
        return result
    }
    readonly property var filteredDisplayProviders: {
        const query = providerFilter.trim().toLowerCase()
        const result = []
        for (let i = 0; i < displayProviders.length; i++) {
            const provider = displayProviders[i]
            if (providerStatusFilter === "live" && (provider.error || !provider.usage)) continue
            if (providerStatusFilter === "issues" && !provider.error) continue
            if (query.length > 0) {
                const haystack = `${providerName(provider.provider)} ${provider.provider} ${providerSourceLabel(provider)}`.toLowerCase()
                if (haystack.indexOf(query) < 0) continue
            }
            result.push(provider)
        }
        result.sort(function(a, b) {
            const aPin = pinnedProviders.indexOf(a.provider) >= 0 ? 0 : 1
            const bPin = pinnedProviders.indexOf(b.provider) >= 0 ? 0 : 1
            if (aPin !== bPin) return aPin - bPin
            const aErr = a.error ? 1 : 0
            const bErr = b.error ? 1 : 0
            if (aErr !== bErr) return aErr - bErr
            return providerPercent(b) - providerPercent(a)
        })
        return result
    }

    readonly property var providerData: {
        for (let i = 0; i < pinnedProviders.length; i++) {
            for (let j = 0; j < successfulProviders.length; j++) {
                if (successfulProviders[j].provider === pinnedProviders[i]) return successfulProviders[j]
            }
        }
        let bestProvider = null
        let bestPercent = -1
        for (let i = 0; i < successfulProviders.length; i++) {
            const provider = successfulProviders[i]
            const percent = Number(provider.usage && provider.usage.primary ? provider.usage.primary.usedPercent || 0 : 0)
            if (percent > bestPercent) { bestPercent = percent; bestProvider = provider }
        }
        return bestProvider || (providers.length > 0 ? providers[0] : null)
    }
    readonly property bool hasProviderData: !!providerData && !!providerData.usage
    readonly property var usageData: hasProviderData ? providerData.usage : null
    readonly property var primaryWindow: usageData ? usageData.primary : null
    readonly property real primaryPercent: primaryWindow ? Number(primaryWindow.usedPercent || 0) : 0
    readonly property color heroAccent: getUsageColor(primaryPercent)

    readonly property string statusTitle: {
        if (isLoading && !hasProviderData) return t("status.syncing", "Syncing usage")
        if (hasError) return t("status.needs_attention", "Needs attention")
        if (!hasProviderData) return t("status.waiting", "Waiting for data")
        return t("status.online", "AI telemetry online")
    }
    readonly property string statusSubtitle: {
        if (isLoading && !hasProviderData) return t("panel.fetching", "Fetching provider telemetry")
        if (hasError) return errorMessage
        if (!hasProviderData) return t("status.no_data_hint", "Authenticate the configured provider CLIs or API keys, then refresh.")
        const resetLabel = primaryWindow ? formatTimeUntil(primaryWindow.resetsAt) : ""
        if (!resetLabel) return t("status.windows_available", "Provider windows are available.")
        return t("status.primary_resets", "Primary window resets in {time}.", { time: resetLabel })
    }
    readonly property bool isDataStale: {
        staleTickMs
        return lastUpdatedMs > 0 && (Date.now() - lastUpdatedMs) > refreshIntervalMs * 2
    }
    readonly property string providerEngineLabel: {
        if (!binaryReady) return "offline"
        return t("status.local_helpers", "local adapters")
    }
    property int staleTickMs: 0

    // --- Helper functions (faithful port) ---
    function normalizeProviderId(providerId) { return String(providerId || "").trim().toLowerCase() }

    function getUsageColor(percent) {
        if (percent >= 80) return Theme.error
        if (percent >= 60) return Theme.warning
        return Theme.success
    }

    function capitalizeFirst(value) {
        if (!value) return ""
        return value.charAt(0).toUpperCase() + value.slice(1)
    }

    function getWindowLabel(windowMinutes) {
        if (!windowMinutes) return ""
        if (windowMinutes <= 300) return t("window.session", "Session")
        if (windowMinutes <= 10080) return t("window.weekly", "Weekly")
        if (windowMinutes <= 43200) return t("window.monthly", "Monthly")
        return `${Math.floor(windowMinutes / 1440)}d`
    }

    function formatTimeUntil(isoDate) {
        if (!isoDate) return ""
        const diff = new Date(isoDate).getTime() - Date.now()
        if (diff <= 0) return t("time.now", "now")
        const mins = Math.floor(diff / 60000)
        if (mins < 60) return `${mins}m`
        const hours = Math.floor(mins / 60)
        if (hours < 24) return `${hours}h ${mins % 60}m`
        const days = Math.floor(hours / 24)
        return `${days}d ${hours % 24}h`
    }

    function formatMinutes(mins) {
        const value = Math.max(0, Math.round(Number(mins) || 0))
        if (value < 60) return `${value}m`
        const hours = Math.floor(value / 60)
        if (hours < 24) return `${hours}h ${value % 60}m`
        return `${Math.floor(hours / 24)}d ${hours % 24}h`
    }

    function formatUsageLine(windowData) {
        if (!windowData) return ""
        if (windowData.displayValue && String(windowData.displayValue).length > 0) return String(windowData.displayValue)
        const percent = Math.round(Number(windowData.usedPercent || 0))
        const reset = formatTimeUntil(windowData.resetsAt)
        return reset.length > 0 ? `${percent}% · ${reset}` : `${percent}%`
    }

    function formatUsageError(exitCode) {
        if (rawStderrBuffer.length > 0) return rawStderrBuffer.trim()
        return t("error.helper_exit", "provider helper exited with code {code}", { code: exitCode })
    }

    function providerName(providerId) {
        const names = {
            codex: "Codex", claude: "Claude", copilot: "Copilot", cursor: "Cursor",
            gemini: "Gemini", openrouter: "OpenRouter", "9router": "9Router",
            deepseek: "DeepSeek", kimi: "Kimi", moonshot: "Kimi", mistral: "Mistral",
            glm: "GLM", zhipu: "GLM", zai: "Z.ai", minimax: "MiniMax", qwen: "Qwen",
            dashscope: "Qwen", alibaba: "Qwen", nvidia: "NVIDIA NIM", nim: "NVIDIA NIM",
            cloudflare: "Cloudflare AI", vertexai: "Vertex AI", vertex: "Vertex AI",
            byteplus: "BytePlus Ark", ark: "BytePlus Ark", modelark: "BytePlus Ark",
            ollama: "Ollama", together: "Together AI", groq: "Groq", cohere: "Cohere",
            replicate: "Replicate", fireworks: "Fireworks AI", ai21: "AI21", xai: "xAI",
            grok: "xAI", perplexity: "Perplexity", cline: "Cline", opencode: "OpenCode",
            kilo: "Kilo", kiro: "Kiro", amp: "Amp", warp: "Warp"
        }
        return names[providerId] || capitalizeFirst(providerId || "provider")
    }

    function providersCsv(list) {
        const result = []
        for (let i = 0; i < list.length; i++) {
            const provider = normalizeProviderId(list[i])
            if (provider.length > 0 && result.indexOf(provider) < 0) result.push(provider)
        }
        return result.join(",")
    }

    function saveProviderSelection(csv) {
        const normalized = providersCsv(csv.split(","))
        if (normalized.length === 0) return
        providerSelection = normalized
        providers = []
        PluginService.savePluginData(pluginKey, "providerSelection", normalized)
        if (procUsage.running) procUsage.running = false
        usageDidTimeout = false
        timedOutRequestId = -1
        refresh()
    }

    function providerPercent(provider) {
        const windowData = primaryUsageWindow(provider)
        if (!windowData) return 0
        return Number(windowData.usedPercent || 0)
    }

    function providerStatus(provider) {
        if (!provider) return "missing"
        if (provider.error) return "error"
        if (provider.usage) return "active"
        return "empty"
    }

    function providerSourceLabel(provider) {
        const source = provider && provider.source ? String(provider.source) : "local"
        return source.length > 0 ? source : "local"
    }

    function providerErrorText(provider) {
        if (!provider || !provider.error) return ""
        const rawMessage = provider.error.message || provider.error.kind || "Provider returned an error."
        if (String(rawMessage).charAt(0) === "[") {
            try {
                const firstLine = String(rawMessage).split("\n")[0]
                const parsed = JSON.parse(firstLine)
                const list = Array.isArray(parsed) ? parsed : [parsed]
                for (let i = 0; i < list.length; i++) {
                    if (list[i] && list[i].provider === provider.provider && list[i].error)
                        return list[i].error.message || list[i].error.kind || rawMessage
                }
                if (list[0] && list[0].error) return list[0].error.message || list[0].error.kind || rawMessage
            } catch (error) { return rawMessage }
        }
        return rawMessage
    }

    function providerAccount(provider) {
        const usage = provider && provider.usage ? provider.usage : null
        if (!usage) return "—"
        if (usage.identity && usage.identity.accountEmail) return usage.identity.accountEmail
        return usage.accountEmail || "—"
    }

    function providerLogin(provider) {
        const usage = provider && provider.usage ? provider.usage : null
        if (!usage) return "—"
        if (usage.identity && usage.identity.loginMethod) return usage.identity.loginMethod
        return usage.loginMethod || "—"
    }

    function providerCredits(provider) {
        if (!provider || !provider.credits) return "—"
        return String(provider.credits.remaining ?? "—")
    }

    function providerUpdatedMs(provider) {
        const value = provider && provider.usage ? provider.usage.updatedAt : ""
        if (!value) return lastUpdatedMs
        const parsed = new Date(value).getTime()
        return Number.isFinite(parsed) ? parsed : lastUpdatedMs
    }

    function providerUpdatedLabel(provider) {
        const value = providerUpdatedMs(provider)
        return value > 0 ? Qt.formatDateTime(new Date(value), "hh:mm:ss") : lastUpdated
    }

    function compactPath(value) {
        const text = String(value || "")
        if (text.length === 0) return "none"
        const parts = text.split("/")
        if (parts.length <= 2) return text
        return `…/${parts.slice(-2).join("/")}`
    }

    function iconForProvider(providerId) {
        if (providerId === "codex") return "data_object"
        if (providerId === "claude") return "psychology"
        if (providerId === "copilot") return "hub"
        if (providerId === "gemini") return "auto_awesome"
        if (providerId === "openrouter") return "route"
        if (providerId === "9router") return "share"
        if (providerId === "deepseek") return "tsunami"
        if (providerId === "kimi" || providerId === "moonshot") return "dark_mode"
        if (providerId === "mistral") return "air"
        if (providerId === "glm" || providerId === "zhipu" || providerId === "zai") return "bubble_chart"
        if (providerId === "minimax") return "grid_view"
        if (providerId === "qwen" || providerId === "dashscope" || providerId === "alibaba") return "cloud"
        if (providerId === "nvidia" || providerId === "nim") return "memory"
        if (providerId === "cloudflare") return "shield"
        if (providerId === "vertexai" || providerId === "vertex") return "hexagon"
        if (providerId === "byteplus" || providerId === "ark" || providerId === "modelark") return "bolt"
        if (providerId === "perplexity") return "travel_explore"
        if (providerId === "cursor") return "ads_click"
        if (providerId === "ollama") return "dns"
        if (providerId === "together") return "join_inner"
        if (providerId === "groq") return "fast_forward"
        if (providerId === "cohere") return "waves"
        if (providerId === "replicate") return "content_copy"
        if (providerId === "fireworks") return "local_fire_department"
        if (providerId === "xai" || providerId === "grok") return "bolt"
        if (providerId === "ai21") return "looks_21"
        if (providerId === "cline") return "terminal"
        if (providerId === "opencode") return "code"
        if (providerId === "warp") return "rocket_launch"
        if (providerId === "amp") return "electric_bolt"
        if (providerId === "kilo") return "speed"
        if (providerId === "kiro") return "tune"
        return "monitoring"
    }

    function providerAccent(providerId) {
        if (providerId === "claude") return Theme.warning
        if (providerId === "codex") return Theme.success
        if (providerId === "copilot") return Theme.primary
        if (providerId === "gemini") return Theme.secondary
        if (providerId === "openrouter") return Theme.primary
        if (providerId === "9router") return Theme.secondary
        if (providerId === "deepseek") return Theme.primary
        if (providerId === "kimi" || providerId === "moonshot") return Theme.secondary
        if (providerId === "mistral") return Theme.warning
        if (providerId === "glm" || providerId === "zhipu" || providerId === "zai") return Theme.primary
        if (providerId === "minimax") return Theme.success
        if (providerId === "qwen" || providerId === "dashscope" || providerId === "alibaba") return Theme.warning
        if (providerId === "nvidia" || providerId === "nim") return Theme.success
        if (providerId === "cloudflare") return Theme.warning
        if (providerId === "vertexai" || providerId === "vertex") return Theme.primary
        if (providerId === "byteplus" || providerId === "ark" || providerId === "modelark") return Theme.secondary
        if (providerId === "together") return Theme.primary
        if (providerId === "groq") return Theme.success
        if (providerId === "cohere") return Theme.secondary
        if (providerId === "replicate") return Theme.primary
        if (providerId === "fireworks") return Theme.warning
        if (providerId === "xai" || providerId === "grok") return Theme.primary
        if (providerId === "ai21") return Theme.secondary
        return Theme.secondary
    }

    function windowsForProvider(provider) {
        const usage = provider && provider.usage ? provider.usage : null
        if (!usage) return []
        const windows = []
        if (usage.primary) windows.push({ key: "primary", label: usage.primary.resetDescription || getWindowLabel(usage.primary.windowMinutes), data: usage.primary })
        if (usage.secondary) windows.push({ key: "secondary", label: usage.secondary.resetDescription || getWindowLabel(usage.secondary.windowMinutes), data: usage.secondary })
        if (usage.tertiary) windows.push({ key: "tertiary", label: usage.tertiary.resetDescription || t("window.tertiary", "Tertiary"), data: usage.tertiary })
        return windows
    }

    function primaryUsageWindow(provider) {
        const usage = provider && provider.usage ? provider.usage : null
        if (!usage) return null
        return usage.primary || usage.secondary || usage.tertiary || null
    }

    function providerReset(provider) {
        const windowData = primaryUsageWindow(provider)
        if (!windowData) return "—"
        return formatTimeUntil(windowData.resetsAt)
    }

    function providerSubtitle(provider) {
        if (!provider) return t("status.provider_missing", "No provider data")
        if (provider.error) return root.providerErrorText(provider)
        const source = provider.source || "local"
        const windowData = primaryUsageWindow(provider)
        if (windowData && windowData.displayValue && String(windowData.displayValue).length > 0) {
            const label = windowData.resetDescription || t("status.usage", "usage")
            return `${source} · ${label} · ${windowData.displayValue}`
        }
        const reset = providerReset(provider)
        return reset !== "—" ? `${source} · ${t("status.reset", "reset")} ${reset}` : `${source} · ${t("status.no_reset", "no reset window")}`
    }

    function formatTokens(n) {
        const value = Number(n || 0)
        if (value >= 1000000000) return `${(value / 1000000000).toFixed(1)}B`
        if (value >= 1000000) return `${(value / 1000000).toFixed(1)}M`
        if (value >= 1000) return `${(value / 1000).toFixed(1)}K`
        return Math.round(value).toString()
    }

    function formatCost(usd) {
        const value = Number(usd || 0)
        if (value >= 1000) return `$${(value / 1000).toFixed(1)}K`
        if (value >= 100) return `$${Math.round(value)}`
        return `$${value.toFixed(2)}`
    }

    function formatTier(tier) {
        if (!tier) return "—"
        if (tier.indexOf("max_20x") >= 0) return "Max 20x"
        if (tier.indexOf("max_5x") >= 0) return "Max 5x"
        if (tier.indexOf("pro") >= 0) return "Pro"
        if (tier.indexOf("free") >= 0) return "Free"
        return tier
    }

    function parseNumberList(value) {
        const parts = value.split(",")
        const result = []
        for (let i = 0; i < 7; i++) result.push(i < parts.length ? Number(parts[i] || 0) : 0)
        return result
    }

    function parseClaudeLine(line) {
        const idx = line.indexOf("=")
        if (idx < 0) return
        const key = line.substring(0, idx)
        const val = line.substring(idx + 1)
        if (key === "SUBSCRIPTION_TYPE") claudeSubscriptionType = val
        else if (key === "RATE_LIMIT_TIER") claudeRateLimitTier = val
        else if (key === "FIVE_HOUR_UTIL") claudeFiveHourUtil = Number(val || 0)
        else if (key === "FIVE_HOUR_RESET") claudeFiveHourReset = val
        else if (key === "SEVEN_DAY_UTIL") claudeSevenDayUtil = Number(val || 0)
        else if (key === "SEVEN_DAY_RESET") claudeSevenDayReset = val
        else if (key === "EXTRA_USAGE_ENABLED") claudeExtraUsageEnabled = (val === "true")
        else if (key === "WEEK_MESSAGES") claudeWeekMessages = parseInt(val) || 0
        else if (key === "WEEK_SESSIONS") claudeWeekSessions = parseInt(val) || 0
        else if (key === "WEEK_TOKENS") claudeWeekTokens = Number(val || 0)
        else if (key === "MONTH_TOKENS") claudeMonthTokens = Number(val || 0)
        else if (key === "ALLTIME_SESSIONS") claudeAlltimeSessions = parseInt(val) || 0
        else if (key === "ALLTIME_MESSAGES") claudeAlltimeMessages = parseInt(val) || 0
        else if (key === "FIRST_SESSION") claudeFirstSession = val
        else if (key === "TODAY_COST") claudeTodayCost = Number(val || 0)
        else if (key === "WEEK_COST") claudeWeekCost = Number(val || 0)
        else if (key === "MONTH_COST") claudeMonthCost = Number(val || 0)
        else if (key === "DAILY") claudeDailyTokens = parseNumberList(val)
        else if (key === "DAILY_COSTS") claudeDailyCosts = parseNumberList(val)
        else if (key === "WEEK_MODELS") {
            claudeModelList.clear()
            if (val.length > 0) {
                const pairs = val.split(",")
                for (let i = 0; i < pairs.length; i++) {
                    const kv = pairs[i].split(":")
                    if (kv.length === 2) claudeModelList.append({ modelName: capitalizeFirst(kv[0]), modelTokens: Number(kv[1] || 0), modelCost: 0 })
                }
            }
        } else if (key === "WEEK_MODEL_COSTS") {
            if (val.length > 0) {
                const pairs = val.split(",")
                for (let i = 0; i < pairs.length; i++) {
                    const kv = pairs[i].split(":")
                    if (kv.length !== 2) continue
                    const name = capitalizeFirst(kv[0])
                    for (let j = 0; j < claudeModelList.count; j++) {
                        if (claudeModelList.get(j).modelName === name) { claudeModelList.setProperty(j, "modelCost", Number(kv[1] || 0)); break }
                    }
                }
            }
        } else if (key === "WEEK_PROJECTS") {
            claudeProjectList.clear()
            if (val.length > 0) {
                const pairs = val.split(",")
                for (let i = 0; i < pairs.length; i++) {
                    const cut = pairs[i].lastIndexOf(":")
                    if (cut <= 0) continue
                    claudeProjectList.append({ projectPath: pairs[i].substring(0, cut), projectTokens: Number(pairs[i].substring(cut + 1) || 0) })
                }
            }
        }
    }

    function windowBurnForecast(util, resetIso, windowMinutes) {
        if (!resetIso || util <= 0) return null
        const resetMs = new Date(resetIso).getTime()
        if (!Number.isFinite(resetMs)) return null
        const remainMin = Math.max(0, (resetMs - Date.now()) / 60000)
        if (remainMin <= 0 || remainMin >= windowMinutes) return null
        const elapsedMin = Math.max(1, windowMinutes - remainMin)
        const rate = util / elapsedMin
        if (rate <= 0) return null
        const minTo100 = (100 - util) / rate
        if (minTo100 <= remainMin) return { exceed: true, text: t("claude.burn_pace_exceed", "At this pace: 100% in {time}", { time: formatMinutes(minTo100) }) }
        return { exceed: false, text: t("claude.burn_pace_ok", "Usage on pace for this window") }
    }

    readonly property var claudeBurnForecast: { staleTickMs; return windowBurnForecast(claudeFiveHourUtil, claudeFiveHourReset, 300) }
    readonly property var claudeWeekBurnForecast: { staleTickMs; return windowBurnForecast(claudeSevenDayUtil, claudeSevenDayReset, 10080) }
    readonly property real claudeMonthProjection: {
        const today = new Date()
        const dayOfMonth = today.getDate()
        if (dayOfMonth <= 0 || claudeMonthCost <= 0) return 0
        const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()
        return (claudeMonthCost / dayOfMonth) * daysInMonth
    }

    function providerConsoleUrl(providerId) {
        const urls = {
            claude: "https://claude.ai/settings/usage",
            codex: "https://chatgpt.com/codex/settings/usage",
            copilot: "https://github.com/settings/copilot/features",
            gemini: "https://aistudio.google.com/usage",
            openrouter: "https://openrouter.ai/activity",
            deepseek: "https://platform.deepseek.com/usage",
            kimi: "https://platform.kimi.ai/console", moonshot: "https://platform.kimi.ai/console",
            mistral: "https://console.mistral.ai/usage",
            glm: "https://open.bigmodel.cn/usercenter/financial", zhipu: "https://open.bigmodel.cn/usercenter/financial",
            zai: "https://z.ai/manage-apikey/billing",
            minimax: "https://platform.minimax.io/user-center/payment/balance",
            qwen: "https://dashscope.console.aliyun.com", dashscope: "https://dashscope.console.aliyun.com", alibaba: "https://dashscope.console.aliyun.com",
            nvidia: "https://build.nvidia.com", nim: "https://build.nvidia.com",
            cloudflare: "https://dash.cloudflare.com",
            vertexai: "https://console.cloud.google.com/vertex-ai", vertex: "https://console.cloud.google.com/vertex-ai",
            byteplus: "https://console.volcengine.com", ark: "https://console.volcengine.com", modelark: "https://console.volcengine.com",
            together: "https://api.together.ai/settings/billing",
            groq: "https://console.groq.com/usage",
            cohere: "https://dashboard.cohere.com/billing",
            replicate: "https://replicate.com/account/billing",
            fireworks: "https://app.fireworks.ai",
            ai21: "https://studio.ai21.com",
            xai: "https://console.x.ai/billing", grok: "https://console.x.ai/billing",
            perplexity: "https://www.perplexity.ai/settings/billing",
            cursor: "https://cursor.com/settings",
            cline: "https://app.cline.bot",
            opencode: "https://opencode.ai",
            kilo: "https://app.kilo.ai/credits",
            kiro: "https://app.kiro.dev/settings/account",
            warp: "https://app.warp.dev",
            amp: "https://ampcode.com"
        }
        return urls[providerId] || ""
    }
    function openProviderConsole(providerId) {
        const url = providerConsoleUrl(providerId)
        if (url.length > 0) Quickshell.execDetached(["xdg-open", url])
    }

    function isPinned(providerId) { return pinnedProviders.indexOf(normalizeProviderId(providerId)) >= 0 }
    function togglePin(providerId) {
        const id = normalizeProviderId(providerId)
        const next = pinnedProviders.slice()
        const index = next.indexOf(id)
        if (index >= 0) next.splice(index, 1)
        else next.push(id)
        pinnedProvidersCsv = next.join(",")
        PluginService.savePluginData(pluginKey, "pinnedProviders", pinnedProvidersCsv)
    }

    function historyPercent(entry) { return Number(entry && entry.p !== undefined ? entry.p : entry) || 0 }
    function providerTrend(providerId) {
        const history = usageHistory[normalizeProviderId(providerId)]
        if (!history || history.length < 2) return ""
        const delta = historyPercent(history[history.length - 1]) - historyPercent(history[history.length - 2])
        if (delta >= 1) return "up"
        if (delta <= -1) return "down"
        return "flat"
    }

    function retryProvider(providerId) {
        if (procRetry.running) return
        retryingProviderId = normalizeProviderId(providerId)
        retryBuffer = ""
        procRetry.command = ["bash", providerUsageScript, retryingProviderId, copilotUsageScript]
        procRetry.running = true
    }

    function checkNotifications() {
        if (!notifyEnabled) return
        const seen = notifiedMap
        for (let i = 0; i < successfulProviders.length; i++) {
            const provider = successfulProviders[i]
            const windowData = primaryUsageWindow(provider)
            if (!windowData) continue
            const percent = Number(windowData.usedPercent || 0)
            const threshold = thresholdFor(provider.provider)
            const dedupeKey = `${provider.provider}:${windowData.resetsAt || "static"}:${threshold}`
            if (percent < threshold - 5) {
                delete seen[dedupeKey]
                Quickshell.execDetached(["bash", notifyAlertScript, "--clear", dedupeKey])
                continue
            }
            if (percent < threshold || seen[dedupeKey]) continue
            seen[dedupeKey] = true
            const pct = Math.round(percent)
            const exhausted = pct >= 100
            const reset = formatTimeUntil(windowData.resetsAt)
            const windowLabel = windowData.resetDescription || getWindowLabel(windowData.windowMinutes) || t("status.usage", "usage")
            const display = String(windowData.displayValue || "").trim()
            const title = exhausted
                ? t("notify.title_exhausted", "{provider} — quota exhausted", { provider: providerName(provider.provider) })
                : t("notify.title", "{provider} at {percent}%", { provider: providerName(provider.provider), percent: pct })
            const bodyParts = [windowLabel]
            if (display.length > 0 && display !== windowLabel) bodyParts.push(display)
            if (reset.length > 0) bodyParts.push(t("notify.resets_in", "resets in {time}", { time: reset }))
            Quickshell.execDetached(["bash", notifyAlertScript, dedupeKey, String(notifyCooldownSecs), exhausted ? "critical" : "normal", exhausted ? "dialog-error" : "dialog-warning", title, bodyParts.join(" · ")])
        }
        notifiedMap = seen
    }

    function detectBinary() {
        if (procDetect.running) return
        binaryReady = false
        hasError = false
        errorMessage = ""
        procDetect.running = true
    }

    function refresh() {
        if (!binaryReady || procUsage.running || usageDidTimeout) return
        hasError = false
        isLoading = true
        rawJsonBuffer = ""
        rawStderrBuffer = ""
        usageRequestId += 1
        timedOutRequestId = -1
        usageCommand = ["bash", providerUsageScript, selectedProviders.join(","), copilotUsageScript]
        procUsage.running = true
        usageTimeout.restart()
        if (root.selectedProviders.indexOf("claude") >= 0 && !claudeStatsProcess.running) {
            claudeStatsError = false
            claudeStatsProcess.running = true
            claudeTimeout.restart()
        }
        if (root.selectedProviders.indexOf("9router") >= 0 && !nineStatsProcess.running) {
            nineStatsBuffer = ""
            nineStatsProcess.running = true
        }
    }

    // --- Processes (faithful port) ---
    Process {
        id: procDetect
        command: ["sh", "-c", "[ -x \"$1\" ] && command -v bash >/dev/null && command -v jq >/dev/null && command -v curl >/dev/null", "sh", root.providerUsageScript]
        onExited: code => {
            root.binaryReady = code === 0
            if (root.binaryReady) root.refresh()
            else {
                root.providers = []
                root.hasError = true
                root.errorMessage = t("error.helper_missing", "Local provider helper is missing or not executable: {path}", { path: root.providerUsageScript })
            }
        }
    }

    Process {
        id: procUsage
        command: root.usageCommand
        environment: { "AIOC_HISTORY_MAX": root.historyRetention }
        stdout: SplitParser { splitMarker: ""; onRead: data => root.rawJsonBuffer += data }
        stderr: SplitParser {
            onRead: line => {
                const trimmed = line.trim()
                if (trimmed.length === 0) return
                if (root.rawStderrBuffer.length > 0) root.rawStderrBuffer += "\n"
                root.rawStderrBuffer += trimmed
            }
        }
        onExited: code => {
            const exitedRequestId = root.usageRequestId
            usageTimeout.stop()
            root.isLoading = false
            if (root.usageDidTimeout && root.timedOutRequestId === exitedRequestId) {
                root.usageDidTimeout = false
                root.timedOutRequestId = -1
                root.rawJsonBuffer = ""
                root.rawStderrBuffer = ""
                return
            }
            if (code === 0 && root.rawJsonBuffer.length > 0) {
                try {
                    const payload = JSON.parse(root.rawJsonBuffer)
                    const list = Array.isArray(payload) ? payload : [payload]
                    const flattened = []
                    for (let i = 0; i < list.length; i++) {
                        if (Array.isArray(list[i])) { for (let j = 0; j < list[i].length; j++) flattened.push(list[i][j]) }
                        else flattened.push(list[i])
                    }
                    root.providers = flattened
                    if (root.successfulProviders.length === 0 && root.errorProviders.length > 0) {
                        root.hasError = true
                        const firstErr = root.errorProviders[0].error
                        const firstErrMsg = (firstErr && typeof firstErr === "object") ? firstErr.message : (typeof firstErr === "string" ? firstErr : "")
                        root.errorMessage = firstErrMsg || t("error.fetch_failed", "Failed to fetch usage from providers.")
                    } else {
                        root.hasError = false
                        root.errorMessage = root.errorProviders.length > 0 ? t("error.providers_need_attention", "{count} provider(s) need attention.", { count: root.errorProviders.length }) : ""
                    }
                    root.lastUpdated = Qt.formatDateTime(new Date(), "hh:mm:ss")
                    root.lastUpdatedMs = Date.now()
                    root.checkNotifications()
                    if (!procHistory.running) { root.historyBuffer = ""; procHistory.running = true }
                } catch (error) {
                    root.hasError = true
                    root.errorMessage = root.rawStderrBuffer.length > 0 ? root.rawStderrBuffer : t("error.parse_failed", "Failed to parse provider helper output.")
                }
            } else if (code === 0) {
                root.providers = []
                root.hasError = false
                root.errorMessage = root.rawStderrBuffer.length > 0 ? root.rawStderrBuffer : ""
                root.lastUpdated = Qt.formatDateTime(new Date(), "hh:mm:ss")
                root.lastUpdatedMs = Date.now()
            } else {
                root.hasError = true
                root.errorMessage = root.formatUsageError(code)
            }
            root.rawJsonBuffer = ""
            root.rawStderrBuffer = ""
        }
    }

    Process {
        id: procHistory
        command: ["bash", root.usageHistoryScript]
        stdout: SplitParser { splitMarker: ""; onRead: data => root.historyBuffer += data }
        onExited: code => {
            if (code !== 0 || root.historyBuffer.length === 0) { root.historyBuffer = ""; return }
            try { root.usageHistory = JSON.parse(root.historyBuffer) } catch (error) {}
            root.historyBuffer = ""
        }
    }

    Process {
        id: procRetry
        stdout: SplitParser { splitMarker: ""; onRead: data => root.retryBuffer += data }
        onExited: code => {
            const targetId = root.retryingProviderId
            root.retryingProviderId = ""
            if (code !== 0 || root.retryBuffer.length === 0) { root.retryBuffer = ""; return }
            try {
                const payload = JSON.parse(retryBuffer)
                const list = Array.isArray(payload) ? payload : [payload]
                if (list.length > 0 && list[0] && list[0].provider === targetId) {
                    const next = root.providers.slice()
                    for (let i = 0; i < next.length; i++) {
                        if (next[i] && next[i].provider === targetId) { next[i] = list[0]; break }
                    }
                    root.providers = next
                    root.checkNotifications()
                }
            } catch (error) {}
            root.retryBuffer = ""
        }
    }

    Process {
        id: claudeStatsProcess
        command: ["bash", root.claudeUsageScript]
        stdout: SplitParser {
            onRead: data => {
                const lines = data.trim().split("\n")
                for (let i = 0; i < lines.length; i++) root.parseClaudeLine(lines[i])
            }
        }
        onExited: code => {
            claudeTimeout.stop()
            root.claudeStatsError = (code !== 0)
        }
    }

    Timer {
        id: claudeTimeout
        interval: root.fetchTimeoutMs
        repeat: false
        onTriggered: { if (claudeStatsProcess.running) claudeStatsProcess.running = false; root.claudeStatsError = true }
    }

    Process {
        id: nineStatsProcess
        command: ["bash", root.nineRouterAnalyticsScript]
        stdout: SplitParser { splitMarker: ""; onRead: data => root.nineStatsBuffer += data }
        onExited: code => {
            if (code !== 0 || root.nineStatsBuffer.length === 0) { root.nineStatsBuffer = ""; return }
            try {
                const parsed = JSON.parse(root.nineStatsBuffer)
                root.nineStats = (parsed && !parsed.error) ? parsed : null
            } catch (error) {}
            root.nineStatsBuffer = ""
        }
    }

    Timer {
        id: usageTimeout
        interval: root.fetchTimeoutMs
        repeat: false
        onTriggered: {
            if (procUsage.running) {
                root.timedOutRequestId = root.usageRequestId
                root.usageDidTimeout = true
                procUsage.running = false
                root.isLoading = false
                root.hasError = true
                root.errorMessage = t("error.helper_timeout", "Provider helper timed out while fetching usage data.")
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: root.refreshIntervalMs
        running: root.binaryReady && root.isRunnable()
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: staleClock
        interval: 10000
        running: root.binaryReady
        repeat: true
        onTriggered: root.staleTickMs = Date.now()
    }

    Timer {
        id: startupTimer
        interval: 1200
        repeat: false
        running: false
        onTriggered: { if (root.isRunnable() && !root.binaryReady) root.detectBinary() }
    }

    Component.onCompleted: {
        root.windowRef = Window.window ?? null
        if (pluginService && pluginId) {
            const fromService = pluginService.getPluginPath ? pluginService.getPluginPath(pluginId) : ""
            if (fromService && fromService.length > 0) _pluginDir = fromService
        }
        if (!_pluginDir) {
            const selfUrl = Qt.resolvedUrl("AiControlCenterWidget.qml").toString()
            const withoutScheme = selfUrl.startsWith("file://") ? selfUrl.substring(7) : selfUrl
            const lastSlash = withoutScheme.lastIndexOf("/")
            _pluginDir = lastSlash !== -1 ? withoutScheme.substring(0, lastSlash) : withoutScheme
        }
        AiControlCenterI18n.loadSettings()
        startupTimer.running = true
    }
    onVisibleChanged: root.handleVisibility()
    onWidgetWidthChanged: root.handleVisibility()
    onWidgetHeightChanged: root.handleVisibility()
    function handleVisibility() {
        if (root.isRunnable()) {
            if (!refreshTimer.running && root.binaryReady) { refreshTimer.running = true; root.refresh() }
            else if (!root.binaryReady && !procDetect.running && !startupTimer.running) root.detectBinary()
        } else {
            refreshTimer.running = false
        }
    }

    // ============================ UI ============================
    // Technical-minimalist desktop surface: dense rows, monospace numerics,
    // status accents only, decoration kept to a minimum. All horizontal rows
    // use RowLayout so spacers/padding behave; inline components reference
    // explicit ids (never parent.parent) for robust bindings.
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, root.backgroundOpacity)
        border.color: Theme.withAlpha(Theme.outlineVariant, 0.7)
        border.width: 1
        clip: true

        Rectangle { // top accent hairline
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            height: 2; color: Theme.withAlpha(root.heroAccent, 0.55)
        }

        Column {
            id: shell
            anchors.fill: parent
            spacing: 0

            // ---------- Control bar ----------
            Item {
                id: controlBar
                visible: root.showHeader
                width: shell.width
                height: visible ? headerCol.height : 0
                Column {
                    id: headerCol
                    width: parent.width
                    spacing: 0
                    // title row
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS
                        Layout.leftMargin: Theme.spacingM
                        Layout.rightMargin: Theme.spacingS
                        Rectangle { // status dot
                            implicitWidth: 8; implicitHeight: 8; radius: 4
                            Layout.alignment: Qt.AlignVCenter
                            color: root.isLoading ? Theme.primary : (root.hasError ? Theme.error : (root.hasProviderData ? Theme.success : Theme.outlineVariant))
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }
                        StyledText {
                            text: root.t("app.title", "AI Control Center")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle { // engine label pill
                            visible: root.widgetWidth > 360
                            implicitWidth: engLabel.implicitWidth + 14; implicitHeight: 18; radius: 9
                            Layout.alignment: Qt.AlignVCenter
                            color: Theme.withAlpha(Theme.outlineVariant, 0.35)
                            StyledText {
                                id: engLabel
                                anchors.centerIn: parent
                                text: root.providerEngineLabel
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall - 2
                                font.family: root.monoFontFamily
                            }
                        }
                        DankIcon { // refresh
                            name: "refresh"
                            size: Theme.iconSize - 6
                            Layout.alignment: Qt.AlignVCenter
                            color: refreshMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText
                            Behavior on color { ColorAnimation { duration: 150 } }
                            MouseArea {
                                id: refreshMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.refresh()
                            }
                        }
                    }
                    // search + filters row
                    RowLayout {
                        width: parent.width
                        height: 34
                        visible: root.widgetWidth > 300
                        spacing: Theme.spacingS
                        Layout.leftMargin: Theme.spacingM
                        Layout.rightMargin: Theme.spacingM
                        Rectangle { // search field
                            Layout.fillWidth: true
                            implicitHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            radius: 6
                            color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.6)
                            border.color: Theme.withAlpha(Theme.outlineVariant, 0.6)
                            border.width: 1
                            DankIcon {
                                name: "search"; size: 13; color: Theme.surfaceVariantText
                                anchors.left: parent.left; anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            TextInput {
                                id: searchInput
                                anchors.left: parent.left; anchors.leftMargin: 24
                                anchors.right: parent.right; anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.family: root.monoFontFamily
                                clip: true
                                selectByMouse: true
                                verticalAlignment: Text.AlignVCenter
                                Text { // placeholder
                                    visible: !searchInput.text
                                    text: root.t("card.filter_providers", "Filter providers by name or source")
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    font.family: root.monoFontFamily
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onTextEdited: root.providerFilter = text
                            }
                        }
                        Row { // status filters
                            id: filtersRow
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            Repeater {
                                model: [
                                    { id: "all", label: root.t("filter.all", "All") },
                                    { id: "live", label: root.t("filter.live", "Live") },
                                    { id: "issues", label: root.t("filter.issues", "Issues") }
                                ]
                                delegate: Rectangle {
                                    width: flabel.implicitWidth + 12; height: 24; radius: 6
                                    color: root.providerStatusFilter === modelData.id ? Theme.withAlpha(Theme.primary, 0.22) : "transparent"
                                    border.color: root.providerStatusFilter === modelData.id ? Theme.primary : "transparent"
                                    border.width: 1
                                    StyledText {
                                        id: flabel
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: root.providerStatusFilter === modelData.id ? Theme.primary : Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.weight: root.providerStatusFilter === modelData.id ? Font.DemiBold : Font.Normal
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.providerStatusFilter = modelData.id
                                    }
                                }
                            }
                        }
                    }
                    Rectangle { // divider
                        width: parent.width; height: 1
                        color: Theme.withAlpha(Theme.outlineVariant, 0.5)
                    }
                }
            }

            // ---------- Hero strip (dense stats) ----------
            Column {
                id: heroStrip
                width: shell.width
                spacing: Theme.spacingXS
                topPadding: Theme.spacingS
                bottomPadding: Theme.spacingS
                leftPadding: Theme.spacingM; rightPadding: Theme.spacingM

                RowLayout {
                    width: parent.width - parent.leftPadding - parent.rightPadding
                    spacing: Theme.spacingS
                    StyledText {
                        text: root.hasProviderData ? root.providerName(root.providerData.provider).toUpperCase() : root.t("panel.status", "Status")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall - 2
                        font.family: root.monoFontFamily
                        font.letterSpacing: 0.8
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { Layout.fillWidth: true }
                    StatBadge { label: root.t("panel.active_short", "active"); value: root.successfulProviders.length; badgeColor: Theme.success }
                    StatBadge { label: root.t("panel.issues_short", "issues"); value: root.errorProviders.length; badgeColor: Theme.warning; visible: root.errorProviders.length > 0 }
                    StatBadge { label: root.t("panel.critical_short", "critical"); value: root.criticalCount; badgeColor: Theme.error; visible: root.criticalCount > 0 }
                }
                // usage bar
                Item {
                    width: parent.width - parent.leftPadding - parent.rightPadding
                    height: 10
                    Rectangle {
                        anchors.fill: parent; radius: 2
                        color: Theme.withAlpha(Theme.outlineVariant, 0.4)
                    }
                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(100, root.primaryPercent)) / 100
                        radius: 2
                        color: root.heroAccent
                        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 320 } }
                    }
                    Rectangle { // threshold tick
                        visible: root.notifyEnabled && root.hasProviderData
                        x: parent.width * root.notifyThreshold / 100 - 1
                        width: 2; height: parent.height + 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.withAlpha(Theme.outlineStrong, 0.7)
                    }
                }
                RowLayout {
                    width: parent.width - parent.leftPadding - parent.rightPadding
                    spacing: Theme.spacingS
                    StyledText {
                        text: root.statusTitle
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignVCenter
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: root.hasProviderData && root.primaryWindow && root.formatTimeUntil(root.primaryWindow.resetsAt).length > 0
                            ? `${root.t("panel.next_reset", "Next reset")} ${root.formatTimeUntil(root.primaryWindow.resetsAt)}`
                            : (root.lastUpdated.length > 0 ? `${root.t("panel.last_sync", "Last sync")} ${root.lastUpdated}` : root.t("panel.no_data", "Awaiting telemetry"))
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall - 2
                        font.family: root.monoFontFamily
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Theme.withAlpha(Theme.outlineVariant, 0.5) }
            }

            // ---------- Indeterminate loading bar ----------
            Item {
                id: loadingBar
                width: shell.width
                height: root.isLoading ? 2 : 0
                visible: root.isLoading
                clip: true
                Rectangle {
                    height: parent.height; width: 80; radius: 1
                    color: Theme.primary
                    NumberAnimation on x { from: -80; to: surface.width; duration: 900; loops: Animation.Infinite; running: root.isLoading }
                }
            }

            // ---------- Content scroll ----------
            Flickable {
                id: content
                width: shell.width
                height: shell.height - controlBar.height - heroStrip.height - loadingBar.height - footer.height
                contentWidth: width
                contentHeight: contentCol.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                Column {
                    id: contentCol
                    width: parent.width
                    spacing: 0

                    // Empty / error states
                    Item {
                        width: parent.width
                        height: (!root.hasProviderData && root.filteredDisplayProviders.length === 0) ? emptyState.height : 0
                        visible: height > 0
                        Column {
                            id: emptyState
                            width: parent.width - Theme.spacingXL * 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            topPadding: Theme.spacingXL
                            spacing: Theme.spacingS
                            DankIcon {
                                name: root.hasError ? "error_outline" : "satellite_alt"
                                size: 32; color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            StyledText {
                                width: parent.width
                                text: root.hasError ? root.errorMessage : root.statusSubtitle
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Provider grid (responsive)
                    GridLayout {
                        id: providerGrid
                        width: parent.width
                        columns: root.widgetWidth < 460 ? 1 : (root.widgetWidth < 720 ? 2 : (root.widgetWidth < 1000 ? 3 : 4))
                        columnSpacing: 1
                        rowSpacing: 1
                        visible: root.filteredDisplayProviders.length > 0
                        Repeater {
                            model: root.filteredDisplayProviders
                            delegate: ProviderCard {}
                        }
                    }

                    // Claude telemetry panel
                    Loader {
                        width: parent.width
                        active: root.selectedProviders.indexOf("claude") >= 0 && !root.claudeStatsError && (root.claudeWeekTokens > 0 || root.claudeTodayCost > 0)
                        sourceComponent: claudeTelemetry
                    }
                    Component { id: claudeTelemetry; ClaudeTelemetryPanel {} }

                    // 9Router telemetry panel
                    Loader {
                        width: parent.width
                        active: root.selectedProviders.indexOf("9router") >= 0 && root.nineStats !== null
                        sourceComponent: nineTelemetry
                    }
                    Component { id: nineTelemetry; NineTelemetryPanel {} }

                    Item { width: parent.width; height: Theme.spacingM }
                }
            }

            // ---------- Footer ----------
            Item {
                id: footer
                width: shell.width; height: 22
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.withAlpha(Theme.outlineVariant, 0.5) }
                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingS
                    Layout.leftMargin: Theme.spacingM
                    Layout.rightMargin: Theme.spacingM
                    StyledText {
                        text: root.lastUpdated.length > 0 ? root.t("card.updated_at", "Updated {time}", { time: root.lastUpdated }) : ""
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall - 3
                        font.family: root.monoFontFamily
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: root.isDataStale ? root.t("panel.stale", "Stale").toUpperCase() : ""
                        color: Theme.warning
                        font.pixelSize: Theme.fontSizeSmall - 3
                        font.family: root.monoFontFamily
                        font.letterSpacing: 0.6
                        Layout.alignment: Qt.AlignVCenter
                    }
                    StyledText {
                        text: `${root.filteredDisplayProviders.length}/${root.providers.length}`
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall - 3
                        font.family: root.monoFontFamily
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }

    // ===================== Inline components =====================
    component StatBadge : Row {
        property string label: ""
        property int value: 0
        property color badgeColor: Theme.success
        spacing: 3
        Layout.alignment: Qt.AlignVCenter
        StyledText {
            text: value
            color: badgeColor
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: Font.Bold
            font.family: root.monoFontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            text: label
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall - 3
            font.family: root.monoFontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    component ProviderCard : Item {
        id: card
        required property var modelData
        readonly property var provider: modelData
        readonly property real percent: root.providerPercent(provider)
        readonly property color accent: root.getUsageColor(percent)
        readonly property bool hasUsage: !!provider && !!provider.usage && !provider.error
        readonly property bool isError: !!provider && !!provider.error
        readonly property string pid: provider ? provider.provider : ""
        readonly property bool expanded: root.focusedProviderId === pid
        readonly property var historyPoints: root.usageHistory[provider ? provider.provider : ""] || []
        Layout.fillWidth: true
        implicitHeight: cardCol.height
        height: cardCol.height

        function toggleExpand() {
            root.focusedProviderId = (root.focusedProviderId === card.pid ? "" : card.pid)
        }

        Column {
            id: cardCol
            width: parent.width
            spacing: 0

            Rectangle {
                id: row
                width: parent.width
                height: root.densityMode === "compact" ? 38 : 44
                color: rowArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.5) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.toggleExpand()
                }
                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingS
                    Layout.leftMargin: Theme.spacingS
                    Layout.rightMargin: Theme.spacingS
                    Rectangle { // status bar (left edge)
                        implicitWidth: 3; implicitHeight: parent.height - 12
                        Layout.alignment: Qt.AlignVCenter
                        color: card.isError ? Theme.error : card.accent
                        opacity: card.hasUsage || card.isError ? 1 : 0.25
                    }
                    DankIcon {
                        name: card.isError ? "error" : root.iconForProvider(card.pid)
                        size: 16
                        Layout.alignment: Qt.AlignVCenter
                        color: card.isError ? Theme.error : Theme.surfaceVariantText
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            text: root.providerName(card.pid)
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        StyledText {
                            visible: root.widgetWidth > 280
                            text: card.isError ? root.providerErrorText(card.provider)
                                : (root.providerSourceLabel(card.provider) + (card.hasUsage ? ` · ${root.providerReset(card.provider)}` : ""))
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall - 3
                            font.family: root.monoFontFamily
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    ColumnLayout {
                        visible: card.hasUsage
                        Layout.preferredWidth: 52
                        spacing: 0
                        StyledText {
                            text: `${Math.round(card.percent)}%`
                            color: card.accent
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            font.family: root.monoFontFamily
                            Layout.alignment: Qt.AlignHCenter
                        }
                        StyledText {
                            property string tr: root.providerTrend(card.pid)
                            visible: tr.length > 0
                            text: tr === "up" ? "▲" : (tr === "down" ? "▼" : "▬")
                            color: tr === "up" ? Theme.error : (tr === "down" ? Theme.success : Theme.surfaceVariantText)
                            font.pixelSize: Theme.fontSizeSmall - 4
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                    Row {
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter
                        DankIcon {
                            name: "push_pin"
                            size: 13
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.isPinned(card.pid) ? Theme.primary : (pinMouse.containsMouse ? Theme.surfaceText : Theme.outlineVariant)
                            opacity: root.isPinned(card.pid) ? 1 : 0.5
                            MouseArea {
                                id: pinMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePin(card.pid)
                            }
                        }
                        DankIcon {
                            name: "open_in_new"
                            size: 12
                            visible: root.providerConsoleUrl(card.pid).length > 0
                            anchors.verticalCenter: parent.verticalCenter
                            color: consoleMouse.containsMouse ? Theme.primary : Theme.outlineVariant
                            MouseArea {
                                id: consoleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openProviderConsole(card.pid)
                            }
                        }
                        DankIcon {
                            name: "expand_more"
                            size: 16
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.surfaceVariantText
                            rotation: card.expanded ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 160 } }
                        }
                    }
                }
                Rectangle { // progress bar under row
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: 2
                    color: Theme.withAlpha(Theme.outlineVariant, 0.3)
                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(100, card.percent)) / 100
                        color: card.accent
                        visible: card.hasUsage
                    }
                }
            }

            // Expanded details
            Item {
                width: parent.width
                height: card.expanded ? expCol.height : 0
                visible: card.expanded
                clip: true
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Column {
                    id: expCol
                    width: parent.width - Theme.spacingM * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: Theme.spacingS; bottomPadding: Theme.spacingS
                    spacing: Theme.spacingS

                    Item { // sparkline
                        width: parent.width; height: (card.hasUsage && card.historyPoints.length >= 2) ? 40 : 0
                        visible: height > 0
                        Sparkline {
                            anchors.fill: parent
                            points: card.historyPoints
                            lineColor: card.accent
                        }
                    }

                    Column { // window rows
                        width: parent.width
                        spacing: 2
                        visible: card.hasUsage
                        Repeater {
                            model: root.windowsForProvider(card.provider)
                            delegate: RowLayout {
                                width: parent.width
                                spacing: Theme.spacingS
                                StyledText {
                                    text: modelData.label
                                    Layout.preferredWidth: parent.width * 0.34
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall - 3
                                    font.family: root.monoFontFamily
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    text: root.formatUsageLine(modelData.data)
                                    Layout.fillWidth: true
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall - 3
                                    font.family: root.monoFontFamily
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    text: root.formatTimeUntil(modelData.data.resetsAt)
                                    Layout.preferredWidth: parent.width * 0.26
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall - 3
                                    font.family: root.monoFontFamily
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    GridLayout { // identity / credits
                        width: parent.width
                        columns: 2
                        columnSpacing: Theme.spacingS; rowSpacing: 2
                        visible: card.hasUsage
                        DetailRow { labelText: root.t("card.account", "Account"); valueText: root.providerAccount(card.provider) }
                        DetailRow { labelText: root.t("card.login", "Login"); valueText: root.providerLogin(card.provider) }
                        DetailRow { labelText: root.t("card.credits", "Credits"); valueText: root.providerCredits(card.provider); visible: root.providerCredits(card.provider) !== "—" }
                    }

                    Rectangle { // retry (error)
                        width: parent.width; height: 26
                        radius: 6
                        visible: card.isError
                        color: retryMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.18) : Theme.withAlpha(Theme.error, 0.08)
                        border.color: Theme.withAlpha(Theme.error, 0.4); border.width: 1
                        RowLayout {
                            anchors.fill: parent
                            spacing: 4
                            Layout.leftMargin: 8
                            DankIcon { name: "refresh"; size: 13; color: Theme.error; Layout.alignment: Qt.AlignVCenter }
                            StyledText {
                                text: root.retryingProviderId === card.pid ? "…" : root.t("card.retry", "Retry")
                                color: Theme.error
                                font.pixelSize: Theme.fontSizeSmall - 2
                                font.family: root.monoFontFamily
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                        MouseArea {
                            id: retryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.retryProvider(card.pid)
                        }
                    }
                }
            }
        }
    }

    component DetailRow : Item {
        property string labelText: ""
        property string valueText: ""
        Layout.fillWidth: true
        height: valueText.length > 0 ? 16 : 0
        visible: valueText.length > 0
        RowLayout {
            anchors.fill: parent
            spacing: Theme.spacingS
            StyledText {
                text: labelText
                Layout.preferredWidth: parent.width * 0.3
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall - 3
                font.family: root.monoFontFamily
                elide: Text.ElideRight
            }
            StyledText {
                text: valueText
                Layout.fillWidth: true
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall - 3
                font.family: root.monoFontFamily
                elide: Text.ElideRight
            }
        }
    }

    component Sparkline : Canvas {
        id: spark
        property var points: []
        property color lineColor: Theme.primary
        renderStrategy: Canvas.Cooperative
        onPointsChanged: requestPaint()
        onLineColorChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const pts = points
            if (!pts || pts.length < 2) return
            const w = width, h = height
            let min = Infinity, max = -Infinity
            for (let i = 0; i < pts.length; i++) {
                const p = Number(pts[i] && pts[i].p !== undefined ? pts[i].p : pts[i]) || 0
                if (p < min) min = p
                if (p > max) max = p
            }
            if (max - min < 1) max = min + 1
            const pad = 3
            ctx.strokeStyle = lineColor
            ctx.lineWidth = 1.4
            ctx.beginPath()
            for (let i = 0; i < pts.length; i++) {
                const p = Number(pts[i] && pts[i].p !== undefined ? pts[i].p : pts[i]) || 0
                const x = pad + (i / (pts.length - 1)) * (w - pad * 2)
                const y = h - pad - ((p - min) / (max - min)) * (h - pad * 2)
                if (i === 0) ctx.moveTo(x, y)
                else ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
    }

    component ClaudeTelemetryPanel : Column {
        id: ctp
        width: parent.width
        spacing: 0
        topPadding: Theme.spacingM
        Rectangle { width: parent.width; height: 1; color: Theme.withAlpha(Theme.outlineVariant, 0.5) }
        SectionHeader {
            titleText: root.t("panel.telemetry", "Telemetry")
            subtitleText: "Claude Code"
            extraText: root.t("card.today_cost", "Today cost") + " " + root.formatCost(root.claudeTodayCost)
        }
        GridLayout {
            width: parent.width - Theme.spacingM * 2
            anchors.horizontalCenter: parent.horizontalCenter
            columns: root.widgetWidth < 520 ? 2 : 4
            columnSpacing: Theme.spacingS; rowSpacing: Theme.spacingS
            MetricTile { labelText: root.t("card.today_cost", "Today cost"); valueText: root.formatCost(root.claudeTodayCost); accentColor: Theme.warning }
            MetricTile { labelText: root.t("card.today_tokens", "Today tokens"); valueText: root.formatTokens(root.claudeDailyTokens[root.currentWeekdayIndex]); accentColor: Theme.warning }
            MetricTile { labelText: root.t("card.week", "Week"); valueText: root.formatCost(root.claudeWeekCost); accentColor: Theme.secondary }
            MetricTile { labelText: root.t("card.month", "Month"); valueText: root.formatCost(root.claudeMonthCost); accentColor: Theme.secondary }
            MetricTile { labelText: root.t("card.projected_month", "Projected month"); valueText: root.formatCost(root.claudeMonthProjection); accentColor: Theme.primary; visible: root.claudeMonthProjection > 0 }
            MetricTile { labelText: "5h"; valueText: Math.round(root.claudeFiveHourUtil) + "%"; accentColor: root.getUsageColor(root.claudeFiveHourUtil); visible: root.claudeFiveHourUtil > 0 }
            MetricTile { labelText: "7d"; valueText: Math.round(root.claudeSevenDayUtil) + "%"; accentColor: root.getUsageColor(root.claudeSevenDayUtil); visible: root.claudeSevenDayUtil > 0 }
            MetricTile { labelText: root.t("card.extra_usage_on", "Extra usage on"); valueText: root.claudeExtraUsageEnabled ? "ON" : "OFF"; accentColor: root.claudeExtraUsageEnabled ? Theme.error : Theme.outlineVariant; visible: root.claudeFiveHourUtil > 0 || root.claudeSevenDayUtil > 0 }
        }
        Item { // daily token bars
            id: dayBarsContainer
            width: parent.width - Theme.spacingM * 2
            anchors.horizontalCenter: parent.horizontalCenter
            height: 56
            readonly property real maxTok: {
                let m = 0
                for (let i = 0; i < 7; i++) if (root.claudeDailyTokens[i] > m) m = root.claudeDailyTokens[i]
                return m
            }
            Row {
                id: dayBars
                anchors.fill: parent
                spacing: 3
                Repeater {
                    model: 7
                    delegate: ColumnLayout {
                        id: dayCol
                        width: (parent.width - dayBars.spacing * 6) / 7
                        height: parent.height
                        spacing: 2
                        readonly property real tok: root.claudeDailyTokens[index] || 0
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * 0.7
                                height: dayBarsContainer.maxTok > 0 ? parent.height * (dayCol.tok / dayBarsContainer.maxTok) : 1
                                color: index === root.currentWeekdayIndex ? Theme.primary : Theme.withAlpha(Theme.secondary, 0.5)
                                radius: 1
                            }
                        }
                        StyledText {
                            text: root.dayLabels[index] ? root.dayLabels[index][0] : ""
                            color: index === root.currentWeekdayIndex ? Theme.primary : Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall - 4
                            font.family: root.monoFontFamily
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
        Column { // top models
            width: parent.width - Theme.spacingM * 2
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            visible: claudeModelList.count > 0
            StyledText { text: root.t("card.models_week", "Models this week"); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 3; font.family: root.monoFontFamily; font.letterSpacing: 0.5 }
            Repeater {
                model: claudeModelList
                delegate: RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS
                    StyledText { text: modelData.modelName; Layout.preferredWidth: parent.width * 0.5; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall - 3; font.family: root.monoFontFamily; elide: Text.ElideRight }
                    StyledText { text: root.formatTokens(modelData.modelTokens); Layout.preferredWidth: parent.width * 0.25; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 3; font.family: root.monoFontFamily }
                    StyledText { text: root.formatCost(modelData.modelCost); Layout.fillWidth: true; color: Theme.warning; font.pixelSize: Theme.fontSizeSmall - 3; font.family: root.monoFontFamily; horizontalAlignment: Text.AlignRight }
                }
            }
        }
        Column { // top projects
            width: parent.width - Theme.spacingM * 2
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            visible: root.showClaudeProjects && claudeProjectList.count > 0
            StyledText { text: root.t("card.top_projects", "Top projects this week"); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 3; font.family: root.monoFontFamily; font.letterSpacing: 0.5 }
            Repeater {
                model: claudeProjectList
                delegate: RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS
                    StyledText { text: root.compactPath(modelData.projectPath); Layout.preferredWidth: parent.width * 0.7; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall - 3; font.family: root.monoFontFamily; elide: Text.ElideRight }
                    StyledText { text: root.formatTokens(modelData.projectTokens); Layout.fillWidth: true; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 3; font.family: root.monoFontFamily; horizontalAlignment: Text.AlignRight }
                }
            }
        }
    }

    component NineTelemetryPanel : Column {
        id: ntp
        width: parent.width
        spacing: 0
        topPadding: Theme.spacingM
        readonly property var stats: root.nineStats || ({})
        readonly property var sToday: stats.today || ({})
        readonly property var sWeek: stats.week || ({})
        readonly property var sMonth: stats.month || ({})
        Rectangle { width: parent.width; height: 1; color: Theme.withAlpha(Theme.outlineVariant, 0.5) }
        SectionHeader {
            titleText: root.t("panel.telemetry", "Telemetry")
            subtitleText: "9Router"
            extraText: root.formatCost(Number(ntp.sMonth.cost || 0))
        }
        GridLayout {
            width: parent.width - Theme.spacingM * 2
            anchors.horizontalCenter: parent.horizontalCenter
            columns: root.widgetWidth < 520 ? 2 : 4
            columnSpacing: Theme.spacingS; rowSpacing: Theme.spacingS
            MetricTile { labelText: root.t("card.nine_today", "Today"); valueText: `${root.formatCost(ntp.sToday.cost || 0)} · ${Number(ntp.sToday.requests || 0)} req`; accentColor: Theme.secondary }
            MetricTile { labelText: root.t("card.week", "Week"); valueText: `${root.formatCost(ntp.sWeek.cost || 0)} · ${Number(ntp.sWeek.requests || 0)} req`; accentColor: Theme.secondary }
            MetricTile { labelText: root.t("card.month", "Month"); valueText: `${root.formatCost(ntp.sMonth.cost || 0)} · ${Number(ntp.sMonth.requests || 0)} req`; accentColor: Theme.secondary }
            MetricTile { labelText: root.t("card.nine_week_tokens", "Week tokens"); valueText: root.formatTokens(ntp.sWeek.tokens || 0); accentColor: Theme.secondary }
        }
    }

    component SectionHeader : RowLayout {
        id: sh
        property string titleText: ""
        property string subtitleText: ""
        property string extraText: ""
        width: parent.width
        spacing: Theme.spacingS
        Layout.leftMargin: Theme.spacingM
        Layout.rightMargin: Theme.spacingM
        StyledText { text: titleText.toUpperCase(); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 3; font.family: root.monoFontFamily; font.letterSpacing: 0.8; Layout.alignment: Qt.AlignVCenter }
        StyledText { text: subtitleText; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall - 2; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignVCenter }
        Item { Layout.fillWidth: true }
        StyledText { text: extraText; color: Theme.warning; font.pixelSize: Theme.fontSizeSmall - 2; font.family: root.monoFontFamily; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignVCenter }
    }

    component MetricTile : ColumnLayout {
        property string labelText: ""
        property string valueText: ""
        property color accentColor: Theme.secondary
        Layout.fillWidth: true
        spacing: 1
        StyledText { text: labelText.toUpperCase(); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 4; font.family: root.monoFontFamily; font.letterSpacing: 0.5 }
        StyledText { text: valueText; color: accentColor; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; font.family: root.monoFontFamily; elide: Text.ElideRight; Layout.fillWidth: true }
    }
}
