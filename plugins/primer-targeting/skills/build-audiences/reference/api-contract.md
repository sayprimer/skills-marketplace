# Audience API-key contract

The endpoint reference for the Primer audience API-key surface that the
`build-audiences` skill and its `bin/primer` CLI drive. The request
shapes, parameters, and limits below are what the CLI sends.

## Auth

All endpoints take a bearer credential: `Authorization: Bearer <token>`. Two
kinds are accepted; the skill always uses the second:

- a Clerk **session token** (browser, 7-day) — not used here;
- a Primer **API key** — a secret prefixed `ak_`, verified server-side as a
  Clerk API key and scoped to the issuing organization. This is what
  the CLI sends (`PRIMER_API_KEY` / `--api-key`).

Errors are uniform: `401` missing/!valid auth, `403` no access to the resource,
`400` returns an **array** of Zod issues (`{code, expected, received, path,
message, options}`), `404` returns a bare string.

## conversation_id — client-side only

The `create` and `shape` request schemas still *accept* a `conversation_id`
string, but this skill **never sends it**. There is no server-side conversation
stitching; the id (if any) is a local client concern. The CLI strips it from
every write body.

---

## Endpoints (14)

### 1. `GET /audiences` — list
List the org's audiences. All query params optional and **string-typed**:
`offset` (default `0`), `limit` (default `50`), `sort`
(`name|size|status|updated_at|created_by|created_at`), `order` (`ASC|DESC`),
`name`, `status`, `destinations`, `createdBy`, `error` (`true|false`),
`favorite` (`true|false`), `type`.
**200** → `{ paginationDetails{ totalCount, skippedCount, pageSize },
audiences[] }`. Each audience: `id, name, type(regular|exclusion),
status(draft|running|matching|ready|incomplete|archived|live), subStatus,
isFavorite, …`.
*Use:* find an existing audience to refine.

### 2. `POST /audiences` — create (or duplicate)
Body (all optional at the schema level; the skill sends `name` + `type` +
`source_criteria`):
- `name` string
- `type` `regular|exclusion` (default `regular`)
- `destinations` **object** of booleans (default `{}`) — keys
  `meta, google, linkedIn, reddit, dv360, salesforce, csv`. (This is an
  object, **not** an array — corrected drift.)
- `source_criteria` `{ target_entity_type*(company|person),
  group{ operator*(and|or), filters*[], group_unique_id } }`
- `initial` — optional pre-seeded `{ source_criteria, estimate }` snapshot
  (used for duplication); the skill leaves it unset for a fresh build.
- `conversation_id` — **accepted but never sent** (see above).
**201** → the created audience (`id, name, status, …, shape{…}`).
*Use:* open a new audience from an ICP the skill has translated to criteria.

### 3. `GET /audiences/{audienceId}` — get
Path `audienceId*`. **200** → the audience object (same shape as create's 201,
incl. nested `shape`). *Use:* read current state/status between steps.

### 4. `PATCH /audiences/{audienceId}` — update
Body: `{ name?, destinations?{…booleans}, archived? }`. **API-key callers send
`destinations` (and/or `name`) only.** Setting `archived: true` triggers an
**irreversible ad-audience clawback**; the CLI refuses to send `archived`.
**200** → updated audience. *Use:* flip export destinations once an audience is
dialed in.

### 5. `POST /audiences/{audienceId}/shape` — new shape (filter revision)
Path `audienceId*`. Body: `{ source_criteria{ target_entity_type*, group{…} },
enrichments?, conversation_id(never sent) }`.
**200 returns a body** (not 204): `{ estimateUpdated(bool),
updatedAudience{…full audience, incl. shape} }`. (Returning a body is a
corrected drift item.) *Use:* the core refine step — push a revised filter set
and learn whether the estimate changed.

### 6. `GET /criterias/estimate` — current estimate (poll target)
Query: `audienceId` (**camelCase**, string; no `shapeId`), `isFinalCall`
(bool). This is the combined estimate; the deprecated per-slice estimate
routes (`/criterias/estimate/{size,preview,match-rate,summary}`) are session-only
and out of scope here.
**200** → `{ people_count, companies_count, preview{ data[]{ …, job_title,
core_job_title, seniority, all_departments, company_* … }, count, offset(0–225) },
match_rate{ meta, linkedIn, google_display, google_search, reddit, dv360 },
heuristics{ summary[], top[], limit, is_redacted_for_privacy }, started_at,
finished_at }`. Each `summary`/`top` block is `{ category, name, total,
values[]{ key, label, value } }` — e.g. a `top` block with `category:
"job_title"` holds the title distribution and `category: "seniority"` the
seniority mix. (See the runtime note below — the runtime populates `top`, and
block `total` may be null.)
**Poll semantics:** after a `shape`, the estimate recomputes asynchronously;
poll this endpoint until `finished_at` is non-null (the completion signal).
Set `isFinalCall=true` on the last poll. The CLI's `estimate --poll` does
exactly this. *Use:* size the audience and feed the job-title audit.

### 7. `GET /audiences/{audienceId}/{shapeId}/estimate/heuristics` — **deprecated**
Path `audienceId*, shapeId*`. **Deprecated: always returns `204 No Content`** and
no longer returns heuristics. Use `GET /criterias/estimate` (#6) `heuristics`
instead. The CLI intentionally exposes **no** verb for this route; the job-title
audit reads #6. *Use:* none — documented for completeness only.

### 8. `GET /filters/field-values` — enumerate a field's values
Query: `fieldId*` (enum: `person_location, company_location, domain, industry,
keywords, technologies, departments, job_title, seniority, annual_revenue,
founded_year, headcount, csv, naics_code, skills, majors, degrees`), `q`
(substring), `limit` (string, default `250`).
**200** → `[{ value, label, category }]`. *Use:* discover valid filter values
when translating an ICP (e.g. list industries matching "insurance").

### 9. `POST /filters/find-values` — resolve specific values
Body: `{ fieldId*(same enum), values*[string] }`. **200** →
`[{ value, label }]`. *Use:* confirm/normalize a handful of exact values the
ICP names (e.g. resolve given job titles).

### 10. `POST /imported-datasets` — create imported dataset — **no CLI verb**
Body: `{ name*, entityType*(company|person), inputCount*, validCount*,
invalidCount*, fieldMappings*{ firstName?, lastName?, companyDomain?,
linkedinUrl?, email? } }`.
**201** → `{ rawPresignedUrl*, translatedPresignedUrl*, datasetId*, name*,
sourceFormat(csv), status(initiated|completed|failed), entityType*,
inputCount*, validCount*, invalidCount*, fieldMappings* }`. This is the static
**one-time** CSV path (create → presigned upload → #13 import). **Superseded by
the Ingest section below** and intentionally **not** exposed by the CLI, so the
skill can't fall back to a non-refreshable upload. Documented for reference
only.

### 11. `GET /imported-datasets` — list datasets
Query (all optional): `offset`, `limit`, `status(initiated|completed|failed)`.
**200** → `[{ id, name, entity_type, status, mapping_table, input_count,
valid_count, invalid_count, field_mappings, error, stats … }]`.

### 12. `GET /imported-datasets/{datasetId}` — get dataset
Path `datasetId*`. **200** → one dataset object (shape as in #11). *Use:* poll
`status` until `completed`.

### 13. `POST /imported-datasets/{datasetId}/import` — import — **no CLI verb**
Path `datasetId*`, no body. **200** → the dataset object (post-import). Part of
the static one-time upload flow (#10). Superseded by Ingest; not exposed by the
CLI. Reference only.

### 14. `DELETE /imported-datasets/{datasetId}` — delete — **no CLI verb**
Path `datasetId*`, no body. **204** on success. **`origin=api` datasets are not
API-deletable** (`deleteImportedDataset` rejects them: "Datasets ingested via
API cannot be deleted"), so the CLI exposes no delete verb. Reference only.

---

## Ingest (continuous dataset push)

The continuously-updatable replacement for the one-time CSV upload (#10/#13).
The customer POSTs people/company rows over HTTP; each record is keyed by a
stable id you choose. Re-pushing the **same `dataset` name** upserts by that id
**in place** — that is the refresh affordance (no new dataset, no delete). On
the first push the org is auto-provisioned (no manual per-org setup). The CLI
drives these via the `ingest` verb.

### I1. `POST /ingest/people` — push person rows
### I2. `POST /ingest/companies` — push company rows

**Query params** (both optional):
- `dataset` — logical dataset name (default `from_api`). **Must not contain
  `-batch-`** (reserved for the server's batch suffixes).
- `id_field` — JSON key holding each record's stable id (default `id`). Every
  record must carry a non-empty value for it.

**Body** — one of, `Content-Type: application/json` (NDJSON accepted too):
a single record object, a bare array of records, or a `{ "records": [ … ] }`
envelope.

**Person fields** (`/ingest/people`): `id`, `first_name`, `last_name`, `email`,
`linkedin_url`, `company_domain`, `company_name`, `country`, `state`, `city`.
Include `email` when available for better matching.

**Company fields** (`/ingest/companies`): `id`, `company_name`, `company_domain`,
`linkedin_url`, `country`, `state`, `city`. Rows with neither `company_domain`
nor `linkedin_url` may not match.

**Keep-others upsert:** each request updates only the ids you send — other
records in the dataset are kept. For a given id, any field you **omit or send
empty is cleared**; send the full set of fields you want to keep per record.

**Limits:** **600 requests/min** per org, **50,000 records/request**, **10 MB**
max body. (The `ingest` `ak_` uses a separate limiter from the audience key —
see `configuration.md`.)

**Status codes:** `202` accepted → `{ "accepted": N }`; `400` invalid body /
missing id / empty batch / bad `dataset`|`id_field`; `401` auth; `403` ingest
not enabled for the org; `413` over 10 MB or 50k records; `429` rate-limited
(retry with backoff); `503` transient (retry).

**Timing:** data is not immediate — rows typically appear in Primer within
**15–60 min**, when the next import cycle runs.

---

## Value caps & drift checklist

- `preview.offset` ∈ **[0, 225]** (create `initial.estimate.preview`, all
  `shape`/audience `heuristics.preview`, and `/criterias/estimate`).
- Corrected drift confirmed present in the artifact and reflected above:
  1. create `destinations` is an **object**, not an array;
  2. `POST …/shape` **returns a body**, not `204`;
  3. combined `/criterias/estimate` uses camelCase **`audienceId`**, **no
     `shapeId`**;
  4. per-slice `/criterias/estimate/{…}` and the `…/estimate/heuristics` route
     are **deprecated / session-only** (heuristics → `204`).

## Response shapes confirmed against runtime

Three responses differ from a naïve reading of the endpoint schemas above.
These are the **confirmed runtime shapes** and the canonical contract — an
earlier gap between the generated OpenAPI and the live responses was reconciled, so the spec and runtime now agree. Recorded here so consumers aren't
surprised; the CLI already handles all three.

1. **`POST /audiences` returns an envelope, not a bare audience.** It returns
   `{ estimateUpdated, updatedAudience{…audience} }` (the same shape as
   `POST …/shape`). **Read the new id from `updatedAudience.id`.**
2. **`/imported-datasets` list/get use camelCase.** Response fields come back
   **camelCase** (`entityType`, `inputCount`, `fieldMappings`, `mappingTable`,
   …), matching the create (`201`) response.
3. **Estimate heuristics land in `heuristics.top[]`.** For a person-targeted
   audience the title/seniority distributions come back under `heuristics.top`
   (blocks `category: "job_title"` / `"seniority"`), with `summary` empty and
   block `total` null; the audit reads `top` (falling back to `summary`) and
   computes shares vs `people_count` when `total` is null.

Note: the server also prefixes the org name to a created audience's `name`
(e.g. `"Primer - <your name>"`).

## CLI ↔ endpoint map

| CLI verb | Endpoint |
|----------|----------|
| `list` | 1. GET /audiences |
| `create` | 2. POST /audiences |
| `get` | 3. GET /audiences/:id |
| `update` | 4. PATCH /audiences/:id |
| `shape` | 5. POST /audiences/:id/shape |
| `estimate [--poll]` | 6. GET /criterias/estimate |
| `audit` | 6 (client-side title audit; #7 deprecated) |
| `field-values` | 8. GET /filters/field-values |
| `find-values` | 9. POST /filters/find-values |
| `ingest people` | I1. POST /ingest/people |
| `ingest companies` | I2. POST /ingest/companies |
| `datasets` | 11. GET /imported-datasets |
| `dataset-get` | 12. GET /imported-datasets/:id |
| _(none)_ | 10/13/14 — static CSV path + delete, superseded by ingest; no CLI verb |
