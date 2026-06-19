# Configuration

All settings are stored through DMS. Plugin updates do not overwrite user choices.

## Interface

| Setting | Values | Default |
| --- | --- | --- |
| Language | `auto`, `en_US`, `pt_BR`, `zh_CN`, `es_ES`, `de_DE` | `auto` |
| Dashboard density | `comfortable`, `compact` | `comfortable` |
| Refresh interval | 1, 2, 5, 15, or 30 minutes | 2 minutes |
| Show provider errors | enabled or disabled | enabled |
| Show Claude projects | enabled or disabled | enabled |

## Appearance (desktop)

| Setting | Values | Default |
| --- | --- | --- |
| Panel opacity | 0–100% | 92% |
| Show control bar | enabled or disabled | enabled |

Compact density reduces collapsed-card height and hides the preview progress bar. Panel opacity controls how much of the wallpaper shows through the desktop surface.

## Provider selection

Use the provider chips or the toggle on each row. At least one provider remains selected. Recommended baseline:

```text
codex,claude,copilot
```

Add API providers only after their required environment variables are available to the DMS process.

## Environment variables

| Provider | Variables |
| --- | --- |
| Copilot | `COPILOT_GITHUB_TOKEN`, `GH_TOKEN`, or `GITHUB_TOKEN` |
| Gemini | `GEMINI_API_KEY`, `GOOGLE_API_KEY`, or `GOOGLE_GENERATIVE_AI_API_KEY` |
| OpenRouter | `OPENROUTER_API_KEY` |
| DeepSeek | `DEEPSEEK_API_KEY` |
| Kimi | `MOONSHOT_API_KEY` or `KIMI_API_KEY`; optional `MOONSHOT_API_BASE` |
| MiniMax | `MINIMAX_API_KEY` |
| GLM | `GLM_API_KEY` or `ZHIPU_API_KEY`; optional `GLM_API_BASE` |
| Z.ai | `ZAI_API_KEY` |
| Mistral | `MISTRAL_API_KEY` |
| Ollama | optional `OLLAMA_HOST` |
| NVIDIA | `NVIDIA_API_KEY` |
| Cloudflare | `CLOUDFLARE_AI_TOKEN` or `CLOUDFLARE_API_TOKEN`; optional `CLOUDFLARE_ACCOUNT_ID` |
| Vertex AI | optional `GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`, or `VERTEXAI_PROJECT` |
| BytePlus | `BYTEPLUS_API_KEY` or `ARK_API_KEY` |
| Qwen | `DASHSCOPE_API_KEY` or `QWEN_API_KEY`; optional `DASHSCOPE_WORKSPACE_ID` |
| Together | `TOGETHER_API_KEY` |
| Groq | `GROQ_API_KEY` |
| Cohere | `COHERE_API_KEY` |
| Replicate | `REPLICATE_API_TOKEN` |
| Fireworks | `FIREWORKS_API_KEY` |
| AI21 | `AI21_API_KEY` |
| xAI | `XAI_API_KEY` |
| Kilo | `KILO_API_KEY` |

Environment variables must be present in the process that starts DMS. Shell-only exports may not reach a graphical session.

## Notifications

| Setting | Values | Default |
| --- | --- | --- |
| Quota notifications | enabled or disabled | enabled |
| Global notification threshold | 75%, 85%, or 95% | 85% |
| Per-provider thresholds | comma-separated `provider:percent` pairs (e.g. `claude:90,codex:75`) | empty |
| Re-alert interval | 0 (once per window), 15, 30, 60 minutes | 0 |

## History

| Setting | Values | Default |
| --- | --- | --- |
| Usage history retention | 500, 2,000, or 10,000 snapshots | 2,000 |

Snapshots are written to `~/.cache/AiControlCenter/usage-history.jsonl` and drive the sparklines and trend arrows on provider cards.

## Health indicators

The settings page executes `providers/get-provider-health` for selected providers:

- Green: required CLI, local database, or environment variable is present.
- Amber: a prerequisite is missing.
- Neutral: informational provider or no check is applicable.

Health checks do not send network requests and never print secret values.
