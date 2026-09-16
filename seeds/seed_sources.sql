-- ============================================================
-- IDENTITY MIGRATIONS
-- ON CONFLICT below keys on (source_type, source_locator), so a source
-- whose type or locator changes can't be matched by the INSERT and would
-- otherwise leave a stale duplicate row behind on every future reseed.
-- Each migration here converts the old row onto its new identity first;
-- the WHERE clause matches nothing once already applied, so these are
-- safe to leave in permanently and safe to re-run any number of times.
-- ============================================================

UPDATE ai_intel.news_sources
SET source_type = 'rss',
    source_locator = 'https://mistral.ai/news/rss',
    updated_at = NOW()
WHERE source_type = 'web' AND source_locator = 'https://mistral.ai/news';


INSERT INTO ai_intel.news_sources
(
    name,
    source_type,
    source_locator,
    category,
    priority,
    enabled,
    collection,
    metadata
)
VALUES

-- ============================================================
-- AGENT HARNESSES / CODING AGENTS
-- Highest priority
-- ============================================================

(
    'OpenCode',
    'github',
    'anomalyco/opencode',
    'agent_harness',
    100,
    TRUE,
    'releases',
    '{
        "homepage": "https://opencode.ai",
        "notes": "Primary OpenCode repository"
    }'::jsonb
),

(
    'OpenCode Changelog',
    'web',
    'https://dev.opencode.ai/changelog',
    'agent_harness',
    100,
    TRUE,
    'changelog',
    '{
        "product": "OpenCode"
    }'::jsonb
),

(
    'DeepSeek Harness',
    'github',
    'deepseek-ai/deepseek-harness',
    'agent_harness',
    98,
    TRUE,
    'releases',
    '{
        "homepage": "https://deepseek.com/harness",
        "notes": "Developer-preview plugin-based agent harness"
    }'::jsonb
),

(
    'Hermes Agent',
    'github',
    'NousResearch/hermes-agent',
    'agent_harness',
    98,
    TRUE,
    'releases',
    '{
        "notes": "Nous Research agent platform"
    }'::jsonb
),

(
    'Claude Code',
    'web',
    'https://docs.anthropic.com/en/docs/claude-code',
    'agent_harness',
    98,
    TRUE,
    'docs',
    '{
        "vendor": "Anthropic",
        "discovery_required": true
    }'::jsonb
),

(
    'OpenAI Codex',
    'web',
    'https://openai.com/codex/',
    'agent_harness',
    98,
    TRUE,
    'product',
    '{
        "vendor": "OpenAI",
        "discovery_required": true
    }'::jsonb
),


-- ============================================================
-- AI IDEs / DEVELOPER ENVIRONMENTS
-- Highest priority
-- ============================================================

(
    'Cursor',
    'web',
    'https://www.cursor.com/changelog',
    'ide',
    100,
    TRUE,
    'changelog',
    '{
        "vendor": "Cursor"
    }'::jsonb
),

(
    'Windsurf',
    'web',
    'https://windsurf.com/changelog',
    'ide',
    95,
    TRUE,
    'changelog',
    '{
        "vendor": "Windsurf"
    }'::jsonb
),

(
    'Visual Studio Code',
    'web',
    'https://code.visualstudio.com/updates',
    'ide',
    92,
    TRUE,
    'changelog',
    '{
        "vendor": "Microsoft",
        "focus": [
            "copilot",
            "agents",
            "mcp",
            "model support",
            "tool use"
        ]
    }'::jsonb
),

(
    'GitHub Copilot',
    'web',
    'https://github.blog/changelog/label/copilot/',
    'ide',
    95,
    TRUE,
    'changelog',
    '{
        "vendor": "GitHub"
    }'::jsonb
),

(
    'JetBrains AI',
    'web',
    'https://www.jetbrains.com/ai/',
    'ide',
    88,
    TRUE,
    'product',
    '{
        "vendor": "JetBrains",
        "discovery_required": true
    }'::jsonb
),

(
    'Zed',
    'github',
    'zed-industries/zed',
    'ide',
    85,
    TRUE,
    'releases',
    '{
        "focus": [
            "agent features",
            "assistant",
            "models",
            "mcp"
        ]
    }'::jsonb
),


-- ============================================================
-- AI PLATFORMS / GATEWAYS / LOCAL AI
-- Highest priority
-- ============================================================

(
    'OpenRouter',
    'web',
    'https://openrouter.ai/announcements',
    'platform',
    100,
    TRUE,
    'announcements',
    '{
        "vendor": "OpenRouter",
        "homepage": "https://openrouter.ai",
        "focus": [
            "model availability",
            "model routing",
            "API changes",
            "tool use",
            "MCP",
            "agent infrastructure",
            "pricing",
            "provider changes",
            "developer features",
            "acquisitions",
            "partnerships"
        ],
        "notes": "Treat official announcements as Tier 1 sources. Prioritize changes affecting model access, routing, APIs, tooling, pricing, or developer workflows."
    }'::jsonb
),

(
    'Ollama',
    'github',
    'ollama/ollama',
    'platform',
    100,
    TRUE,
    'releases',
    '{
        "vendor": "Ollama",
        "homepage": "https://ollama.com",
        "repository": "ollama/ollama",
        "focus": [
            "model support",
            "tool use",
            "agent harness support",
            "API compatibility",
            "OpenAI compatibility",
            "local inference",
            "performance",
            "context handling",
            "multimodal support",
            "developer tooling"
        ],
        "notes": "Collect GitHub releases. Scoring should suppress routine patches unless they introduce meaningful model, API, inference, or workflow capabilities."
    }'::jsonb
),

(
    'Open WebUI',
    'github',
    'open-webui/open-webui',
    'platform',
    100,
    TRUE,
    'releases',
    '{
        "vendor": "Open WebUI",
        "homepage": "https://openwebui.com",
        "repository": "open-webui/open-webui",
        "focus": [
            "model integrations",
            "agent features",
            "tools",
            "functions",
            "pipelines",
            "MCP",
            "OpenRouter",
            "image generation",
            "observability",
            "authentication",
            "deployment",
            "developer workflow"
        ],
        "notes": "Collect GitHub releases. Prioritize changes affecting integrations, agent workflows, functions, pipelines, model providers, deployment, or administration over cosmetic UI changes."
    }'::jsonb
),

(
    'Hugging Face',
    'web',
    'https://huggingface.co/blog',
    'platform',
    95,
    TRUE,
    'blog',
    '{
        "focus": [
            "developer platform",
            "inference",
            "agents",
            "models",
            "open source"
        ]
    }'::jsonb
),

(
    'Hugging Face Transformers',
    'github',
    'huggingface/transformers',
    'platform',
    90,
    TRUE,
    'releases',
    '{}'::jsonb
),

(
    'llama.cpp',
    'github',
    'ggml-org/llama.cpp',
    'inference',
    90,
    TRUE,
    'releases',
    '{
        "notes": "High release frequency; scoring should suppress routine build-only releases"
    }'::jsonb
),

(
    'vLLM',
    'github',
    'vllm-project/vllm',
    'inference',
    90,
    TRUE,
    'releases',
    '{}'::jsonb
),


-- ============================================================
-- WORKFLOW / ORCHESTRATION / AGENT INFRASTRUCTURE
-- ============================================================

(
    'n8n',
    'github',
    'n8n-io/n8n',
    'workflow',
    100,
    TRUE,
    'releases',
    '{
        "vendor": "n8n",
        "homepage": "https://n8n.io",
        "repository": "n8n-io/n8n",
        "focus": [
            "AI workflows",
            "agents",
            "MCP",
            "LLM integrations",
            "workflow orchestration",
            "nodes",
            "credentials",
            "webhooks",
            "execution",
            "scaling",
            "observability",
            "developer tooling"
        ],
        "notes": "Collect GitHub releases. Prefer meaningful workflow, AI, integration, execution, and platform changes. Routine patches should generally score low."
    }'::jsonb
),

(
    'n8n Release Notes',
    'web',
    'https://docs.n8n.io/release-notes/',
    'workflow',
    100,
    TRUE,
    'release_notes',
    '{
        "notes": "Prefer feature-level release notes over raw patch noise"
    }'::jsonb
),

(
    'LangGraph',
    'github',
    'langchain-ai/langgraph',
    'workflow',
    88,
    TRUE,
    'releases',
    '{}'::jsonb
),

(
    'Model Context Protocol',
    'web',
    'https://modelcontextprotocol.io',
    'protocol',
    100,
    TRUE,
    'docs',
    '{
        "focus": [
            "specification",
            "protocol changes",
            "SDK changes",
            "ecosystem announcements"
        ]
    }'::jsonb
),

(
    'Model Context Protocol GitHub',
    'github',
    'modelcontextprotocol',
    'protocol',
    98,
    TRUE,
    'organization',
    '{
        "notes": "Track important MCP repositories and SDK releases"
    }'::jsonb
),


-- ============================================================
-- OBSERVABILITY / AI ENGINEERING
-- ============================================================

(
    'Langfuse',
    'github',
    'langfuse/langfuse',
    'observability',
    92,
    TRUE,
    'releases',
    '{
        "focus": [
            "tracing",
            "evals",
            "OpenTelemetry",
            "agent observability"
        ]
    }'::jsonb
),

(
    'OpenTelemetry',
    'web',
    'https://opentelemetry.io/blog/',
    'observability',
    75,
    TRUE,
    'blog',
    '{
        "focus": [
            "genai",
            "llm",
            "semantic conventions"
        ]
    }'::jsonb
),


-- ============================================================
-- MAJOR MODEL / API PROVIDERS
-- These matter, but scoring should prevent routine corporate
-- news from flooding the brief.
-- ============================================================

(
    'OpenAI',
    'web',
    'https://openai.com/news/',
    'model_provider',
    95,
    TRUE,
    'news',
    '{
        "focus": [
            "models",
            "API",
            "Codex",
            "agents",
            "developer tools"
        ]
    }'::jsonb
),

(
    'Anthropic',
    'web',
    'https://www.anthropic.com/news',
    'model_provider',
    95,
    TRUE,
    'news',
    '{
        "focus": [
            "Claude",
            "Claude Code",
            "API",
            "agents",
            "developer platform"
        ]
    }'::jsonb
),

(
    'Google AI',
    'web',
    'https://blog.google/technology/ai/',
    'model_provider',
    92,
    TRUE,
    'news',
    '{
        "focus": [
            "Gemini",
            "developer tools",
            "API",
            "agents"
        ]
    }'::jsonb
),

(
    'Google AI Developers',
    'web',
    'https://developers.googleblog.com/',
    'model_provider',
    92,
    TRUE,
    'blog',
    '{
        "focus": [
            "Gemini API",
            "AI Studio",
            "developer tooling",
            "models"
        ]
    }'::jsonb
),

(
    'Mistral AI',
    'rss',
    'https://mistral.ai/news/rss',
    'model_provider',
    88,
    TRUE,
    'feed',
    '{
        "focus": [
            "models",
            "API",
            "coding",
            "agents",
            "open weights"
        ]
    }'::jsonb
),

(
    'Meta AI',
    'web',
    'https://ai.meta.com/blog/',
    'model_provider',
    85,
    TRUE,
    'blog',
    '{
        "focus": [
            "Llama",
            "open models",
            "developer infrastructure"
        ]
    }'::jsonb
),

(
    'Qwen',
    'github',
    'QwenLM',
    'model_provider',
    85,
    TRUE,
    'organization',
    '{
        "focus": [
            "model releases",
            "coding models",
            "agent models"
        ]
    }'::jsonb
),


-- ============================================================
-- DISCOVERY SOURCES
-- Lower priority because these discover events rather than act
-- as authoritative evidence.
-- ============================================================

(
    'AI Developer News Discovery',
    'search',
    'ai-developer-news',
    'discovery',
    70,
    TRUE,
    'queries',
    '{
        "queries": [
            "AI coding agent release",
            "AI IDE release",
            "agent harness release",
            "developer AI platform launch",
            "LLM developer tooling acquisition",
            "MCP developer tooling",
            "AI workflow orchestration",
            "open source AI agent release",
            "OpenRouter Ollama Hugging Face ecosystem news",
            "AI inference platform release"
        ]
    }'::jsonb
),

(
    'Model Release Discovery',
    'search',
    'model-release-news',
    'discovery',
    65,
    TRUE,
    'queries',
    '{
        "queries": [
            "new AI model release coding",
            "open weights model release",
            "LLM tool use model release",
            "agentic model release",
            "reasoning model release developer API"
        ]
    }'::jsonb
),

(
    'AI Industry Discovery',
    'search',
    'ai-industry-news',
    'discovery',
    60,
    TRUE,
    'queries',
    '{
        "queries": [
            "AI developer tools acquisition",
            "AI infrastructure acquisition",
            "AI coding company acquisition",
            "AI platform major partnership",
            "AI developer platform funding"
        ]
    }'::jsonb
)

ON CONFLICT (source_type, source_locator)
DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    priority = EXCLUDED.priority,
    enabled = EXCLUDED.enabled,
    collection = EXCLUDED.collection,
    metadata = EXCLUDED.metadata;
