#!/usr/bin/env bash
#
# leak-gate.sh — fail if the marketplace tree carries anything that must never
# reach the public `sayprimer/skills-marketplace` repo.
#
# The canonical tree in `skills-marketplace/` is written publish-clean by
# construction (no internal fences, no Jira ids), so this is a safety net, not a
# sanitizer: it proves the invariant still holds after any edit. It runs in
# three places over the SAME patterns — the local build, this repo's CI, and the
# public repo's own CI — so a leak fails at the earliest of the three.
#
# Usage: leak-gate.sh <dir>   (defaults to the canonical skills-marketplace tree)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-$REPO_ROOT/skills-marketplace}"
[ -d "$TARGET" ] || { echo "leak-gate: no such dir: $TARGET" >&2; exit 2; }

fail=0
gate() { # <label> <extended-regex> [glob]
  local label="$1" pat="$2" glob="${3:-}" hits
  # .github is excluded: the published leak-gate workflow necessarily contains
  # every pattern string as source code. `tests/` is excluded and never shipped:
  # its fixtures use fake secret-shaped strings (ak_… ) on purpose. CI applies
  # the same exclusions.
  if hits="$(grep -RInE ${glob:+--include="$glob"} "$pat" "$TARGET" \
              --exclude-dir=.git --exclude-dir=.github --exclude-dir=tests 2>/dev/null)"; then
    echo "LEAK [$label]:" >&2
    echo "$hits" | sed 's/^/    /' >&2
    fail=1
  fi
}

gate "internal fence"          '<!-- *internal:(begin|end)'
gate "jira id"                 '\bAUD-[0-9]+'
gate "work-item id"            '\bWI-?[0-9]+'
gate "empty bold artifact"     '\*\*\*\*' '*.md'
gate "customer/partner name"   '(Opteo|Guillaume)'
gate "internal issue/PR ref"   '((PR|pull request|issue|ticket)[[:space:]]*#[0-9]+|#[0-9]{4,})'
gate "internal doc ref"        '(Notion|Confluence|Google Doc)'
gate "non-production host"     'staging\.|\.int\.|127\.0\.0\.1'
gate "internal environment"    '([Ss]taging|[Ll]ocal dev|deploy-env)'
gate "internal flag/config"    '(permanent-dynamic-audiences|dynamicAudiences\.)'
gate "api-key secret"          'ak_[A-Za-z0-9]{12,}'
gate "clerk/stripe live key"   '(sk_live_|sk_test_)[A-Za-z0-9]{10,}'
gate "operator api-key tool"   'CLERK_SECRET_KEY|primer-apikey|api\.clerk\.com'
gate "aws access key id"       'AKIA[0-9A-Z]{16}'
gate "private key block"       '-----BEGIN [A-Z ]*PRIVATE KEY-----'
gate "postgres dsn"            'PRIMER_PG_DSN|postgres(ql)?://[^ ]*:[^ ]*@'
gate "author home path"        '/Users/[a-z]'
gate "internal infra host"     'clockworkspring|IRSA|is_live|DuckDB|localhost:3999'
gate "internal api-docs host"  'api-docs|swagger\.json|\.int\.sayprimer'
# the skill was renamed from the legacy internal slug; its reappearance in the
# published tree is a regression, not a leak of secrets, but still wrong.
gate "legacy skill slug"       '\baudience-refiner\b'

if [ "$fail" -ne 0 ]; then
  echo "==> leak-gate FAILED for $TARGET" >&2
  exit 1
fi
echo "leak-gate clean: $TARGET"
