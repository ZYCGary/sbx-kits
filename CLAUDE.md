# CLAUDE.md

A collection of sbx kits, all v3 (`schemaVersion: "3"`). No application code, no test
suite; `node/` is the only kit with a build recipe.

Schema is authoritative upstream, not here — v3 is Early Access and shifts:

- <https://docs.docker.com/ai/sandboxes/customize/use-kits/>
- <https://docs.docker.com/ai/sandboxes/customize/author/tool-mixins/>
- <https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md> and its
  `docs/spec/capabilities/` (one page per capability)

v3 and v1/v2 kits cannot mix in one sandbox. The built-in `claude` agent
(`docker.io/sbx/claude:latest`) is v3 since 2026-11, so every kit here is v3.

## Layout

A kit is a directory with `spec.yaml` (the descriptor) and, when it ships content,
`spec.dockerfile` beside it (companion found by filename stem). **The directory name is
the kit name** — v3 has no `name:` field — so harness variants are flat siblings, not
`<tool>/<harness>/` (that would name every variant `claude`).

    laravel-sail/spec.yaml               # agent-neutral, network rules only
    node/spec.yaml + spec.dockerfile     # Node 24 + npm overlay; pnpm, buf, ccstatusline,
                                         #   mattpocock-skills-claude require it
    pnpm/  buf/                          # require node
    ccstatusline/                        # requires claude, node
    rtk-claude/  codegraph-claude/  ponytail-claude/  lsp-claude/
    i-have-adhd-claude/  caveman-claude/  mattpocock-skills-claude/   # require claude

Until 2026-11-09 these were v2 kits in `<tool>/claude/` directories; old env files with
`#dir=rtk/claude` need `#dir=rtk-claude`.

## Commands

```bash
make validate                              # every kit; add a line per new kit
sbx kit validate ./<kit>/                  # one kit
sbx kit inspect  ./<kit>/
sbx create --name <s> --kit /abs/node/ --kit /abs/<kit>/ claude <ws>
sbx env create <file>.sbxenv.yaml          # kits: list, local paths or git+https…#dir=<kit>
sbx policy ls --wide --source kit          # confirm kit rules are live
sbx policy log                             # actual blocked hosts
sbx exec <sandbox> -- <cmd> --help         # check CLI flags in the sandbox, not the host
```

**Kits with a recipe (`node/`) build with the host's `docker buildx` and need an OCI
exporter.** OrbStack's default `docker` driver has none (`OCI exporter is not supported
for the docker driver`). Use a `docker-container` builder:

```bash
docker buildx create --name sbx-kits --driver docker-container --bootstrap   # once
BUILDX_BUILDER=sbx-kits sbx env create <file>.sbxenv.yaml
```

## Writing a kit

- Descriptor starts `# syntax=docker/sandbox-kit:3`, `schemaVersion: "3"`, `kind: mixin`.
  Everything else is a capability: `lifecycle@1` (install/startup hooks, `files:`),
  `network-policy@1` (`install:`/`runtime:` allow lists), `agent-context@1` (`content:`).
- One capability per kit. Compose with repeated `--kit` or `kits:` in `.sbxenv.yaml`.
- `requires: ["claude"]` for a Claude-only kit, `["node"]` for anything running
  `npm`/`npx`. Requirements resolve against the composed set — the consumer must list
  `node/` too.
- `agent-context@1` on every kit (mixins give `content`, never `filename`).
- Hook env is **deny-by-default**: a hook sees only `PATH`, `HOME` and the shell's own
  baseline plus names in `env:`. npm hooks declare `env: [NPM_CONFIG_PREFIX]`.
- `user: "1000"` on any hook resolving `$HOME` or writing under `/home/agent`; hooks
  default to root.
- Merge into `~/.claude/settings.json` with `jq`; never write it whole. Mixin hooks run
  after the workload's own settings seed (dependency order), so a merge sticks.
- An overlay's directory entries replace the base's (owner and mode included). Create
  parent dirs in a build stage with the ownership the base has, or use `lifecycle@1`
  `files:` for a single file.
- Derive allowlists from `sbx policy log`, never from a Dockerfile or install script.
  Ship with no rules, let the run fail, add the hosts the log names. Do not allowlist a
  host you cannot attribute.
- Each kit needs a `README.md`: what it does, usage, host prerequisites, an entry table,
  cleanup.

## Sandbox behaviour

Observed in this repo's sandboxes (v3, sbx v0.51.0, `sbx/claude` 2.1.319).

- **The `claude` image is a Docker Hardened Image (Debian 13)**: bash, git, gh, curl,
  jq, python3, uv, docker/dockerd — **no node/npm**. `NPM_CONFIG_PREFIX` and its
  `bin/` on `PATH` are preset but the directory is absent until `node/` creates it.
- **`sbx create --kit`, not `sbx kit add`** — `kit add` cannot add mixins to a v3
  sandbox. Updating a kit is `sbx rm` + `sbx create`; reopening an existing sandbox uses
  the kits it was created with.
- **Install hooks exit 0 ≠ success.** `codegraph install` without `--yes` shows an agent
  picker, gets EOF, writes nothing, exits 0. Verify with `sbx exec`. Per-kit install logs:
  `sudo ls /var/log/sbx-kits/<kit>/`.
- **Agent context** lands in `~/.claude/kits-agent-context/<kit>.md`, indexed from a
  `## Kits` section at the end of `~/.claude/CLAUDE.md`.
- **Network rules match exactly in both directions.** `example.com` does not match
  `sub.example.com`; `*.example.com` does not match the bare root.
- **`~/.local/bin` is on `PATH`, including in install hooks.** `claude` lives at
  `/home/agent/.local/bin/claude`. Do not re-export `PATH`.
- **`~/.claude/skills` is a persistent store shared read-write across all sandboxes**
  (macOS: `~/Library/Application Support/com.docker.sandboxes/sandboxes/agent-skills`),
  surviving their removal. `sbx create --no-share-skills` opts out. Use plugins in a kit.
- **A fresh sandbox has no Claude Code marketplaces configured**, not even
  `claude-plugins-official`. Add the marketplace before installing a plugin. At 2.1.221
  both `marketplace add` and `plugin install` are idempotent (`already …`, exit 0) — no
  `grep` guard. `claude plugin install` has no `-y` flag.
- **Probe kit** to settle a question: echo what you need to a file, attach to a scratch
  sandbox, `sbx exec` it back.
