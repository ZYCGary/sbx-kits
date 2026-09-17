# lsp

The official LSP plugins for Claude Code — `php-lsp`, `gopls-lsp`, `typescript-lsp` — as
a sandbox kit. One kit per harness:

    lsp/claude/     # name: lsp-claude — unverified, not yet run in a sandbox

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/lsp/claude/ claude <workspace>
    sbx run claude --kit /abs/path/to/lsp/claude/
    sbx kit add <sandbox> /abs/path/to/lsp/claude/     # restarts it

The path is the variant directory; `lsp/` has no `spec.yaml`. No `files/`, no network
rules.

## Host prerequisites

None. The plugins are pulled inside the sandbox.

## The `claude` variant

| Entry | Note |
| ----- | ----- |
| `claude plugin marketplace add anthropics/claude-plugins-official` | A fresh sandbox has no marketplaces configured, not even the official one. |
| `claude plugin install <name>@claude-plugins-official` | The suffix selects among configured marketplaces. Three installs, one per language. |
| No `grep` guard | Both commands are idempotent at Claude Code 2.1.221 (`already …`, exit 0). |
| `user: "1000"` | `claude` and its config are the agent's. |

## Language servers are not installed

Each plugin is a `lspServers` declaration only — it names a command and the extensions
it handles. Nothing works until that command is on `PATH`:

| Plugin | Server command | Install |
| ------ | -------------- | ------- |
| `php-lsp` | `intelephense --stdio` | `npm install -g intelephense` |
| `gopls-lsp` | `gopls` | `go install golang.org/x/tools/gopls@latest` |
| `typescript-lsp` | `typescript-language-server --stdio` | `npm install -g typescript-language-server typescript` |

Deliberately left out of the kit: each pulls from a different registry, and this repo
derives allowlists from `sbx policy log` rather than guessing them. Install the servers
from the workspace's own toolchain, or extend this kit once a run has named the hosts.

## Cleanup

Goes away with the sandbox. Plugins are per-sandbox, not written to `~/.claude/skills`
(shared read-write across all sandboxes).
