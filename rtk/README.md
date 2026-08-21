# rtk

[`rtk`](https://github.com/rtk-ai/rtk) filters command output before it reaches the
agent's context. One kit per harness:

    rtk/claude/     # name: rtk-claude — verified

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/rtk/claude/ claude <workspace>
    sbx run claude --kit /abs/path/to/rtk/claude/
    sbx kit add <sandbox> /abs/path/to/rtk/claude/     # restarts it

The path is the variant directory; `rtk/` has no `spec.yaml`. No `files/`, no
host-side prerequisites, no network rules.

## The `claude` variant

| Entry                                     | Note                                                                                                                                                                                                                                                                                |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `curl … install.sh \| sh`, `user: "1000"` | Installer defaults to `~/.local/bin`, already on the agent's `PATH`.                                                                                                                                                                                                                |
| `rtk init -g`                             | Registers the PreToolUse hook and writes `RTK.md`, globally rather than per project.                                                                                                                                                                                                |
| `--auto-patch`                            | Required. Without it (rtk 0.45.0) `rtk init` answers its own `[y/N]` patch prompt with N, writes no hook, and **exits 0**, while still writing `RTK.md` and the `@RTK.md` reference. Patches by merging, so it composes with `ccstatusline/` writing the same file in either order. |
| `< /dev/null`                             | Covers `rtk init`'s other prompt (`--trust-filters`). Not observed to be load-bearing.                                                                                                                                                                                              |

## Adding a harness

Sibling directory, `name: rtk-<harness>`, `requires.agent: <harness>`, changing the
harness selector — a separate axis from `--auto-patch`. Claude Code is the default, so
the Claude variant passes no selector. From `rtk init --help` at 0.45.0:

| Harness                                                                                            | Selector         |
| -------------------------------------------------------------------------------------------------- | ---------------- |
| Claude Code                                                                                        | _(default)_      |
| Gemini CLI                                                                                         | `--gemini`       |
| Codex CLI                                                                                          | `--codex`        |
| OpenCode                                                                                           | `--opencode`     |
| GitHub Copilot                                                                                     | `--copilot`      |
| Cursor, Windsurf, Cline/Roo, Kilo Code, Antigravity, Kimi, Pi, Hermes, Factory Droid, Mistral Vibe | `--agent <name>` |

Re-check `rtk init --help` in the sandbox first; this is one version's snapshot.
`--codex` uses AGENTS.md + RTK.md with **no hook patching** — instructions only, nothing
enforcing them.

## Cleanup

Goes away with the sandbox. To disable in a live one, delete rtk's `PreToolUse` entry
from `~/.claude/settings.json`.
