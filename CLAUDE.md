# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Reference

Do not restate what the kit docs already specify — read them:

- <https://docs.docker.com/ai/sandboxes/customize/kits.md> — what kits are, lifecycle, `sbx kit` CLI
- <https://docs.docker.com/ai/sandboxes/customize/kit-reference.md> — `spec.yaml` schema, every key
- <https://docs.docker.com/ai/sandboxes/customize/kit-examples.md> — official example kits

`sbx kit` is marked EXPERIMENTAL by the CLI; subcommands and schema may shift, so check
the reference rather than trusting this file on any question of schema.

## What this repo is

A collection of sbx kits. There is no application code, no build step, and no test suite.
A kit is a directory holding a `spec.yaml` and optionally a `files/` directory; the
`README.md` documenting it sits one level up when the tool has harness variants.

**Two layouts, and the shape is the signal.** A tool that only ever targets one harness
is a flat top-level kit. A tool whose upstream supports several gets a directory per
harness, because `requires.agent` takes exactly one base-agent name — so multi-harness
support cannot be one kit:

    laravel-sail/spec.yaml          # agent-neutral
    pnpm/spec.yaml                  # agent-neutral
    ccstatusline/spec.yaml          # Claude-only by nature (statusLine protocol)
    rtk/README.md
    rtk/claude/spec.yaml            # name: rtk-claude
    i-have-adhd/claude/spec.yaml    # name: i-have-adhd-claude
    mattpocock-skills/claude/spec.yaml

- `laravel-sail/` — opens the six outbound hosts the Laravel Sail Dockerfile needs
  that the Balanced network preset misses.
- `pnpm/` — installs pnpm, one install step. Hot-addable. Does not enable
  `pnpm add -g`; see its README.
- `ccstatusline/` — ships the ccstatusline config and registers `statusLine`. Has
  `files/`, so creation-time only.
- `rtk/claude/` — installs rtk and registers its PreToolUse hook. Upstream covers 16
  harnesses; only the verified one is here.
- `i-have-adhd/claude/`, `mattpocock-skills/claude/` — one Claude Code plugin each,
  marketplace add + install.

Only add a harness variant once you have actually run it. An unverified variant is
worse than a missing one, because it fails silently.

These were one `claude-tools/` kit until 2026-08-21. Anything attached to a live
sandbox as `claude-tools` predates the split.

## Commands

```bash
sbx kit validate ./<kit>/                  # check spec.yaml before committing
sbx kit inspect  ./<kit>/                  # show resolved kit details
sbx run claude --kit ./<kit>/              # new sandbox with the kit
sbx create --name <s> --kit /abs/<kit>/ claude <ws>   # the way kits are applied here
sbx policy ls --wide --source kit          # confirm kit rules are live
sbx policy log                             # actual blocked hosts — the source of truth
sbx exec <sandbox> -- <cmd> --help         # check a CLI flag in the sandbox, not on the host
```

## What the docs do not tell you

Findings from this repo's sandboxes. Everything here was observed, not read.

**Always `sbx create --kit`, never `sbx kit add`.** Updating a kit means `sbx rm` +
`sbx create --kit` on each sandbox that should get it; kits cannot be removed from a
running sandbox either. Two traps if you use `sbx kit add` anyway: an already-attached kit
cannot be re-added (`duplicate kit name`, no force flag), and the path must be absolute — a
relative path re-resolves against `$HOME` later and breaks subsequent adds with
`path does not exist`.

**Derive allowlists from `sbx policy log`, never from reading a Dockerfile or install
script.** Ship the kit with no network rules, let the run fail, and add exactly the hosts
the log names. Expect several failing passes, since a blocked step masks what the next step
would have needed. Read the script only to *interpret* the log.

**Do not allowlist hosts you cannot attribute.** laravel-sail deliberately leaves
`http-intake.logs.us5.datadoghq.com` blocked.

**Network rule matching is exact in both directions.** `example.com` does not match
`sub.example.com`, and `*.example.com` does not match the bare root.

**A fresh sandbox has no Claude Code marketplaces configured at all**, not even
`claude-plugins-official`. Add the marketplace before installing any plugin. The
`plugin@marketplace` suffix only selects among *configured* marketplaces, and its failure
message ("your local copy may be out of date") misdescribes the cause.

Both commands are already idempotent — at 2.1.221, `marketplace add` on a configured
marketplace and `plugin install` on an installed plugin each print `already …` and exit 0
(measured in-sandbox). Do not wrap them in a `grep` guard over `claude plugin list`: the
guard cannot prevent an error that does not happen, and its substring match can silently
skip a needed install.

**`~/.claude/skills` is a persistent store shared read-write across all sandboxes**, on
macOS at `~/Library/Application Support/com.docker.sandboxes/sandboxes/agent-skills`.
Anything written there leaks into every other sandbox and survives their removal;
`sbx create --no-share-skills` opts out. Use plugins, not globally-installed skills, in a
kit.

**Check CLI flags against the sandbox, not the host.** It ships Claude Code 2.1.221, whose
`claude plugin install` has no `-y` flag.

**A `files/` directory works on a mixin**, though the reference documents it under
`kind: sandbox`. Files land `agent:agent` 0644, agent-writable, byte-exact, and
`sbx kit pack` includes them.

**Neither `files/` nor `setup.files` merges — both overwrite.** For a file that other steps
and kits also touch, `~/.claude/settings.json` above all, use `jq` in an install step
(`/usr/bin/jq` ships in the image).

**Files are written at creation, not on every container start**, despite the reference's
"at sandbox start". Agent-side edits survive stop/start with or without
`onlyIfMissing: true`, and are lost only on the recreate that reapplies the kit — so
`onlyIfMissing` only decides whether creation overwrites a file the image or an earlier kit
already placed.

**`setup.install` steps run as root (`uid=0`, `HOME=/root`); `setup.startup` steps run as
the agent (`uid=1000`, `HOME=/home/agent`).** Set `user: "1000"` on any install step that
resolves a path from `$HOME` or writes under `/home/agent` — otherwise the write lands in
`/root` while the step still reports success, or the file ends up `root:root` and the agent
cannot rewrite its own config later.

**`setup.install` runs once per kit application**, not on ordinary restarts. Keep steps
idempotent anyway, since re-applying is how a kit gets updated.

**The agent's `~/.local/bin` is on `PATH`, including inside install steps** — the sandbox's
own `claude` binary lives at `/home/agent/.local/bin/claude`. Use an installer's
`~/.local/bin` default, and do not re-export `PATH` to reach a tool a previous step just
installed.

**ccstatusline has no import CLI.** Its whole argument surface at 2.2.27 is `--version`,
`--config <path>`, `--hook`, and "stdin not a TTY → render the status line, TTY → run the
TUI". The README's import/export is a TUI menu item whose only effect is writing
`~/.config/ccstatusline/settings.json`, so shipping that file *is* the non-interactive
import. Registering `statusLine` in `~/.claude/settings.json` has no CLI either — use a
`jq` merge.

**To settle a question about the sandbox, write a throwaway probe kit** that echoes what
you need to a file, attach it to a scratch sandbox (`sbx create --name probe --kit ...`),
and `sbx exec` the file back.

## Conventions for a new kit

**One kit is one capability, not a bundle.** This follows
[`docker/sbx-kits-contrib`](https://github.com/docker/sbx-kits-contrib), where ~40 kits
are almost all a single tool (`vale`, `trivy`, `mise`, `playwright`) and even Claude-paired
concerns get their own kit each (`claude-mem`, `claude-ollama`, `claude-sbx-statusline` —
a status line alone is a kit). The reason is that a kit is the unit of distribution and
versioning, not just of attachment: upstream publishes each as its own OCI artifact, and
CONTRIBUTING.md calls a kit's network allowlist "the **complete** outbound contract" —
bundling two tools produces an allowlist whose entries cannot be attributed. Composition
happens at the CLI, with repeated `--kit`, or via `kits:` in `.sbxenv.yaml`.

**`requires.agent` is a hard gate, not a hint.** The reference: it "takes one base-agent
name. It is validated as a kit name and enforced during composition." So a kit that
declares it does not degrade on another agent — it fails to compose. There is no
`requires.agents` list, no version constraint, and **no documented way for an install step
to learn which agent it is running under** — no injected `SANDBOX_AGENT` or equivalent, so
detection means probing for a binary or config directory.

That is why a multi-harness tool becomes one kit *per harness* under a shared directory
(`rtk/claude/`, `rtk/gemini/`) with `name: <tool>-<harness>`, rather than one kit that
detects the agent at install time. The nesting keeps the enforced gate and a clear
composition-time error, and lets coverage grow by adding a directory you have verified
instead of extending a branch chain full of variants you have not. Upstream is flat and
expresses the same thing in the name (`claude-mem`, `claude-ollama`), so mirror the naming
even when nesting; `name` and the directory path deliberately diverge here.

Name a kit after the tool, not the harness — a harness suffix (`rtk-claude`) only where
variants exist. `files/` cannot be shared between sibling variants; each needs its own copy.

Use `kind: mixin` unless you are defining or replacing the agent itself, and set
`requires.agent` only when the kit truly cannot work elsewhere — say in the spec *why*, and
whether that is by nature (`ccstatusline` speaks Claude Code's status-line protocol) or just
this variant (`rtk/claude/` is one of upstream's 16 harness paths). Give every kit an
`agentInstructions.content` block telling the agent what
this sandbox now has and how to use it. Prefer a `files/` entry over `setup.files` for a
whole file, and follow the shape of the official example kits where they cover the case.

Each kit needs a `README.md` following `laravel-sail/README.md`'s structure: what breaks
without it, usage for both new and existing sandboxes, host-side prerequisites, a table
justifying *each* entry with the step that needs it and why the preset misses it, scope,
and cleanup (including how to drop any equivalent global `sbx policy allow` rules the kit
now supersedes). Every allowlist entry is expected to carry a reason — no unexplained
hosts.
