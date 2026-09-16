-- migrate:up

-- ============================================================
-- scoring_config
--
-- Versioned scoring weights, inclusion threshold, and model
-- selection for AI News - Score. One row per scoring_version.
-- news_scores.scoring_version references this so a later change
-- to weights or threshold never makes historical scores mean
-- something different retroactively -- old scores stay
-- interpretable against the config that actually produced them.
-- ============================================================

CREATE TABLE ai_intel.scoring_config (
    scoring_version TEXT PRIMARY KEY,

    weight_relevance NUMERIC(4,3) NOT NULL
        CHECK (weight_relevance BETWEEN 0 AND 1),

    weight_developer_impact NUMERIC(4,3) NOT NULL
        CHECK (weight_developer_impact BETWEEN 0 AND 1),

    weight_workflow_impact NUMERIC(4,3) NOT NULL
        CHECK (weight_workflow_impact BETWEEN 0 AND 1),

    weight_importance NUMERIC(4,3) NOT NULL
        CHECK (weight_importance BETWEEN 0 AND 1),

    weight_novelty NUMERIC(4,3) NOT NULL
        CHECK (weight_novelty BETWEEN 0 AND 1),

    inclusion_threshold NUMERIC(5,2) NOT NULL
        CHECK (inclusion_threshold BETWEEN 0 AND 100),

    classifier_model TEXT NOT NULL,

    editorial_model TEXT,

    notes TEXT,

    active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Weights are a formula, not a probability distribution --
    -- they do not need to sum to 1 in principle, but the v1
    -- design intentionally does, and drifting off that silently
    -- would quietly change what "final_score" means. Catch it
    -- at write time instead of during a confusing scoring review.
    CONSTRAINT scoring_config_weights_sum_to_one
        CHECK (
            ROUND(
                weight_relevance + weight_developer_impact
                + weight_workflow_impact + weight_importance
                + weight_novelty,
                3
            ) = 1.000
        )
);

CREATE INDEX idx_scoring_config_active
    ON ai_intel.scoring_config(active);

CREATE TRIGGER trg_scoring_config_updated_at
BEFORE UPDATE ON ai_intel.scoring_config
FOR EACH ROW
EXECUTE FUNCTION ai_intel.set_updated_at();

-- Seed v1 with the weights and threshold documented in Confluence.
INSERT INTO ai_intel.scoring_config (
    scoring_version,
    weight_relevance,
    weight_developer_impact,
    weight_workflow_impact,
    weight_importance,
    weight_novelty,
    inclusion_threshold,
    classifier_model,
    notes
) VALUES (
    'v1',
    0.25,
    0.25,
    0.20,
    0.20,
    0.10,
    60.00,
    'openai/gpt-4o-mini',
    'Initial weights per architecture doc. Tune against real scoring runs before changing -- increment scoring_version rather than editing this row in place, so historical scores stay comparable.'
);


-- ============================================================
-- item_research
--
-- Enrichment produced by AI News - Research (AUT-6), kept
-- separate from news_items so raw facts and analysis do not
-- blur together, and so re-running research never has to touch
-- collection data.
-- ============================================================

CREATE TABLE ai_intel.item_research (
    id BIGSERIAL PRIMARY KEY,

    news_item_id BIGINT NOT NULL
        REFERENCES ai_intel.news_items(id)
        ON DELETE CASCADE,

    authoritative_url TEXT,
    authoritative_title TEXT,
    authoritative_published_at TIMESTAMPTZ,

    factual_notes TEXT,

    corroborating_urls JSONB NOT NULL DEFAULT '[]'::jsonb,

    -- Same-event collapsing: multiple news_items describing one
    -- underlying announcement share a canonical_event_id so
    -- Publish can treat them as one story with several sources.
    canonical_event_id TEXT,

    verification_status TEXT NOT NULL DEFAULT 'unverified'
        CHECK (
            verification_status IN (
                'verified',
                'partial',
                'unverified'
            )
        ),

    researched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT item_research_news_item_unique
        UNIQUE (news_item_id)
);

CREATE INDEX idx_item_research_news_item
    ON ai_intel.item_research(news_item_id);

CREATE INDEX idx_item_research_canonical_event
    ON ai_intel.item_research(canonical_event_id)
    WHERE canonical_event_id IS NOT NULL;

CREATE INDEX idx_item_research_verification_status
    ON ai_intel.item_research(verification_status);

CREATE TRIGGER trg_item_research_updated_at
BEFORE UPDATE ON ai_intel.item_research
FOR EACH ROW
EXECUTE FUNCTION ai_intel.set_updated_at();


-- ============================================================
-- runs
--
-- Durable operational visibility per AI News - Daily execution
-- (AUT-8). Child-workflow return values alone are not durable
-- enough to debug a failed night after the fact.
-- ============================================================

CREATE TABLE ai_intel.runs (
    id BIGSERIAL PRIMARY KEY,

    run_id TEXT NOT NULL,

    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,

    status TEXT NOT NULL DEFAULT 'running'
        CHECK (
            status IN (
                'running',
                'success',
                'partial',
                'failed'
            )
        ),

    collection_window_start TIMESTAMPTZ,
    collection_window_end TIMESTAMPTZ,

    sources_attempted INTEGER,
    sources_succeeded INTEGER,
    sources_failed INTEGER,

    candidates_found INTEGER,
    duplicates_rejected INTEGER,
    items_scored INTEGER,
    items_above_threshold INTEGER,
    items_researched INTEGER,
    items_published INTEGER,

    error_summary TEXT,

    model_cost_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT runs_run_id_unique
        UNIQUE (run_id)
);

CREATE INDEX idx_runs_started_at
    ON ai_intel.runs(started_at DESC);

CREATE INDEX idx_runs_status
    ON ai_intel.runs(status);


-- ============================================================
-- feedback
--
-- Reader judgement (AUT-9), so relevance can eventually be
-- tuned against real output rather than guesswork.
-- ============================================================

CREATE TABLE ai_intel.feedback (
    id BIGSERIAL PRIMARY KEY,

    news_item_id BIGINT
        REFERENCES ai_intel.news_items(id)
        ON DELETE CASCADE,

    brief_id BIGINT
        REFERENCES ai_intel.daily_briefs(id)
        ON DELETE CASCADE,

    signal TEXT NOT NULL
        CHECK (
            signal IN (
                'useful',
                'too_noisy',
                'not_relevant',
                'missed_priority'
            )
        ),

    note TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT feedback_target_required
        CHECK (news_item_id IS NOT NULL OR brief_id IS NOT NULL)
);

CREATE INDEX idx_feedback_news_item
    ON ai_intel.feedback(news_item_id)
    WHERE news_item_id IS NOT NULL;

CREATE INDEX idx_feedback_brief
    ON ai_intel.feedback(brief_id)
    WHERE brief_id IS NOT NULL;

CREATE INDEX idx_feedback_signal
    ON ai_intel.feedback(signal);


-- ============================================================
-- news_items.rejection_reason
--
-- AUT-5's deterministic duplicate filter needs somewhere to
-- record WHY an item was rejected before any LLM call happens,
-- so a rejected item is queryable rather than buried in metadata.
-- ============================================================

ALTER TABLE ai_intel.news_items
    ADD COLUMN rejection_reason TEXT;


-- ============================================================
-- Category vocabularies
--
-- Confluence documents two distinct, deliberately separate
-- vocabularies: what KIND OF SOURCE this is (news_sources) vs.
-- what KIND OF STORY this is (news_scores). Neither column was
-- ever constrained in the database -- both were free TEXT.
-- Values below match what the seeds and the architecture doc
-- already use; this only makes the existing convention
-- enforced rather than advisory.
-- ============================================================

ALTER TABLE ai_intel.news_sources
    ADD CONSTRAINT news_sources_category_check
    CHECK (
        category IN (
            'agent_harness',
            'ide',
            'platform',
            'inference',
            'workflow',
            'protocol',
            'observability',
            'model_provider',
            'discovery'
        )
    );

ALTER TABLE ai_intel.news_scores
    ADD CONSTRAINT news_scores_category_check
    CHECK (
        category IN (
            'agent_harness',
            'platform_infra',
            'ide',
            'workflow_orchestration',
            'model_release',
            'industry'
        )
    );


-- ============================================================
-- news_sources metadata.collection required
--
-- AUT-4's collector routes on source_type + metadata.collection.
-- A source row missing collection is unroutable, and previously
-- failed silently at run time (the three search/discovery
-- sources shipped this way). Reject it at insert time instead.
-- ============================================================

ALTER TABLE ai_intel.news_sources
    ADD CONSTRAINT news_sources_metadata_collection_required
    CHECK (metadata ? 'collection');


-- migrate:down

ALTER TABLE ai_intel.news_sources
    DROP CONSTRAINT IF EXISTS news_sources_metadata_collection_required;

ALTER TABLE ai_intel.news_scores
    DROP CONSTRAINT IF EXISTS news_scores_category_check;

ALTER TABLE ai_intel.news_sources
    DROP CONSTRAINT IF EXISTS news_sources_category_check;

ALTER TABLE ai_intel.news_items
    DROP COLUMN IF EXISTS rejection_reason;

DROP TABLE IF EXISTS ai_intel.feedback;

DROP TABLE IF EXISTS ai_intel.runs;

DROP TRIGGER IF EXISTS trg_item_research_updated_at
    ON ai_intel.item_research;
DROP TABLE IF EXISTS ai_intel.item_research;

DROP TRIGGER IF EXISTS trg_scoring_config_updated_at
    ON ai_intel.scoring_config;
DROP TABLE IF EXISTS ai_intel.scoring_config;
