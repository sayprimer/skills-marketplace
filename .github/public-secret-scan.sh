#!/usr/bin/env bash
#
# public-secret-scan.sh — the PUBLIC backstop gate shipped into the
# sayprimer/skills-marketplace repo (as .github/public-secret-scan.sh) and run
# by that repo's own CI.
#
# This is deliberately GENERIC. It matches only universal secret shapes (AWS,
# Stripe/Clerk, private keys, DSNs, Slack/GitHub/Google tokens) — patterns that
# reveal nothing about Primer. The authoritative gate with the internal-terms
# denylist (customer/partner names, internal hosts, feature flags, the legacy
# skill slug) is `leak-gate.sh`, which runs ONLY in the private primer-platform
# repo before publishing — so that denylist is never itself published. See
# scripts/marketplace/README.md.
#
# Usage: public-secret-scan.sh <dir>
set -euo pipefail

TARGET="${1:-.}"
[ -d "$TARGET" ] || { echo "public-secret-scan: no such dir: $TARGET" >&2; exit 2; }

fail=0
gate() { # <label> <extended-regex> [glob]
  local label="$1" pat="$2" glob="${3:-}" hits
  if hits="$(grep -RInE ${glob:+--include="$glob"} "$pat" "$TARGET" \
              --exclude-dir=.git --exclude-dir=.github 2>/dev/null)"; then
    echo "SECRET [$label]:" >&2
    echo "$hits" | sed 's/^/    /' >&2
    fail=1
  fi
}

# Universal secret detectors only — no Primer-specific terms.
gate "primer api-key secret" 'ak_[A-Za-z0-9]{12,}'
gate "clerk/stripe live key" '(sk_live_|sk_test_)[A-Za-z0-9]{10,}'
gate "aws access key id"     'AKIA[0-9A-Z]{16}'
gate "gcp api key"           'AIza[0-9A-Za-z_\-]{35}'
gate "github token"          'gh[pousr]_[A-Za-z0-9]{20,}'
gate "slack token"           'xox[baprs]-[0-9A-Za-z-]{8,}'
gate "private key block"     '-----BEGIN [A-Z ]*PRIVATE KEY-----'
gate "credentialed dsn"      'postgres(ql)?://[^ ]*:[^ ]*@'
gate "author home path"      '/Users/[a-z]'

if [ "$fail" -ne 0 ]; then
  echo "==> public-secret-scan FAILED for $TARGET" >&2
  exit 1
fi
echo "public-secret-scan clean: $TARGET"
