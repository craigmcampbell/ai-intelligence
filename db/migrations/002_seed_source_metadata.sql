-- migrate:up

-- ============================================================
-- Normalize metadata for the original four seeded sources.
--
-- Metadata convention:
--
-- {
--   "collection": "<collector behavior>",
--   "vendor": "<organization/project>",
--   "homepage": "<canonical product/site URL>",
--   "focus": ["topics", "worth", "prioritizing"],
--   "notes": "<optional collector guidance>"
-- }
--
-- collection values currently expected by AUT-4:
--
--   releases       GitHub repository releases
--   changelog      Product changelog page
--   release_notes  Curated release notes
--   blog           Official blog
--   news           Official news feed
--   announcements  Official announcements
--   organization   GitHub organization discovery
--   docs           Documentation changes
--   product        Product page requiring discovery support
--
-- ============================================================


-- ------------------------------------------------------------
-- OpenRouter
-- ------------------------------------------------------------

UPDATE ai_intel.news_sources
SET metadata = '{
    "collection": "announcements",
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
}'::jsonb,
    updated_at = NOW()
WHERE source_type = 'web'
  AND source_locator = 'https://openrouter.ai/announcements';


-- ------------------------------------------------------------
-- Ollama
-- ------------------------------------------------------------

UPDATE ai_intel.news_sources
SET metadata = '{
    "collection": "releases",
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
}'::jsonb,
    updated_at = NOW()
WHERE source_type = 'github'
  AND source_locator = 'ollama/ollama';


-- ------------------------------------------------------------
-- Open WebUI
-- ------------------------------------------------------------

UPDATE ai_intel.news_sources
SET metadata = '{
    "collection": "releases",
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
}'::jsonb,
    updated_at = NOW()
WHERE source_type = 'github'
  AND source_locator = 'open-webui/open-webui';


-- ------------------------------------------------------------
-- n8n
-- ------------------------------------------------------------

UPDATE ai_intel.news_sources
SET metadata = '{
    "collection": "releases",
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
}'::jsonb,
    updated_at = NOW()
WHERE source_type = 'github'
  AND source_locator = 'n8n-io/n8n';


-- migrate:down

-- Restore the original minimal metadata state.
--
-- This rollback intentionally preserves the rows themselves and
-- only removes the metadata introduced by this migration.

UPDATE ai_intel.news_sources
SET metadata = '{}'::jsonb,
    updated_at = NOW()
WHERE
    (source_type = 'web'
        AND source_locator = 'https://openrouter.ai/announcements')
    OR
    (source_type = 'github'
        AND source_locator = 'ollama/ollama')
    OR
    (source_type = 'github'
        AND source_locator = 'open-webui/open-webui')
    OR
    (source_type = 'github'
        AND source_locator = 'n8n-io/n8n');
