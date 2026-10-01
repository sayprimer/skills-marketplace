---
name: audience-refiner
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

- **API key.** The CLI reads a revocable Primer API key (secret, prefixed
  `ak_`) from `PRIMER_API_KEY`, or `--api-key` per call. **This is the only
  thing the user must supply** — if it isn't set, ask them for it. Treat it as a
  secret: use it to make calls, but don't repeat it back in chat or write it
  into files or transcripts.
- **Host.** The API host defaults to Primer production, so don't ask for it.
  Override it (`PRIMER_API_BASE_URL` / `--base-url`) only if the user says they
  are on a dedicated or regional deployment. See `reference/configuration.md`.
- **Contract.** `reference/api-contract.md` is the authoritative endpoint
  reference. Trust it over memory.

## The loop

Work the ICP into an audience in this order. Prefer `--dry-run` to inspect any
hand-authored body before sending.

### Step 0 — Capture the ICP
Get the ICP into the light structure in `reference/ICP-template.md`. You do not
need every field — you need the firmographic and buyer filters, hard
exclusions, a few known-good / known-bad examples, and a rough size
expectation. The examples and size are your acceptance test later.

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
Set `target_entity_type` to `person`, also for an account list. An audience
resolves to people, and company filters choose the companies they work at. The
API stores `company` as `person`.

### Step 2 — Create the audience

```bash
bin/primer create --name "Acme — Growth leaders @ DTC" \
  --type regular --target-entity-type person \
  --criteria @criteria.json
```

Read the new id from **`updatedAudience.id`** — `create` returns a
`{ estimateUpdated, updatedAudience }` envelope (see the `POST /audiences`
response in `reference/api-contract.md`), not a bare audience object. The server
may prefix the org name to the audience `name` you sent. (`destinations` are set
later, once the audience is dialed in — don't wire ad destinations while you're
still refining.)

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

### Step 6 — Launch it (run)

Once the destinations are set and the audience is dialed in, launch it. This
builds the audience and syncs it to those destinations — no UI step:

```bash
bin/primer run <id> --confirm
```

> **The destination must already be connected.** Ad-platform connections
> (LinkedIn, Meta, Google, Reddit, DV360, Microsoft) are set up **once in the
> Primer app** via OAuth — they can't be created with an API key. If you `run`
> with a destination that isn't connected, the API rejects it (rather than
> silently building without delivering) and names the unconnected destinations.
> To check before running, list `bin/primer connections` and look at each row's
> `provider` + `state` — the ad platforms (and CRMs) connected for the org.

> **`run` is a significant outbound action.** It builds the audience and pushes
> it to its ad-platform destinations, and on a free plan it starts the org's
> trial (a time-limited clock) — so it requires `--confirm` (the CLI refuses
> without it, and the server requires `confirm: true` on the API-key path). Only
> run once the audit looks right and the customer has agreed to activate.

> **Reshaping a live audience does not re-sync on its own.** After a later
> `shape`/`update`, the destination keeps the previously-run shape until you
> `run <id> --confirm` again. (Separately, if an audience is *live*, the
> platform's dynamic-audiences processor may rebuild it on its own schedule —
> that is downstream of this CLI; don't rely on it to push an edit promptly.)

> **Changed your mind right after launching?** `bin/primer cancel <id>` stops a
> run during the brief window before it dispatches. Once it has started building,
> cancel returns 409 and the run can't be stopped via the API.

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
### Targeting a pushed dataset in an audience

A dataset is referenced by its **`mappingTable`**, not its name — and you can't
construct that string, you read it back once Primer finishes importing:

1. Poll `bin/primer datasets` (or `dataset-get <id>`) until your dataset — matched
   by `name` (the `--dataset` you pushed) — shows `status: "completed"` with a
   non-null `mappingTable`. The import runs ~15–60 min behind the push.
2. Add one filter to the audience's `source_criteria.group.filters` carrying that
   `mappingTable`; the `operator` decides target vs. suppress:

   ```json
   {
     "unique_id": "<uuid>",
     "entity_type": "company",
     "field": "acme-accounts",
     "operator": "is_within",
     "values": [],
     "dataType": "string",
     "mappingTable": "csv.`org_21_184_202608061530_company_mapping`"
   }
   ```

- `mappingTable` is what resolves the dataset. `operator: is_within` targets the
  list; `exclude` suppresses it — either works in a `regular` or `exclusion`
  audience.
- `values` is always `[]`; `field` is only a display label. `entity_type` matches
  the dataset; set `target_entity_type: "person"` for a buildable audience.
- `field-values`/`find-values` don't resolve datasets — discover them via
  `datasets`/`dataset-get` only.

The static one-time CSV upload path is intentionally gone from this CLI — there
is no `dataset-create`/`dataset-import`/`dataset-delete`; everything goes
through `ingest` so the dataset remains refreshable. See the `POST /ingest/*`
endpoints in `reference/api-contract.md`.

> **Be precise about auto-refresh.** `ingest` push/refresh works today with just
> the API key. Whether new rows then *auto-rebuild dependent audiences* is a
> separate, downstream concern handled by the platform's dynamic-audiences
> processor. Describe `ingest` as keeping the *dataset* current, and don't
> over-promise audience auto-rebuild.

## Guardrails

- **The CLI is deterministic transport; you are the judgment.** It composes and
  sends requests and re-shapes numbers the server returned (the audit). It does
  not decide targeting — you do.
- **Don't invent audience contents.** Every claim about who's in the audience
  must come from the estimate's `preview`/`heuristics`. The preview is a capped
  sample (`offset` ≤ 225), not the whole audience — say "in the sample" when
  citing it.
- **Dry-run hand-authored bodies** (`--dry-run`) before sending.

## CLI verbs → endpoints

Which verb drives which endpoint. `reference/api-contract.md` is the mechanical
shape of each endpoint; this is the map from what you type to what it calls.

| CLI verb | Endpoint |
| --- | --- |
| `list` | `GET /audiences` |
| `create` | `POST /audiences` |
| `get` | `GET /audiences/:id` |
| `update` | `PATCH /audiences/:id` |
| `shape` | `POST /audiences/:id/shape` |
| `run` | `POST /audiences/:id/run` (build + sync; needs `--confirm`) |
| `cancel` | `POST /audiences/:id/run/cancel` (stop a pending run) |
| `connections` | `GET /connections` (connected ad platforms / CRMs + state) |
| `estimate [--poll]` | `GET /criterias/estimate` |
| `audit` | client-side title/seniority audit over the estimate |
| `field-values` | `GET /filters/field-values` |
| `find-values` | `POST /filters/find-values` |
| `ingest people` | `POST /ingest/people` |
| `ingest companies` | `POST /ingest/companies` |
| `datasets` | `GET /imported-datasets` |
| `dataset-get` | `GET /imported-datasets/:id` |
| _(none)_ | `POST`/`import`/`DELETE /imported-datasets` — the static CSV path, superseded by `ingest` |

The deprecated `GET /audiences/:id/:shapeId/estimate/heuristics` route (`204 No
Content`) is intentionally unmapped; read heuristics from `estimate` instead.
