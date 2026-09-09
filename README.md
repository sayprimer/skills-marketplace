# Primer skills marketplace

Agent skills published by [Primer](https://www.sayprimer.com). Each skill is a
[SKILL.md](https://agentskills.io) agent skill, packaged so it installs both as
a Claude Code / Cowork plugin and as a Codex skill.

## Skills

### `build-audiences`

Turns an ICP — a description of who you want to reach — into a Primer
**audience**, then refines it until the audience actually matches: it resolves
prose to filter values, creates and shapes the audience, polls the estimate, and
audits the job-title and seniority mix, re-shaping until the mix fits. Ships a
dependency-free Python CLI (`bin/primer`) that drives the Primer
audience and ingest API-key endpoints.

Requires a Primer API key (`ak_…`). Contact Primer to get one.

## Install

**Claude Code**

```
/plugin marketplace add sayprimer/skills-marketplace
/plugin install primer-targeting@sayprimer
```

**Claude Cowork** — Customize → Browse plugins, or have an org owner add this
repo under Organization settings → Plugins → Add plugin → GitHub.

**Codex / other agents** — the skill follows the open agent-skills layout. Copy
or symlink it into a skills directory your agent reads:

```bash
git clone https://github.com/sayprimer/skills-marketplace.git
ln -s "$PWD/skills-marketplace/.agents/skills/build-audiences" \
      ~/.agents/skills/build-audiences
```

## Configuration

| What | Env var | Notes |
|------|---------|-------|
| API key | `PRIMER_API_KEY` | Secret, prefixed `ak_`. Never commit it. **The only thing you have to set.** |
| Ingest API key | `PRIMER_INGEST_API_KEY` | Optional; falls back to `PRIMER_API_KEY`. |
| API host | `PRIMER_API_BASE_URL` | Optional; defaults to Primer's production host. Set it only for a dedicated or regional deployment. |

The CLI is stdlib-only Python 3.8+ — no install, no third-party dependencies.
Every write verb supports `--dry-run`, which prints the exact request (with the
key redacted) and sends nothing.

See the skill's `reference/` directory for the endpoint contract, configuration
detail, and an ICP template.

## Staying up to date

Each release bumps the plugin's `version`, which is what clients compare to
decide whether you need an update. How you receive it depends on your client.

**Claude Code.** Third-party marketplaces have background auto-update **off by
default**, so turn it on once:

```
/plugin  →  Marketplaces  →  sayprimer  →  Enable auto-update
```

With it on, Claude Code refreshes shortly after a session starts and prompts
you to run `/reload-plugins` (the running session keeps the version it loaded
at launch). To update on demand instead:

```
/plugin marketplace update sayprimer
/reload-plugins
```

Installing by full name also refreshes the catalog first, even with
auto-update off:

```
/plugin install primer-targeting@sayprimer
```

Instead of the UI toggle, you can set it in `~/.claude/settings.json` for
yourself — or an admin can put the same block in a project's
`.claude/settings.json` or in managed settings to enable it for everyone
without each person toggling it:

```json
{
  "extraKnownMarketplaces": {
    "sayprimer": {
      "source": { "source": "github", "repo": "sayprimer/skills-marketplace" },
      "autoUpdate": true
    }
  }
}
```

**Claude Cowork — nothing for you to do; one setting for your org owner.**
Cowork does **not** read `~/.claude/settings.json`, so none of the above
applies to it. It sources plugins from your claude.ai account and downloads
them fresh into each session, which means members always start a session on
whatever version the org marketplace currently holds — there is no per-user
update step and no `/reload-plugins`.

What gates it is the org marketplace sync, and **syncs are manual by default**.
An org owner enables automatic propagation once, in **Organization settings →
Plugins → Libraries**: find the marketplace, open the menu on its card, and
toggle **Sync automatically** on. From then on every merge to the connected
branch triggers a sync. Without it, someone has to click **Update** on the
marketplace card for each release — until they do, members stay on the old
version no matter what they do on their end.

**Known limitation.** Claude Code currently skips background plugin
auto-updates on Homebrew and other package-manager installs even when
`autoUpdate` is true — see
<https://github.com/anthropics/claude-code/issues/86139> (open as of
September 2026). If you installed that way, use the manual
`/plugin marketplace update sayprimer` above. Background updates are also
skipped when `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` or
`DISABLE_AUTOUPDATER` is set.

## Contributing

This repo is **generated** from Primer's internal source of truth and published
as sanitized snapshots — direct edits here are overwritten on the next publish.
Please open an issue rather than a pull request. See
[CONTRIBUTING.md](CONTRIBUTING.md) for why, and how a change reaches you.
