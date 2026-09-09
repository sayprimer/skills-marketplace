# Contributing

Thanks for looking. This repo is **generated**, which changes how changes get
made — please read this before opening a pull request.

## Why pull requests aren't the path here

The plugin is built and published from Primer's internal source of truth. Every
release is screened before it is published, and that screen has to run *before*
anything reaches a public ref — because **pushing a branch to a public
repository publishes it immediately**, and a check that fails afterward does not
unpublish it.

Editing this repo directly would invert that ordering: content would become
public first and get vetted second. Branch protection can stop a bad merge; it
cannot stop the disclosure that already happened when the branch was pushed.

So the publish path is deliberately one-way, and direct edits here are
overwritten by the next release. This isn't a judgement about outside
contributions — it's about when the screen runs relative to when content
becomes visible.

## What to do instead

**Open an issue.** Bug reports, unclear documentation, a missing endpoint, an
awkward CLI flag — they all land the same way: the change is made upstream and
ships in the next release. Include enough to reproduce, and please don't paste
your API key.

## How a release reaches you

1. The change is made in the internal source, alongside its tests.
2. A build assembles this tree and screens it. **If the screen fails, no tree is
   produced** — there is nothing to push.
3. The result opens a pull request here, where CI independently re-checks the
   artifact itself rather than trusting the builder.
4. On merge, `plugins/primer-targeting/.claude-plugin/plugin.json` carries a new
   `version`.

That `version` string is what your client compares to decide whether your
installed copy is stale, which is why every release bumps it. See
[Staying up to date](README.md#staying-up-to-date) for how to make sure you
actually receive it — on most clients it is off by default.

## Found something that shouldn't be public?

If you spot a credential, an internal hostname, or anything else here that looks
like it was published by mistake, please **don't open a public issue** — that
amplifies it. Use GitHub's private vulnerability reporting on this repository
(Security → Report a vulnerability), which is enabled and goes straight to us.
