# codegraph

[`codegraph`](https://github.com/colbymchenry/codegraph) builds a local symbol/call-path
index of a project and serves it to an agent over MCP. One kit per harness:

    codegraph/claude/     # name: codegraph-claude — unverified

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/codegraph/claude/ claude <workspace>
    sbx run claude --kit /abs/path/to/codegraph/claude/
    sbx kit add <sandbox> /abs/path/to/codegraph/claude/     # restarts it

The path is the variant directory; `codegraph/` has no `spec.yaml`. No `files/`, no
host-side prerequisites. Network rules are not yet derived from `sbx policy log` — the
installer pulls from `raw.githubusercontent.com` at minimum; run it once, check
`sbx policy log` for anything else blocked, and add those hosts.

## The `claude` variant

| Entry | Note |
| ----- | ---- |
| `curl … install.sh \| sh`, `user: "1000"` | No Node.js required — codegraph bundles its own runtime. Installer defaults to a location on the agent's `PATH`. |
| `codegraph install` | Auto-detects and wires Claude Code, registering `codegraph serve --mcp` as an MCP server. Only Claude Code is present in this sandbox, so nothing else gets touched. |
| `< /dev/null` | Guards against any interactive prompt in `codegraph install`; not confirmed to be load-bearing. |
| No `codegraph init` in `setup.install` | `setup.install` runs before the workspace is mounted, and indexing is project-specific — the agent runs `codegraph init` itself once inside the project root (see `agentInstructions`). |

## Composition risk

`codegraph install` writes Claude Code's MCP config; unverified whether it merges or
overwrites `~/.claude/settings.json` (`rtk-claude` and `ccstatusline` both merge into that
same file via `jq`). Apply `codegraph-claude` first if composing, until checked.

## Cleanup

Goes away with the sandbox. Per-project state lives in `.codegraph/` inside the
workspace, not under `~/.claude`.
