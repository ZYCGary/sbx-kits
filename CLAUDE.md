# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of **sbx kits** — declarative YAML artifacts that extend a Docker Sandbox
agent with network policy, credentials, env vars, startup commands, or injected files.
There is no application code, no build step, and no test suite. Each top-level directory
is one kit: a `spec.yaml` plus a `README.md` documenting it.

Current kits:

- `laravel-sail/` — mixin that opens the six outbound hosts the Laravel Sail
  Dockerfile needs that the Balanced network preset misses.
- `claude-tools/` — mixin that installs the tooling the `claude` agent expects
  in-sandbox (currently rtk). Designed to be attached to every new sandbox and
  re-applied with `sbx kit add` as it grows, so it must stay hot-addable.

## Commands

```bash
sbx kit validate ./<kit>/                  # check spec.yaml before committing
sbx kit inspect  ./<kit>/                  # show resolved kit details
sbx run claude --kit ./<kit>/              # new sandbox with the kit
sbx kit add <sandbox> ./<kit>/             # add to an existing sandbox (restarts it)
sbx policy ls --wide --source kit          # confirm kit rules are live
sbx policy log                             # actual blocked hosts — the source of truth
sbx kit pack/push/pull                     # OCI distribution (unused so far)
```

`sbx kit` is marked EXPERIMENTAL by the CLI; subcommands and schema may shift.

## Constraints that shape kit design

**`sbx kit add` supports only a subset of the schema**: `environment.variables`,
`setup.install`, and `permissions.network.allow`. Anything else — a `deny` rule, an
`agentInstructions` block, file injection — forces a full sandbox recreate instead of a
restart. Keep a kit inside that subset when it is meant to be hot-addable, and split
anything beyond it into a separate kit rather than widening an existing one.

Kits cannot be removed from a running sandbox; the sandbox must be recreated.

**Network rule matching is exact in both directions.** `example.com` does not match
`sub.example.com`, and `*.example.com` does not match the bare root. Two of the six
laravel-sail hosts exist purely because of this (`ppa.launchpadcontent.net` vs the
preset's `ppa.launchpad.net`; `deb.nodesource.com` vs `nodesource.com`).

**Derive allowlists from `sbx policy log`, never from reading a Dockerfile or install
script.** This is the repo's standing rule, and it is a security position, not just a
convenience one: an allowlist written by prediction is always wider than the real
contract. Write the kit with no network rules, let the first run fail, and add exactly
the hosts the log names — accepting several failing passes, since a blocked step masks
what the next step would have needed. `claude-tools` ships with an empty allowlist for
this reason; `laravel-sail`'s six hosts were each earned by an observed failure. Reading
the script is still useful for *interpreting* the log, just never for populating the
list. (`apt-get update` is the classic case for why prediction fails: it refreshes
metadata for every configured source, not just the package you asked for.)

**Set `requires.agent` on any mixin that is agent-specific.** It is mixin-only, takes one
base-agent name, and is enforced during composition — `claude-tools` uses it because it
registers a Claude Code hook, while `laravel-sail` omits it because it is agent-neutral.

**`setup.install` steps run as root; `setup.startup` steps run as UID 1000.** Sandbox
images provide a non-root `agent` user at UID 1000, and the field takes the numeric UID,
not the name. The test for whether a step needs `user: "1000"` is not what it installs
but **whether it resolves any path from `$HOME`** — as root that is `/root`, so the
write lands somewhere the agent never looks and the step still reports success. Both of
`claude-tools`' steps need it for exactly this reason.

**The agent's `~/.local/bin` is on `PATH`** — the sandbox's own `claude` binary lives at
`/home/agent/.local/bin/claude`. Prefer an installer's `~/.local/bin` default over
redirecting it to `/usr/local/bin`, which only buys a root requirement.

**`setup.install` commands re-run on every restart**, so every one of them must be
idempotent — guard with a version check rather than reinstalling blindly.

**Do not allowlist hosts you cannot attribute.** laravel-sail deliberately leaves
`http-intake.logs.us5.datadoghq.com` blocked because its source is unidentified.

## Conventions for a new kit

A kit is a directory with `spec.yaml` (`schemaVersion: "2"`, `kind: mixin`, `name`,
`displayName`, `description`, then the permission/setup blocks) and a `README.md`.
Follow `laravel-sail/README.md`'s structure: what breaks without it, usage for both new
and existing sandboxes, host-side prerequisites, a table justifying *each* entry with
the step that needs it and why the preset misses it, scope, and cleanup (including how
to drop any equivalent global `sbx policy allow` rules the kit now supersedes).
Every allowlist entry is expected to carry a reason — no unexplained hosts.
