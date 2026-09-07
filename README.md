# AI Developer Intelligence

A high-signal AI news and developer-intelligence pipeline built with **n8n**, **PostgreSQL**, and **OpenRouter**, hosted on **Railway**.

The system collects developments across the AI developer ecosystem, filters out low-value noise, researches significant stories using authoritative sources, and produces a concise daily briefing focused on one question:

> **What changed since the last run that is worth a developer or AI workflow designer paying attention to?**

The goal is not to create another AI newsletter. The goal is to build a personalized intelligence pipeline that identifies developments likely to change how AI-powered software is built or how the developer workflow operates.

## Architecture

The system is divided into several independent n8n workflows coordinated by a daily orchestrator.

```text
                     ┌─────────────────────┐
                     │   Daily Schedule    │
                     └──────────┬──────────┘
                                │
                                ▼
                     ┌─────────────────────┐
                     │   AI News — Daily   │
                     └──────────┬──────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
       ┌────────────┐     ┌────────────┐    ┌────────────┐
       │  Collect   │ ──▶ │   Score    │ ─▶ │  Research  │
       └────────────┘     └────────────┘    └──────┬─────┘
                                                   │
                                                   ▼
                                            ┌────────────┐
                                            │  Publish   │
                                            └────────────┘
```

### AI News — Collect

Collects candidate stories from configured sources.

Primary sources are preferred whenever possible:

- GitHub releases
- Official changelogs
- Official product blogs
- RSS/Atom feeds
- Product and platform APIs

Discovery search supplements direct sources so significant developments outside the known source registry can still be found.

All collected information is normalized into a common `news_items` representation before entering the rest of the pipeline.

### AI News — Score

Evaluates candidate stories for relevance using an inexpensive model accessed through OpenRouter.

Each candidate receives scores for:

- relevance
- importance
- novelty
- developer impact
- workflow impact

The final score is calculated deterministically:

```text
final_score =
    relevance        * 0.25 +
    developer_impact * 0.25 +
    workflow_impact  * 0.20 +
    importance       * 0.20 +
    novelty          * 0.10
```

The default publication/research threshold is **60**.

The model does not calculate the final score. It supplies the individual dimensions, and application logic performs the weighted calculation.

Scoring is versioned so changes to models, prompts, weights, or classification strategies can be evaluated without destroying historical results.

### AI News — Research

Researches candidates that pass the relevance threshold or otherwise require verification.

The research stage:

1. Locates the authoritative source.
2. Fetches the underlying announcement or documentation.
3. Extracts factual information.
4. Verifies consequential claims.
5. Separates sourced facts from analysis.
6. Records authoritative source URLs for later citation.

Acquisitions, major partnerships, funding announcements, and similar business claims should use an independent credible source in addition to the primary announcement when practical.

Search results and LLM internal knowledge are never treated as authoritative evidence.

### AI News — Publish

Uses a stronger editorial model through OpenRouter to transform researched items into the daily briefing.

The editor receives structured, researched information rather than being asked to independently discover facts.

The resulting briefing contains:

#### Top Signal

The most important developments of the day.

Target: 3–7 stories.

There is deliberately no minimum. If only one development is genuinely important, the brief should contain one rather than manufacture significance.

#### Toolchain Watch

Changes affecting tools and platforms currently relevant to the developer workflow.

#### Industry

Acquisitions, partnerships, funding, licensing changes, consolidation, and other ecosystem developments with meaningful developer impact.

#### Worth Experimenting With

New tools, models, integrations, or techniques that appear worth hands-on evaluation.

#### Filter Statistics

Basic pipeline statistics showing how aggressively the system filtered the day's incoming information.

## Areas of Interest

The system prioritizes developments that materially affect software development and AI engineering workflows.

### Agent Harnesses and Coding Agents

Highest priority.

Examples include:

- OpenCode
- Claude Code
- Codex
- DeepSeek Harness
- Hermes Agent
- emerging agent harnesses and coding agents

Particularly important capabilities include:

- subagents
- skills
- MCP
- planning
- context management
- memory
- sandboxes
- scheduling
- model portability
- orchestration
- tool execution

### AI Developer Platforms and Infrastructure

Highest priority.

Examples include:

- OpenRouter
- Hugging Face
- Ollama
- Open WebUI
- llama.cpp
- vLLM

Important developments include model serving, routing, gateways, inference, observability, caching, tool APIs, MCP support, and local model infrastructure.

### IDEs and Developer Environments

Highest priority.

Examples include:

- Cursor
- Windsurf
- Visual Studio Code
- JetBrains IDEs
- Zed
- emerging AI-native development environments

Important changes include:

- agent modes
- background agents
- model support
- MCP
- planning
- terminal and tool access
- repository indexing
- context management
- code review workflows
- harness integrations
- meaningful pricing or usage-limit changes

### Workflow and Orchestration

Highest priority.

Examples include:

- n8n
- MCP ecosystem
- LangGraph
- agent orchestration platforms
- workflow automation
- observability and evaluation tooling

### Models

Model releases are included when they have meaningful practical implications.

Particular attention is given to:

- coding ability
- agentic/tool-use performance
- context capabilities
- inference requirements
- local deployment
- open weights
- cost changes
- platform availability

A benchmark result by itself is generally not sufficient to make the daily brief.

### Industry Developments

Tracked when they may materially affect the developer ecosystem.

Examples include:

- acquisitions
- major partnerships
- significant funding
- licensing changes
- platform consolidation
- strategic shifts by major AI companies

## Signal Philosophy

The pipeline intentionally favors **precision over recall**.

Missing an obscure AI announcement is preferable to producing a daily wall of low-value content.

Strong positive signals include:

- changes to tools actively used in the development workflow
- significant new agent capabilities
- meaningful IDE changes
- new model/tool integrations
- major inference or infrastructure improvements
- important acquisitions or ecosystem consolidation
- developments that create a reason to change or experiment with the current toolchain

Strong negative signals include:

- generic AI listicles
- SEO content
- benchmark-only announcements with no practical implications
- minor UI changes
- speculative opinion presented as news
- repetitive coverage of previously reported events
- insignificant funding announcements
- generic prompt-engineering content
- "AI will change everything" commentary without actionable information

## Editorial Recommendations

Stories may receive one of the following recommendations:

| Recommendation | Meaning |
| --- | --- |
| `TRY` | Worth experimenting with soon |
| `WATCH` | Important enough to monitor |
| `ADOPT` | Strong candidate for the active workflow |
| `IGNORE` | Interesting headline, little practical value |
| `REPLACE` | May justify replacing an existing tool or approach |

Recommendations are analysis, not sourced facts, and should always be presented separately from factual reporting.

## Infrastructure

The initial production deployment runs on Railway.

```text
Railway Project
│
├── n8n
│
└── PostgreSQL
```

Redis, queue workers, and distributed n8n execution are intentionally excluded from the initial architecture.

They should only be introduced if workload or reliability requirements demonstrate a need for them.

## Database

Application data is stored in the PostgreSQL schema:

```text
ai_intel
```

The initial schema contains:

```text
ai_intel.news_sources
ai_intel.news_items
ai_intel.news_scores
ai_intel.daily_briefs
ai_intel.daily_brief_items
```

Later migrations may introduce tables for run telemetry and editorial feedback.

### Database Migrations

Database migrations are managed using **dbmate**.

Migration files live under:

```text
db/migrations/
```

Example:

```text
db/
└── migrations/
    ├── 20260907120000_initial_schema.sql
    ├── 20260907130000_add_runs.sql
    └── 20260907140000_add_feedback.sql
```

Create a migration with:

```bash
dbmate new <migration-name>
```

Apply pending migrations with:

```bash
dbmate up
```

Roll back the most recently applied migration with:

```bash
dbmate down
```

Check migration status with:

```bash
dbmate status
```

dbmate maintains its own `schema_migrations` table in PostgreSQL. Application migrations should not create a separate migration-history mechanism.

A migration follows the standard dbmate structure:

```sql
-- migrate:up

-- SQL used to apply the migration

-- migrate:down

-- SQL used to reverse the migration
```

Applied migration files should be treated as immutable. Schema changes should be introduced through new migrations rather than modifying migrations that have already been applied to production.

## Source Registry

Tracked sources are stored in `ai_intel.news_sources`.

This is an intentional architectural decision.

Adding a new IDE, agent harness, platform, repository, RSS feed, or other source should normally require adding configuration to the source registry rather than modifying the n8n workflow itself.

Supported source types initially include:

```text
github
rss
api
search
web
```

Source-specific collector configuration can be stored in the source's `metadata` JSONB field.

This keeps collection logic generic while allowing individual sources to specify behavior such as release paths, feed configuration, lookback windows, or parsing options.

## Deduplication

The system uses multiple levels of deduplication.

### Deterministic Deduplication

Candidates can be identified using:

- source external ID
- canonical URL
- normalized content hash

These checks happen before spending LLM tokens.

### Event Deduplication

Different sources frequently report the same underlying event.

For example:

```text
OpenRouter announcement
        │
        ├── company blog
        ├── news article
        ├── GitHub update
        └── social/discovery result
```

These should ultimately represent one event in the briefing rather than four separate stories.

Semantic/event-level deduplication is performed after deterministic checks when necessary.

## Models

OpenRouter provides the model gateway for AI operations.

Different stages intentionally use different model classes.

```text
Collection       → no LLM
Deduplication    → deterministic first
Scoring          → inexpensive fast model
Research         → retrieval + targeted AI extraction
Editorial        → stronger reasoning/writing model
```

Model selection should remain configurable rather than being embedded throughout workflow logic.

## Secrets

Secrets must never be committed to this repository.

Infrastructure secrets belong in Railway environment variables.

Integration credentials used by workflows should normally be stored using n8n Credentials.

Examples include:

```text
OpenRouter API key
GitHub token
search provider API key
delivery credentials
database credentials
```

A `.env.example` may document required configuration, but it must contain placeholders only.

## Development Principles

Keep the system boring where boring is useful.

Prefer:

- PostgreSQL over workflow-local state
- configuration over hard-coded source logic
- deterministic logic before LLM calls
- structured model output over free-form parsing
- primary sources over summaries
- explicit scoring formulas over opaque model decisions
- idempotent workflows
- persisted state before external delivery
- small composable workflows over one enormous n8n graph

LLMs should perform tasks that benefit from semantic reasoning.

They should not be used to solve problems that SQL, hashing, HTTP, or straightforward application logic can solve more reliably.

## Project Roadmap

The initial implementation is tracked in Jira under the **AUT** project.

Current implementation sequence:

```text
AUT-1  AI Developer Intelligence — Daily Briefing
  │
  ├── AUT-2  Deploy n8n and PostgreSQL on Railway
  ├── AUT-3  Create database schema and source registry
  ├── AUT-4  Implement direct-source collection
  ├── AUT-5  Implement deduplication and relevance scoring
  ├── AUT-6  Add discovery and authoritative research
  ├── AUT-7  Implement editorial brief and delivery
  ├── AUT-8  Add orchestration, errors, and telemetry
  └── AUT-9  Tune signal quality and feedback
```

## Success Criteria

A successful daily run should answer:

> **What happened since the previous run that is worth my attention?**

And, for every significant development:

> **Does this change anything about how I should build, experiment, or work?**

If the pipeline cannot answer those questions better than manually browsing AI news, it is not finished.