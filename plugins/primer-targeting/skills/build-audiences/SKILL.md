---
name: build-audiences
description: |
  Builds and refines a Primer audience programmatically from a description of
  who the customer wants to reach (an ICP), by driving the Primer audience
  API-key endpoints through the bundled `bin/primer` CLI. Use this
  skill whenever the user wants to "build an audience", "refine an audience",
  "create a Primer audience", "translate an ICP into filters", "size/estimate
  an audience", "check who's in an audience", or asks to tighten targeting so a
  segment matches an ideal-customer profile (right industries, headcount,
  titles, seniority, geos), including known-account / exclusion lists pushed
  via the ingest endpoint. The skill
  translates the ICP into filter criteria, creates and shapes the audience,
  polls the estimate, and audits the job-title/seniority mix — re-shaping until
  the audience matches the ICP. The CLI is the deterministic transport; this
  skill supplies the judgment. Requires a revocable Primer API key (`ak_…`).
---

# Refining Primer audiences

This skill turns a customer's **ICP** ("who we want to reach") into a Primer
**audience** — a filter set the customer can push to ad and outbound
destinations — and then **refines** it until the audience actually matches the
ICP. It drives the audience API-key endpoints through the bundled
`bin/primer` CLI. All the mechanics (auth, request shapes, polling)
live in the CLI and `reference/api-contract.md`; **your job is the judgment** —
translating the ICP to filters, reading the estimate, and deciding what to
change.

## Before you start

- **API key + host.** The CLI reads a revocable Primer API key from `PRIMER_API_KEY` and the API host from
  `PRIMER_API_BASE_URL`; you can also pass them per call with `--api-key` /
  `--base-url`. If neither is set, ask the user for their API key and their
  Primer API host, then use them via those flags. Treat the key as a secret:
  use it to make calls, but don't repeat it back in chat or write it into files
  or transcripts. See `reference/configuration.md`.
- **Contract.** `reference/api-contract.md` is the authoritative endpoint
  reference, generated from the OpenAPI subset. Trust it over memory.

## The loop

Work the ICP into an audience in this order. Prefer `--dry-run` to inspect any
hand-authored body before sending.

### Step 0 — Capture the ICP
Get the ICP into the light structure in `reference/ICP-template.md`. You do not
need every field — you need the target entity (`company` vs `person`), the
firmographic and buyer filters, hard exclusions, a few known-good / known-bad
examples, and a rough size expectation. The examples and size are your
acceptance test later.

### Step 1 — Resolve filter values
The ICP names things in prose ("insurance", "VP Marketing"); the API needs
valid filter values. Resolve them:

```bash
# enumerate what's available for a field (optionally filtered by a substring)
bin/primer field-values industry --q insurance
# resolve specific named values
bin/primer find-values job_title --value "VP Marketing" --value "CMO"
```

Use these to assemble a `source_criteria` object:
`{ target_entity_type, group{ operator, filters[], group_unique_id } }`.

### Step 2 — Create the audience

```bash
bin/primer create --name "Acme — Growth leaders @ DTC" \
  --type regular --target-entity-type company \
  --criteria @criteria.json
```

Read the new id from **`updatedAudience.id`** — at runtime `create` returns a
`{ estimateUpdated, updatedAudience }` envelope (see the runtime note in
`reference/api-contract.md`), not a bare audience object. (`destinations` are
set later, once the audience is dialed in — don't wire ad destinations while
you're still refining.)

### Step 3 — Shape it

```bash
bin/primer shape <id> --criteria @criteria.json
```

`shape` returns `{ estimateUpdated, updatedAudience }`. A new shape kicks off an
asynchronous estimate.

### Step 4 — Estimate (poll)

```bash
bin/primer estimate <id> --poll
```

Polls `GET /criterias/estimate` until `finished_at` is set. You get
`people_count`, `companies_count`, a capped `preview`, `match_rate`, and
`heuristics`.

### Step 5 — Audit the audience

```bash
bin/primer audit <id>
```

`audit` reads the same estimate and summarizes the **job-title distribution**
and **seniority mix** from `heuristics` (runtime populates `heuristics.top`,
blocks `job_title`/`seniority`; it falls back to `heuristics.summary` and to the
preview sample). Shares are computed vs `people_count` when a block carries no
total. This is the refine signal. Check it against the ICP's known-good / known-bad
examples and size expectation:

- Wrong titles dominating (e.g. lots of interns/students when you want VPs)?
  Tighten `job_title` / `seniority` filters and re-`shape`.
- Size off by an order of magnitude vs the ICP's expectation? The criteria are
  probably too broad or too narrow — adjust and re-`shape`.
- Known-good accounts/titles missing, or known-bad present? Fix the filters.

Loop Steps 3–5 until the audience matches the ICP. Then, if the customer wants
to activate it, set export destinations:

```bash
bin/primer update <id> --destination meta=true --destination csv=true
```

> **Never** send `archived` — the CLI refuses it. Setting `archived: true`
> triggers an irreversible ad-audience clawback; API-key callers change
> `destinations`/`name` only.

## Known-account / exclusion lists (ingest)

To get your own rows (known customers, suppression lists, a CRM/warehouse
export) into Primer, push them with the **`ingest`** verb — one call, no
create→upload→import dance:

```bash
# people or companies; records inline, @file.json, or NDJSON (@file / - stdin)
bin/primer ingest companies --dataset acme-accounts \
  --records @accounts.json
```

- **Same `dataset` name each push = in-place refresh.** Records upsert by their
  stable id (`--id-field`, default `id`); this is how the dataset stays current.
  Keep-others semantics: for a given id, any field you omit or send empty is
  **cleared**, so send the full set of fields you want to keep per record.
- **No per-org setup** — the org is auto-provisioned on the first push.
- Body shapes: a single object, an array, `{records:[...]}`, or NDJSON. Server
  limits per request: **50k records / 10 MB**; the CLI auto-splits larger
  inputs into ≤50k batches. Data appears in Primer within ~15–60 min.
- Then reference the dataset (by name) in an `exclusion`- or `regular`-type
  audience. Reads stay origin-agnostic: `datasets` / `dataset-get`.

The static one-time CSV upload path is intentionally gone from this CLI — there
is no `dataset-create`/`dataset-import`/`dataset-delete`; everything goes
through `ingest` so the dataset remains refreshable. See the **Ingest** section
of `reference/api-contract.md`.

> **Be precise about auto-refresh.** `ingest` push/refresh works today with just
> the API key. Whether new rows then *auto-rebuild dependent audiences* is a
> separate, downstream concern handled by the platform's dynamic-audiences
> processor. Describe `ingest` as keeping the *dataset* current, and don't
> over-promise audience auto-rebuild.

## conversation_id is client-side only

If you track a conversation id locally, keep it local. The skill and CLI
**never** send `conversation_id` to the server — there is no server-side
conversation stitching. The CLI strips it from any write body.

## Guardrails

- **The CLI is deterministic transport; you are the judgment.** It composes and
  sends requests and re-shapes numbers the server returned (the audit). It does
  not decide targeting — you do.
- **Don't invent audience contents.** Every claim about who's in the audience
  must come from the estimate's `preview`/`heuristics`. The preview is a capped
  sample (`offset` ≤ 225), not the whole audience — say "in the sample" when
  citing it.
- **Dry-run hand-authored bodies** (`--dry-run`) before sending.
