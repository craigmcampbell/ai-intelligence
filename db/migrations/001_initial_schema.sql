-- migrate:up

CREATE SCHEMA IF NOT EXISTS ai_intel;

-- ============================================================
-- news_sources
--
-- Registry of sources monitored by the collection workflows.
-- Adding a new source should generally be a data/config change,
-- not an n8n workflow change.
-- ============================================================

CREATE TABLE ai_intel.news_sources (
    id BIGSERIAL PRIMARY KEY,

    name TEXT NOT NULL,

    source_type TEXT NOT NULL
        CHECK (
            source_type IN (
                'github',
                'rss',
                'api',
                'search',
                'web'
            )
        ),

    source_locator TEXT NOT NULL,

    category TEXT NOT NULL,

    priority INTEGER NOT NULL DEFAULT 50
        CHECK (priority BETWEEN 0 AND 100),

    enabled BOOLEAN NOT NULL DEFAULT TRUE,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    last_success_at TIMESTAMPTZ,
    last_error_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT news_sources_source_unique
        UNIQUE (source_type, source_locator)
);

CREATE INDEX idx_news_sources_enabled
    ON ai_intel.news_sources(enabled);

CREATE INDEX idx_news_sources_category
    ON ai_intel.news_sources(category);

CREATE INDEX idx_news_sources_priority
    ON ai_intel.news_sources(priority DESC);


-- ============================================================
-- news_items
--
-- Normalized stories/items discovered by collection workflows.
-- Multiple source types eventually resolve into this common
-- representation.
-- ============================================================

CREATE TABLE ai_intel.news_items (
    id BIGSERIAL PRIMARY KEY,

    source_id BIGINT NOT NULL
        REFERENCES ai_intel.news_sources(id)
        ON DELETE RESTRICT,

    external_id TEXT,

    canonical_url TEXT,

    title TEXT NOT NULL,

    raw_summary TEXT,

    published_at TIMESTAMPTZ,

    discovered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    content_hash TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'candidate'
        CHECK (
            status IN (
                'candidate',
                'rejected',
                'research',
                'published'
            )
        ),

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- A source should not produce the same externally identified
-- item more than once.
CREATE UNIQUE INDEX idx_news_items_source_external_id
    ON ai_intel.news_items(source_id, external_id)
    WHERE external_id IS NOT NULL;

-- Canonical URLs provide another deterministic deduplication
-- mechanism.
CREATE UNIQUE INDEX idx_news_items_canonical_url
    ON ai_intel.news_items(canonical_url)
    WHERE canonical_url IS NOT NULL;

CREATE INDEX idx_news_items_source_id
    ON ai_intel.news_items(source_id);

CREATE INDEX idx_news_items_status
    ON ai_intel.news_items(status);

CREATE INDEX idx_news_items_published_at
    ON ai_intel.news_items(published_at DESC);

CREATE INDEX idx_news_items_discovered_at
    ON ai_intel.news_items(discovered_at DESC);

CREATE INDEX idx_news_items_content_hash
    ON ai_intel.news_items(content_hash);


-- ============================================================
-- news_scores
--
-- Stores AI relevance/scoring results.
--
-- Scores are deliberately persisted rather than overwriting
-- news_items so scoring algorithms can be versioned and
-- recalculated later.
-- ============================================================

CREATE TABLE ai_intel.news_scores (
    id BIGSERIAL PRIMARY KEY,

    news_item_id BIGINT NOT NULL
        REFERENCES ai_intel.news_items(id)
        ON DELETE CASCADE,

    scoring_version TEXT NOT NULL,

    relevance SMALLINT NOT NULL
        CHECK (relevance BETWEEN 0 AND 100),

    importance SMALLINT NOT NULL
        CHECK (importance BETWEEN 0 AND 100),

    novelty SMALLINT NOT NULL
        CHECK (novelty BETWEEN 0 AND 100),

    developer_impact SMALLINT NOT NULL
        CHECK (developer_impact BETWEEN 0 AND 100),

    workflow_impact SMALLINT NOT NULL
        CHECK (workflow_impact BETWEEN 0 AND 100),

    final_score NUMERIC(5,2) NOT NULL
        CHECK (final_score BETWEEN 0 AND 100),

    category TEXT NOT NULL,

    keep BOOLEAN NOT NULL,

    reason TEXT NOT NULL,

    needs_verification BOOLEAN NOT NULL DEFAULT FALSE,

    raw_model_output JSONB,

    scored_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT news_scores_item_version_unique
        UNIQUE (news_item_id, scoring_version)
);

CREATE INDEX idx_news_scores_news_item
    ON ai_intel.news_scores(news_item_id);

CREATE INDEX idx_news_scores_final_score
    ON ai_intel.news_scores(final_score DESC);

CREATE INDEX idx_news_scores_keep
    ON ai_intel.news_scores(keep);

CREATE INDEX idx_news_scores_category
    ON ai_intel.news_scores(category);

CREATE INDEX idx_news_scores_scored_at
    ON ai_intel.news_scores(scored_at DESC);


-- ============================================================
-- daily_briefs
--
-- Stores the final generated daily intelligence briefing.
-- The brief is persisted before delivery so generation and
-- delivery are independent operations.
-- ============================================================

CREATE TABLE ai_intel.daily_briefs (
    id BIGSERIAL PRIMARY KEY,

    brief_date DATE NOT NULL,

    content_markdown TEXT NOT NULL,

    editor_model TEXT NOT NULL,

    stats JSONB NOT NULL DEFAULT '{}'::jsonb,

    delivery_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            delivery_status IN (
                'pending',
                'delivered',
                'failed'
            )
        ),

    delivery_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT daily_briefs_brief_date_unique
        UNIQUE (brief_date)
);

CREATE INDEX idx_daily_briefs_brief_date
    ON ai_intel.daily_briefs(brief_date DESC);

CREATE INDEX idx_daily_briefs_delivery_status
    ON ai_intel.daily_briefs(delivery_status);


-- ============================================================
-- daily_brief_items
--
-- Join table recording exactly which news items were included
-- in each daily brief and their editorial ordering.
-- ============================================================

CREATE TABLE ai_intel.daily_brief_items (
    brief_id BIGINT NOT NULL
        REFERENCES ai_intel.daily_briefs(id)
        ON DELETE CASCADE,

    news_item_id BIGINT NOT NULL
        REFERENCES ai_intel.news_items(id)
        ON DELETE RESTRICT,

    display_order INTEGER NOT NULL
        CHECK (display_order > 0),

    recommendation TEXT
        CHECK (
            recommendation IS NULL
            OR recommendation IN (
                'TRY',
                'WATCH',
                'ADOPT',
                'IGNORE',
                'REPLACE'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (brief_id, news_item_id),

    CONSTRAINT daily_brief_items_order_unique
        UNIQUE (brief_id, display_order)
);

CREATE INDEX idx_daily_brief_items_news_item
    ON ai_intel.daily_brief_items(news_item_id);


-- ============================================================
-- updated_at trigger
--
-- Automatically maintain updated_at rather than requiring
-- every n8n workflow to remember to set it.
-- ============================================================

CREATE OR REPLACE FUNCTION ai_intel.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_news_sources_updated_at
BEFORE UPDATE ON ai_intel.news_sources
FOR EACH ROW
EXECUTE FUNCTION ai_intel.set_updated_at();


CREATE TRIGGER trg_news_items_updated_at
BEFORE UPDATE ON ai_intel.news_items
FOR EACH ROW
EXECUTE FUNCTION ai_intel.set_updated_at();


CREATE TRIGGER trg_daily_briefs_updated_at
BEFORE UPDATE ON ai_intel.daily_briefs
FOR EACH ROW
EXECUTE FUNCTION ai_intel.set_updated_at();


-- migrate:down

DROP TRIGGER IF EXISTS trg_daily_briefs_updated_at
    ON ai_intel.daily_briefs;

DROP TRIGGER IF EXISTS trg_news_items_updated_at
    ON ai_intel.news_items;

DROP TRIGGER IF EXISTS trg_news_sources_updated_at
    ON ai_intel.news_sources;

DROP FUNCTION IF EXISTS ai_intel.set_updated_at();

DROP TABLE IF EXISTS ai_intel.daily_brief_items;
DROP TABLE IF EXISTS ai_intel.daily_briefs;
DROP TABLE IF EXISTS ai_intel.news_scores;
DROP TABLE IF EXISTS ai_intel.news_items;
DROP TABLE IF EXISTS ai_intel.news_sources;

DROP SCHEMA IF EXISTS ai_intel;