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

## Commands

```bash
sbx kit validate ./laravel-sail/           # check spec.yaml before committing
sbx kit inspect  ./laravel-sail/           # show resolved kit details
sbx run claude --kit ./laravel-sail/       # new sandbox with the kit
sbx kit add <sandbox> ./laravel-sail/      # add to an existing sandbox (restarts it)
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

**Derive allowlists from `sbx policy log`, not from the Dockerfile.** `apt-get update`
refreshes metadata for every configured source, so the real outbound set is wider than
the packages a build asks for.

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
