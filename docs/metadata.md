github + releases
    → GitHub Releases collector

github + organization
    → GitHub organization/project discovery collector

web + changelog
    → changelog collector

web + announcements
    → announcement-page collector

web + release_notes
    → curated release-notes collector

web + blog
    → blog collector

search + queries
    → discovery search collector

# Source Metadata Contract

A row in `ai_intel.news_sources` has three distinct kinds of data, and they are deliberately kept apart rather than living together in one JSONB blob:

```text
source_type, source_locator,   structural / required columns.
category, collection               Drive routing and are always present.

metadata (JSONB)                Optional per-source tuning a human
                                 configures: vendor, homepage, focus,
                                 notes, lookback_hours, queries, ...

feed_url, page_hash              Collector-owned runtime state. Written
                                 back by Web Feed / Web Monitor. Seeds
                                 never set these and must never touch
                                 them.
```

This split exists because `metadata` used to hold all three, which made the registry hard to read (the single most important routing field, `collection`, was buried inside a JSON blob) and genuinely dangerous to reseed (a reseed replaces `metadata` wholesale, which used to silently erase collector-discovered `feed_url`/`page_hash` values). See AUT-15.

The most important distinction for routing is:

```text
source_type = where/how the source is accessed
collection  = how the source should be collected
```

A collector must route using **both columns together**.

For example:

```json
{
  "source_type": "github",
  "source_locator": "ollama/ollama",
  "collection": "releases"
}
```

means:

```text
GitHub transport
+
GitHub Releases collection strategy
```

while:

```json
{
  "source_type": "github",
  "source_locator": "QwenLM",
  "collection": "organization"
}
```

means:

```text
GitHub transport
+
organization/project discovery strategy
```

The second source must not be treated as a repository release feed simply because its `source_type` is `github`.

## Base Shape

Most sources should follow this general structure: structural columns plus an optional metadata blob of tuning fields.

```json
{
  "source_type": "github",
  "source_locator": "ollama/ollama",
  "category": "platform",
  "collection": "releases",
  "metadata": {
    "vendor": "Ollama",
    "homepage": "https://ollama.com",
    "repository": "ollama/ollama",
    "focus": [
      "model support",
      "tool use",
      "local inference"
    ],
    "notes": "Collector or scoring guidance",
    "lookback_hours": 48,
    "discovery_required": false
  }
}
```

`collection` is the only field considered part of the required behavioral contract, which is why it is a NOT NULL column with its own CHECK constraint rather than an optional metadata key. Everything inside `metadata` is optional and should be supplied when it improves collection, scoring, research, or maintainability.

## `collection`

`collection` determines which collector strategy should be used. It is a real column on `news_sources`, constrained to the eleven supported values:

| Collection | Typical source type | Purpose |
| --- | --- | --- |
| `releases` | `github` | Collect repository releases |
| `organization` | `github` | Discover relevant repositories/projects within an organization |
| `feed` | `rss` | Collect RSS or Atom entries |
| `changelog` | `web` | Parse an official product changelog |
| `release_notes` | `web` | Parse curated release notes |
| `announcements` | `web` | Collect official announcements |
| `blog` | `web` | Collect posts from an official blog |
| `news` | `web` | Collect official company/product news |
| `docs` | `web` | Detect meaningful documentation changes |
| `product` | `web` | Monitor a product page, usually with discovery assistance |
| `queries` | `search` | Execute configured discovery searches |

The combination of `source_type` and `collection` must be supported by the collection workflow.

Examples:

```text
github + releases
github + organization
rss    + feed
web    + changelog
web    + announcements
web    + release_notes
web    + blog
web    + news
web    + docs
web    + product
search + queries
```

If an unsupported pair is encountered, the source should fail individually without aborting the entire collection run.

## `vendor`

Human-readable organization, project, or vendor name.

Example:

```json
{
  "vendor": "Open WebUI"
}
```

This field is primarily contextual. It may be supplied to scoring and research prompts so models do not have to infer ownership from URLs or repository names.

It should not be used as a unique identifier.

## `homepage`

Canonical product or project homepage.

Example:

```json
{
  "homepage": "https://openwebui.com"
}
```

This can be used during research to establish product context or locate authoritative supporting material.

The actual collection target remains `source_locator`.

## `repository`

Canonical repository identifier when relevant.

Example:

```json
{
  "repository": "open-webui/open-webui"
}
```

For `github + releases`, this will often duplicate `source_locator`.

That duplication is intentional because metadata may later be passed independently to downstream workflow nodes or prompts.

Do not treat `repository` as the routing identifier. `source_locator` remains the authoritative source address.

## `focus`

A list of topics that are particularly important when evaluating this source.

Example:

```json
{
  "focus": [
    "agent features",
    "MCP",
    "model integrations",
    "deployment"
  ]
}
```

`focus` is not a hard filter.

It acts as a relevance hint for scoring and research.

A story outside the focus list may still be important enough to keep.

For example, an Open WebUI security incident might be highly relevant even if `"security"` was omitted from the source's focus list.

## `notes`

Free-form implementation or editorial guidance.

Example:

```json
{
  "notes": "Suppress routine patch releases unless they introduce meaningful model, API, or workflow changes."
}
```

Use `notes` for guidance that is specific to one source and does not justify a dedicated configuration field.

Notes may be supplied to scoring or research prompts, but workflows should avoid building critical deterministic logic around free-form text.

If a behavior becomes structurally important, promote it to a dedicated metadata field.

## `lookback_hours`

Optional collection-window override.

Example:

```json
{
  "lookback_hours": 48
}
```

When omitted, the collector should use the workflow's default lookback behavior, normally based on `last_success_at` plus a small overlap window.

This field is useful for sources that publish irregularly or whose feeds do not reliably expose stable identifiers.

Collectors should still remain idempotent. A longer lookback must not produce duplicate `news_items`.

## `discovery_required`

Indicates that the registered page is authoritative but is not sufficient by itself to reliably enumerate updates.

Example:

```json
{
  "collection": "product",
  "discovery_required": true
}
```

This may apply to product pages or documentation sites without a structured changelog.

When `true`, the collection or research workflow may use a configured discovery provider to identify likely changes, but any resulting story should still be verified against an authoritative source before publication.

Discovery results are leads, not evidence.

## Search Metadata

Sources with:

```text
source_type = search
collection  = queries
```

should define a list of discovery queries in `metadata`.

Example:

```json
{
  "source_type": "search",
  "collection": "queries",
  "metadata": {
    "queries": [
      "AI coding agent release",
      "AI IDE release",
      "agent harness release",
      "MCP developer tooling"
    ]
  }
}
```

Search sources are discovery mechanisms rather than authoritative sources.

Items discovered through search must retain their discovery provenance and should be researched before publication.

## GitHub Release Sources

Typical shape:

```json
{
  "collection": "releases",
  "metadata": {
    "vendor": "Ollama",
    "homepage": "https://ollama.com",
    "repository": "ollama/ollama",
    "focus": [
      "model support",
      "tool use",
      "local inference",
      "API compatibility"
    ],
    "notes": "Suppress routine patch releases unless they materially affect developer workflows."
  }
}
```

The collector should use the GitHub API to retrieve releases for `source_locator`.

Example:

```text
source_type:    github
source_locator: ollama/ollama
collection:     releases
```

The GitHub API should be authenticated.

Routine releases should still be collected and stored when appropriate. Relevance scoring, rather than the collector, should generally decide whether they deserve further attention.

## GitHub Organization Sources

Typical shape:

```json
{
  "collection": "organization",
  "metadata": {
    "vendor": "Qwen",
    "homepage": "https://qwen.ai",
    "focus": [
      "model releases",
      "coding models",
      "agent models"
    ]
  }
}
```

Example:

```text
source_type:    github
source_locator: QwenLM
collection:     organization
```

This strategy may inspect repositories belonging to the organization and identify significant projects or releases.

It must not construct a GitHub Releases request directly against the organization name.

Organization collection should be conservative because large organizations may contain many repositories unrelated to the intelligence brief.

`focus` and future collector-specific metadata can help constrain discovery.

## Web Changelog Sources

Typical shape:

```json
{
  "collection": "changelog",
  "metadata": {
    "vendor": "Cursor",
    "homepage": "https://cursor.com",
    "focus": [
      "agents",
      "model support",
      "MCP",
      "background agents",
      "developer workflow"
    ]
  }
}
```

The collector should parse discrete changelog entries where possible.

Each entry should retain its original authoritative URL and published date.

Do not treat minor visual or copy changes on the changelog page itself as stories.

## Announcement Sources

Typical shape:

```json
{
  "collection": "announcements",
  "metadata": {
    "vendor": "OpenRouter",
    "homepage": "https://openrouter.ai",
    "focus": [
      "model availability",
      "routing",
      "API changes",
      "tool use",
      "MCP",
      "pricing"
    ]
  }
}
```

Announcement sources are considered authoritative Tier 1 sources.

They should generally be preferred over third-party reporting when establishing what a product launched or changed.

Consequential business claims such as acquisitions may still require secondary verification during the research stage.

## Metadata and Scoring

Metadata should enrich scoring but not dictate it.

For example:

```json
{
  "focus": [
    "MCP",
    "agent features"
  ]
}
```

means that MCP or agent-related changes from that source deserve particular consideration.

It does not mean:

```text
if topic not in focus -> reject
```

The scoring model should evaluate the actual development against the broader system priorities.

Metadata provides context, not the final verdict.

## Metadata and Collection Logic

Collector behavior should be configuration-driven wherever practical.

Adding:

```text
Cursor
web
https://www.cursor.com/changelog
collection = changelog
```

should not require creating a dedicated `Cursor` branch in n8n.

Instead:

```text
source
  ↓
source_type + metadata.collection
  ↓
generic collector
  ↓
source-specific metadata
  ↓
normalized news item
```

Source-specific code is justified only when the underlying source genuinely requires unique parsing or API behavior.

## Schema Evolution

Metadata fields should remain in JSONB while they are optional or source-specific.

A metadata property should be promoted to a database column when it becomes:

- required for nearly every source,
- heavily queried by SQL,
- part of a critical constraint,
- indexed frequently,
- or fundamental to the identity of a source.

`collection` was promoted out of metadata into its own column for exactly this reason (AUT-15): it is required for every source, it is the field every collector routes on, and it needed its own CHECK constraint rather than only being validated by convention.

Avoid expanding the relational schema merely because a new source requires one additional configuration value that is genuinely optional or source-specific.

## Collector-Owned Runtime State

`feed_url` and `page_hash` are columns on `news_sources`, not metadata keys, and they are not something a human sets when adding a source.

* `feed_url` is written once by the Web Feed collector after it discovers a source's RSS/Atom feed via `<link rel="alternate">` on the page. Once set, later runs read the feed directly instead of re-discovering it.
* `page_hash` is written by the Web Monitor collector after every scrape, used to detect whether a `docs`/`product` page's content actually changed since the last check.

Seeds must never set either column. If a source's `feed_url` or `page_hash` ever needs to be cleared (to force re-discovery or a forced re-check), do it with a direct `UPDATE` against the live database, not by editing `seeds/seed_sources.sql`.

## Example: Ollama

```json
{
  "collection": "releases",
  "metadata": {
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
  }
}
```

## Example: Open WebUI

```json
{
  "collection": "releases",
  "metadata": {
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
    "notes": "Prioritize integrations, agent workflows, functions, pipelines, providers, deployment, and administration over cosmetic UI changes."
  }
}
```

## Example: n8n

```json
{
  "collection": "releases",
  "metadata": {
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
    "notes": "Prefer meaningful workflow, AI, integration, execution, and platform changes. Routine patches should generally score low."
  }
}
```

## Example: OpenRouter

```json
{
  "collection": "announcements",
  "metadata": {
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
  }
}
```

## Guiding Principle

Metadata should make the collector **more generic, not more complicated**.

The desired end state is:

```text
new source
   ↓
insert configuration
   ↓
existing collector understands it
   ↓
no workflow surgery
```

If adding every new source requires editing the n8n graph, the metadata contract is not doing enough work.