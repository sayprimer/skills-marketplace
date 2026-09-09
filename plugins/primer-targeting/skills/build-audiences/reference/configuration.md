# Configuration

The `build-audiences` skill drives the Primer audience API-key endpoints
through the bundled `bin/primer` CLI (stdlib-only Python 3 — no
install). Everything below is what the CLI needs to reach the API.

## Credentials & base URL

| What | Env var | CLI flag | Notes |
|------|---------|----------|-------|
| API key | `PRIMER_API_KEY` | `--api-key` | Revocable Clerk key, secret, prefixed `ak_`. Sent as `Authorization: Bearer <key>`. **Never** paste it into chat or commit it. |
| Ingest API key | `PRIMER_INGEST_API_KEY` | `--ingest-api-key` | Optional. Used by the `ingest` verb only; falls back to the audience key above if unset. See the two-key note below. |
| Base URL | `PRIMER_API_BASE_URL` | `--base-url` | Environment root, no trailing path. **Required** — there is no baked-in default (the host is environment-specific). |

### Two keys, two limiters

Ingest and the audience endpoints are rate-limited **separately**, so a
deployment may hand you two `ak_` keys:

| Surface | Key | Rate limit |
|---------|-----|-----------|
| Audience endpoints (`create`/`shape`/`estimate`/…) | audience `ak_` | **120 req/min** |
| `ingest` (`POST /ingest/{people\|companies}`) | ingest `ak_` | **600 req/min** |

Both are bearer `ak_` keys on the same host. If your deployment issues one key
for both surfaces, set `PRIMER_API_KEY` and the `ingest` verb reuses it. If it
issues a distinct ingest key, put it in `PRIMER_INGEST_API_KEY` (or pass
`--ingest-api-key`) and leave `PRIMER_API_KEY` for the audience calls. Ingest
also enforces **50k records / 10 MB** per request (the CLI auto-splits by
record count); `429` means back off, `413` means the batch was too big.

Export once per shell:

```bash
export PRIMER_API_KEY="ak_…" # provided out-of-band; keep it secret
export PRIMER_API_BASE_URL="https://primer-platform.api.sayprimer.com"
```

The CLI redacts the key in all `--dry-run` output (`Bearer ak_tes…7890`).

## Environments

Set `PRIMER_API_BASE_URL` to your Primer API host:

| Environment | `PRIMER_API_BASE_URL` | Notes |
|-------------|-----------------------|-------|
| Production | `https://primer-platform.api.sayprimer.com` | Your Primer API host. |

## conversation_id policy

`conversation_id` is **client-side only**. The CLI never sends it on `create` or
`shape` (it strips the key from any write body and prints a note to stderr).
There is no server-side conversation stitching — nothing in this skill implies
otherwise.

## Dry-run first

Every write verb supports `--dry-run`, which composes and prints the exact
request (method, URL, redacted headers, JSON body) and sends nothing. Use it to
inspect the composed body before spending a real call — especially when passing
a hand-authored `--criteria`/`--body` JSON.

```bash
primer --dry-run shape aud_123 --criteria @criteria.json
```

## Poll & value caps

- `estimate --poll` polls `GET /criterias/estimate` until `finished_at` is set
  (`--poll-interval`, default 3s; `--poll-timeout`, default 180s), sending
  `isFinalCall=true` on the last poll.
- `preview.offset` is capped at **225** (see `api-contract.md`).

## Verifying against the contract

`reference/api-contract.md` is generated from the OpenAPI subset. When
that artifact is re-issued, regenerate the contract doc and re-check the CLI
body shapes against it — the CLI ↔ endpoint map at the bottom of the contract is
the checklist.
