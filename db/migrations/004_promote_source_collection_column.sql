-- migrate:up

-- ============================================================
-- news_sources.collection
--
-- Promotes the single most important routing field out of
-- metadata jsonb into a real, constrained column. AUT-4's
-- collectors route on source_type + collection; burying that
-- inside metadata made the registry hard to read at a glance
-- and easy to misconfigure (a typo inside a JSON blob fails
-- silently at run time, not at insert time).
-- ============================================================

ALTER TABLE ai_intel.news_sources
    ADD COLUMN collection TEXT;

UPDATE ai_intel.news_sources
SET collection = metadata->>'collection'
WHERE metadata ? 'collection';

ALTER TABLE ai_intel.news_sources
    ALTER COLUMN collection SET NOT NULL;

ALTER TABLE ai_intel.news_sources
    ADD CONSTRAINT news_sources_collection_check
    CHECK (
        collection IN (
            'releases',
            'organization',
            'feed',
            'changelog',
            'release_notes',
            'announcements',
            'blog',
            'news',
            'docs',
            'product',
            'queries'
        )
    );

-- Superseded by the column + CHECK above.
ALTER TABLE ai_intel.news_sources
    DROP CONSTRAINT IF EXISTS news_sources_metadata_collection_required;


-- ============================================================
-- news_sources.feed_url / news_sources.page_hash
--
-- These are written back by the collectors at run time (Web
-- Feed discovers feed_url once; Web Monitor updates page_hash
-- after every scrape). They previously lived inside the same
-- metadata object seeds/seed_sources.sql hand-edits and
-- rewrites wholesale on every reseed
-- (`metadata = EXCLUDED.metadata`) -- meaning a routine reseed
-- would silently erase discovered feed URLs and content hashes.
-- Dedicated columns seeds never touch removes that collision
-- entirely and makes clear at a glance which fields are
-- collector-owned vs. human-configured.
-- ============================================================

ALTER TABLE ai_intel.news_sources
    ADD COLUMN feed_url TEXT;

ALTER TABLE ai_intel.news_sources
    ADD COLUMN page_hash TEXT;

UPDATE ai_intel.news_sources
SET feed_url = metadata->>'feed_url'
WHERE metadata ? 'feed_url';

UPDATE ai_intel.news_sources
SET page_hash = metadata->>'page_hash'
WHERE metadata ? 'page_hash';

-- Strip the three promoted keys out of metadata now that they
-- live elsewhere. What remains is exclusively human-configured
-- tuning (vendor, homepage, focus, notes, lookback_hours,
-- queries, max_repos, ...).
UPDATE ai_intel.news_sources
SET metadata = metadata - 'collection' - 'feed_url' - 'page_hash';


-- migrate:down

UPDATE ai_intel.news_sources
SET metadata = metadata
    || jsonb_build_object('collection', collection)
    || CASE WHEN feed_url IS NOT NULL
            THEN jsonb_build_object('feed_url', feed_url)
            ELSE '{}'::jsonb END
    || CASE WHEN page_hash IS NOT NULL
            THEN jsonb_build_object('page_hash', page_hash)
            ELSE '{}'::jsonb END;

ALTER TABLE ai_intel.news_sources
    DROP COLUMN IF EXISTS page_hash;

ALTER TABLE ai_intel.news_sources
    DROP COLUMN IF EXISTS feed_url;

ALTER TABLE ai_intel.news_sources
    DROP CONSTRAINT IF EXISTS news_sources_collection_check;

ALTER TABLE ai_intel.news_sources
    DROP COLUMN IF EXISTS collection;

ALTER TABLE ai_intel.news_sources
    ADD CONSTRAINT news_sources_metadata_collection_required
    CHECK (metadata ? 'collection');
