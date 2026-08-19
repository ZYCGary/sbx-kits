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
  creation time; it declares `setup.files`, so it is creation-time-only.

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

**The workflow here is always `sbx create --kit`, never `sbx kit add`.** A kit applied at
creation time gets the full schema, so design for that and do not contort a kit to stay
inside the hot-add subset. For reference, that subset is `environment.variables`,
`setup.install`, and `permissions.network.allow`; anything else — a `deny` rule, an
`agentInstructions` block, `setup.files` — makes `sbx kit add` refuse. `claude-tools`
declares `setup.files` and is therefore creation-time-only by design.

Updating a kit means `sbx rm` + `sbx create --kit` on each sandbox that should get it.
Kits cannot be removed from a running sandbox either. Should you ever use `sbx kit add`
anyway, two traps: an already-attached kit cannot be re-added (`duplicate kit name`, no
force flag), and it must be given an absolute path — a kit recorded from a relative path
later re-resolves against `$HOME` and breaks subsequent adds with `path does not exist`.

**A fresh sandbox has no Claude Code marketplaces configured at all**, not even
`claude-plugins-official`. Any plugin step must add its marketplace first, even for
plugins whose docs say the official marketplace needs no setup. The `plugin@marketplace`
suffix does not help — it only selects among *configured* marketplaces, and its failure
message ("your local copy may be out of date") misdescribes the real cause. Guard both
the marketplace add and the install with a `grep` over `claude plugin marketplace list` /
`claude plugin list` to stay idempotent.

**`~/.claude/skills` is a persistent store shared read-write across all sandboxes**, not
per-sandbox state. Anything a kit or a test writes there leaks into every other sandbox
and survives their removal; `sbx create --no-share-skills` opts out. Prefer plugins over
globally-installed skills in a kit, so what the kit adds stays scoped to the sandbox.

**Check CLI flags against the sandbox, not the host.** The sandbox ships an older Claude
Code (2.1.221) whose `claude plugin install` has no `-y` flag; a command copied from the
host CLI's `--help` fails with `unknown option`. Verify with
`sbx exec <sandbox> -- <cmd> --help`.

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

**Accepting a recreate does not mean you need `kind: sandbox`.** A mixin applied at
creation time (`--kit`) already supports the full schema — verified: `setup.files` and
the other fields `sbx kit add` rejects apply fine that way. Reach for `kind: sandbox` only to define or replace
the agent itself — image, entrypoint, command flags, resources — as the docs'
`claude-safe` example does.

**`setup.files` is the right way to place a whole file — at creation time.** Entries are
`{path, content, mode, onlyIfMissing, description}`. `content` is **required** and inline;
the reference documents no `source:`/`from:` field, so a payload lives in `spec.yaml`
either way (confirmed against the kit reference and by the validator rejecting
`source:`). `${WORKDIR}` expands to the workspace path inside `content`. A `description:`
containing `": "` must be quoted or it breaks YAML parsing.

There is no `user:` field, but that does not matter — a path under `/home/agent` lands `agent:agent` and
agent-writable anyway (tested with a probe kit). The one real cost is hot-add: `sbx kit
add` refuses any kit declaring it, with `kit "X" declares setup.files, which the kit-add
recreate flow does not yet apply; recreate the sandbox from scratch`. Since this repo
always recreates, that cost is nominal — prefer `setup.files` over a heredoc in an
install step. What it cannot do is *merge*: it overwrites, so anything landing in a file
several steps and kits all touch — `~/.claude/settings.json` above all — needs `jq` in an
install step instead (`/usr/bin/jq` ships in the image).

The reference's "files are written at sandbox start" means *creation*, not every start —
same lifecycle as `setup.install`. Tested: a probe kit's two files were both edited
in-sandbox, and a stop/start left both edits in place, with and without
`onlyIfMissing: true`. So `onlyIfMissing` only decides whether creation overwrites a file
the image or an earlier kit already placed; agent-side edits survive restarts either way,
and are lost only on the recreate that reapplies the kit.

**Set `requires.agent` on any mixin that is agent-specific.** It is mixin-only, takes one
base-agent name, and is enforced during composition — `claude-tools` uses it because it
registers a Claude Code hook, while `laravel-sail` omits it because it is agent-neutral.

**`setup.install` steps run as root (`"0"`); `setup.startup` steps run as the agent
(`"1000"`).** Measured with a probe kit: an install step at the default reports
`uid=0 HOME=/root`, and the same step with `user: "1000"` reports
`uid=1000 HOME=/home/agent`. The agent's home being `/home/agent` is a fact about the
*agent's* environment — what `sbx exec` and the running agent see — and says nothing
about install steps, which are a separate context. Both `"1000"` and `"agent"` are
accepted; prefer the numeric form the Docker examples use.

The test for whether a step needs `user: "agent"` is **whether it resolves any path from
`$HOME`** — as root that is `/root`, so the write lands somewhere the agent never looks
and the step still reports success. A second reason is ownership: files a root step
creates under `/home/agent` stay `root:root`, which can lock the agent out of rewriting
its own config later. Both of `claude-tools`' steps need it on both counts.

To settle this class of question, write a throwaway probe kit that echoes `id -u` and
`$HOME` to a file, attach it to a scratch sandbox (`sbx create --name probe --kit ...`),
and `sbx exec` the file back — it takes about a minute and beats reasoning from the docs.

**The agent's `~/.local/bin` is on `PATH`, including inside install steps** — the
sandbox's own `claude` binary lives at `/home/agent/.local/bin/claude`, and a step at
`user: "1000"` reports `PATH=/home/agent/.local/bin:/usr/local/share/npm-global/bin:...`.
Prefer an installer's `~/.local/bin` default over redirecting it to `/usr/local/bin`,
which only buys a root requirement, and do not bother re-exporting `PATH` to reach a tool
a previous step just installed.

**`setup.install` runs once per kit application** — at sandbox creation or `sbx kit add`
— and not on ordinary restarts (verified: a stop/start left a probe step's run counter at
1). Idempotency is still required, because re-applying a kit with `sbx kit add` is the
normal way to update it. `setup.startup` is the one that replays on every container
start; reserve it for daemons, cache warming, and config refresh.

**ccstatusline has no import CLI** — its whole argument surface (read off the shipped
`dist/ccstatusline.js` at 2.2.27) is `--version`, `--config <path>`, `--hook`, and
"stdin not a TTY → render the status line, TTY → run the TUI". The README's
import/export is a TUI menu item whose only effect is writing
`~/.config/ccstatusline/settings.json`, so a `setup.files` entry at that path *is* the
non-interactive import. Registering `statusLine` in `~/.claude/settings.json` has no CLI
either — a `jq` merge is the only automated path, since that file is co-owned by rtk's
hook and the plugin steps and cannot be overwritten wholesale.

**Follow the official examples' shape** (`kit-examples` in the Docker docs) when they
cover the case — their `nvm` kit is the model for any `curl … | sh` installer that writes
into the agent's home.

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
