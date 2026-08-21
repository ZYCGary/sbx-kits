# CLAUDE.md

A collection of sbx kits. No application code, no build step, no test suite.

Schema is authoritative in the docs, not here — `sbx kit` is EXPERIMENTAL and shifts:

- <https://docs.docker.com/ai/sandboxes/customize/kits.md>
- <https://docs.docker.com/ai/sandboxes/customize/kit-reference.md>
- <https://docs.docker.com/ai/sandboxes/customize/kit-examples.md>

## Layout

A kit is a directory with a `spec.yaml` and optionally `files/`. Flat for a tool with
one harness; one subdirectory per harness otherwise, with the `README.md` one level up.

    laravel-sail/spec.yaml               # agent-neutral
    pnpm/spec.yaml                       # agent-neutral
    ccstatusline/spec.yaml               # name: ccstatusline
    rtk/README.md
    rtk/claude/spec.yaml                 # name: rtk-claude
    i-have-adhd/claude/spec.yaml         # name: i-have-adhd-claude
    caveman/claude/spec.yaml             # name: caveman-claude
    mattpocock-skills/claude/spec.yaml   # name: mattpocock-skills-claude

Only `ccstatusline/` ships `files/`. These were one `claude-tools/` kit until
2026-08-21; a live sandbox may still have that name attached.

## Commands

```bash
sbx kit validate ./<kit>/                  # before committing
sbx kit inspect  ./<kit>/
sbx create --name <s> --kit /abs/<kit>/ claude <ws>   # how kits are applied here
sbx run claude --kit ./<kit>/
sbx policy ls --wide --source kit          # confirm kit rules are live
sbx policy log                             # actual blocked hosts
sbx exec <sandbox> -- <cmd> --help         # check CLI flags in the sandbox, not the host
```

## Writing a kit

- `kind: mixin` unless defining or replacing the agent itself.
- One capability per kit. Compose with repeated `--kit` or `kits:` in `.sbxenv.yaml`.
- `requires.agent` takes one base-agent name, enforced during composition — a mismatch
  fails to compose. No `requires.agents` list; no env var telling an install step which
  agent it runs under.
- Multi-harness tool → one kit per harness, `name: <tool>-<harness>`, directory
  `<tool>/<harness>/`. `name` and directory path diverge; `files/` is not shared between
  siblings. Add a harness only after running it.
- `agentInstructions.content` on every kit.
- Prefer `files/` over `setup.files` for a whole file.
- `user: "1000"` on any install step resolving `$HOME` or writing under `/home/agent`.
- Derive allowlists from `sbx policy log`, never from a Dockerfile or install script.
  Ship with no rules, let the run fail, add the hosts the log names. Do not allowlist a
  host you cannot attribute.
- Each kit needs a `README.md`: what it does, usage, host prerequisites, an entry table,
  cleanup.

## Sandbox behaviour

Observed in this repo's sandboxes.

- **`sbx create --kit`, not `sbx kit add`.** Updating a kit is `sbx rm` + `sbx create`.
  Kits cannot be removed from a running sandbox; an attached kit cannot be re-added
  (`duplicate kit name`, no force flag); `sbx kit add` paths must be absolute.
- **`sbx kit add` refuses a kit with `files/`** — applies to `ccstatusline/`.
- **Network rules match exactly in both directions.** `example.com` does not match
  `sub.example.com`; `*.example.com` does not match the bare root.
- **`setup.install` runs as root (`HOME=/root`); `setup.startup` runs as the agent
  (uid 1000).** A misdirected write still reports success.
- **`setup.install` runs once per kit application**, not on restarts. Keep it idempotent.
- **`~/.local/bin` is on `PATH`, including in install steps.** `claude` lives at
  `/home/agent/.local/bin/claude`. Do not re-export `PATH`.
- **`files/` works on a mixin.** Files land `agent:agent` 0644, byte-exact, written at
  creation only — not on container start. `sbx kit pack` includes them.
- **Neither `files/` nor `setup.files` merges — both overwrite.** Use `jq` for a shared
  file, `~/.claude/settings.json` above all (`/usr/bin/jq` ships in the image).
- **`~/.claude/skills` is a persistent store shared read-write across all sandboxes**
  (macOS: `~/Library/Application Support/com.docker.sandboxes/sandboxes/agent-skills`),
  surviving their removal. `sbx create --no-share-skills` opts out. Use plugins in a kit.
- **A fresh sandbox has no Claude Code marketplaces configured**, not even
  `claude-plugins-official`. Add the marketplace before installing a plugin. At 2.1.221
  both `marketplace add` and `plugin install` are idempotent (`already …`, exit 0) — no
  `grep` guard. `claude plugin install` has no `-y` flag.
- **Probe kit** to settle a question: echo what you need to a file, attach to a scratch
  sandbox, `sbx exec` it back.
