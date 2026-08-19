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
  in-sandbox (rtk, two plugins, ccstatusline). Attached to every new sandbox at
  creation time; it ships a `files/` directory, so it is creation-time-only.

## Commands

```bash
sbx kit validate ./<kit>/                  # check spec.yaml before committing
sbx kit inspect  ./<kit>/                  # show resolved kit details
sbx run claude --kit ./<kit>/              # new sandbox with the kit
sbx create --name <s> --kit /abs/<kit>/ claude <ws>   # the way kits are applied here
sbx policy ls --wide --source kit          # confirm kit rules are live
sbx policy log                             # actual blocked hosts — the source of truth
sbx kit pack/push/pull                     # OCI distribution (unused so far)
```

`sbx kit` is marked EXPERIMENTAL by the CLI; subcommands and schema may shift.

## Constraints that shape kit design

**Always `sbx create --kit`, never `sbx kit add`.** Creation-time application gets the
full schema. The hot-add subset is `environment.variables`, `setup.install`, and
`permissions.network.allow` only; a `deny` rule, `agentInstructions`, `setup.files`, or a
`files/` directory makes `sbx kit add` refuse.

**Updating a kit means `sbx rm` + `sbx create --kit`** on each sandbox that should get it.
Kits cannot be removed from a running sandbox. If you do use `sbx kit add`: an
already-attached kit cannot be re-added (`duplicate kit name`, no force flag), and the
path must be absolute — a relative path re-resolves against `$HOME` later and breaks
subsequent adds with `path does not exist`.

**Derive allowlists from `sbx policy log`, never from reading a Dockerfile or install
script.** Ship the kit with no network rules, let the run fail, and add exactly the hosts
the log names. Expect several failing passes, since a blocked step masks what the next
step would have needed. Read the script only to *interpret* the log.

**Do not allowlist hosts you cannot attribute.** laravel-sail deliberately leaves
`http-intake.logs.us5.datadoghq.com` blocked.

**Network rule matching is exact in both directions.** `example.com` does not match
`sub.example.com`, and `*.example.com` does not match the bare root.

**A fresh sandbox has no Claude Code marketplaces configured at all**, not even
`claude-plugins-official`. Add the marketplace before installing any plugin. The
`plugin@marketplace` suffix only selects among *configured* marketplaces, and its failure
message ("your local copy may be out of date") misdescribes the cause. Guard both the
marketplace add and the install with a `grep` over `claude plugin marketplace list` /
`claude plugin list` to stay idempotent.

**`~/.claude/skills` is a persistent store shared read-write across all sandboxes.**
Anything written there leaks into every other sandbox and survives their removal;
`sbx create --no-share-skills` opts out. Use plugins, not globally-installed skills, in a
kit.

**Check CLI flags against the sandbox, not the host** —
`sbx exec <sandbox> -- <cmd> --help`. The sandbox ships Claude Code 2.1.221, whose
`claude plugin install` has no `-y` flag.

**Use `kind: mixin` unless you are defining or replacing the agent itself** — image,
entrypoint, command flags, resources. A mixin applied with `--kit` supports the full
schema, including the fields `sbx kit add` rejects.

**Ship whole files from the kit's `files/` directory.** `files/home/` maps to
`/home/agent/` and `files/workspace/` to the primary workspace path; parent directories
are created, existing files overwritten, absolute and `../` paths rejected. Files land
`agent:agent` 0644 and agent-writable, byte-exact, and `sbx kit pack` includes `files/` in
the ZIP. Works on a mixin, though the reference documents it under `kind: sandbox`.

**Reach for `setup.files` only when you need `mode:`, `onlyIfMissing:`, or `${WORKDIR}`
expansion.** Entries are `{path, content, mode, onlyIfMissing, description}`; `content` is
required and inline, with no `source:`/`from:` alternative. Quote any `description:`
containing `": "` or it breaks YAML parsing.

**Neither file mechanism merges — both overwrite.** For a file that other steps and kits
also touch, `~/.claude/settings.json` above all, use `jq` in an install step
(`/usr/bin/jq` ships in the image).

**Files are written at creation, not on every container start** — same lifecycle as
`setup.install`. Agent-side edits survive stop/start with or without `onlyIfMissing:
true`, and are lost only on the recreate that reapplies the kit. `onlyIfMissing` only
decides whether creation overwrites a file the image or an earlier kit already placed.

**Set `requires.agent` on any mixin that is agent-specific.** Mixin-only, one base-agent
name, enforced during composition. `claude-tools` sets it because it registers a Claude
Code hook; `laravel-sail` omits it because it is agent-neutral.

**`setup.install` steps run as root (`uid=0`, `HOME=/root`); `setup.startup` steps run as
the agent (`uid=1000`, `HOME=/home/agent`).** Set `user: "1000"` on any install step that
resolves a path from `$HOME` or writes under `/home/agent` — otherwise the write lands in
`/root` while the step still reports success, or the file ends up `root:root` and the agent
cannot rewrite its own config later. Both `"1000"` and `"agent"` are accepted; prefer the
numeric form the Docker examples use.

**`setup.install` runs once per kit application**, not on ordinary restarts. Keep steps
idempotent anyway. `setup.startup` replays on every container start; reserve it for
daemons, cache warming, and config refresh.

**The agent's `~/.local/bin` is on `PATH`, including inside install steps** — the
sandbox's own `claude` binary lives at `/home/agent/.local/bin/claude`. Use an installer's
`~/.local/bin` default, and do not re-export `PATH` to reach a tool a previous step just
installed.

**ccstatusline has no import CLI.** Its whole argument surface at 2.2.27 is `--version`,
`--config <path>`, `--hook`, and "stdin not a TTY → render the status line, TTY → run the
TUI". The README's import/export is a TUI menu item whose only effect is writing
`~/.config/ccstatusline/settings.json`, so shipping that file *is* the non-interactive
import. Registering `statusLine` in `~/.claude/settings.json` has no CLI either — use a
`jq` merge.

**Follow the official examples' shape** (`kit-examples` in the Docker docs) when they
cover the case — their `nvm` kit is the model for any `curl … | sh` installer that writes
into the agent's home.

**To settle a question about the sandbox, write a throwaway probe kit** that echoes what
you need to a file, attach it to a scratch sandbox (`sbx create --name probe --kit ...`),
and `sbx exec` the file back.

## Conventions for a new kit

A kit is a directory with `spec.yaml` (`schemaVersion: "2"`, `kind: mixin`, `name`,
`displayName`, `description`, then the permission/setup blocks) and a `README.md`.
Follow `laravel-sail/README.md`'s structure: what breaks without it, usage for both new
and existing sandboxes, host-side prerequisites, a table justifying *each* entry with
the step that needs it and why the preset misses it, scope, and cleanup (including how
to drop any equivalent global `sbx policy allow` rules the kit now supersedes).
Every allowlist entry is expected to carry a reason — no unexplained hosts.
