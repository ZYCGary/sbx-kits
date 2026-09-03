# ponytail

[`ponytail`](https://github.com/DietrichGebert/ponytail) as a sandbox kit — a skill that
runs a lazy-evaluation ladder before implementation so the agent writes less code. One
kit per harness:

    ponytail/claude/     # name: ponytail-claude

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/ponytail/claude/ claude <workspace>
    sbx run claude --kit /abs/path/to/ponytail/claude/
    sbx kit add <sandbox> /abs/path/to/ponytail/claude/     # restarts it

The path is the variant directory; `ponytail/` has no `spec.yaml`. No `files/`, no
host-side prerequisites, no network rules. Upstream needs no API key or background
service.

## The `claude` variant

| Entry | Note |
| ----- | ---- |
| `claude plugin marketplace add DietrichGebert/ponytail` | A fresh sandbox has no marketplaces configured; the `@marketplace` suffix only selects among configured ones. |
| `claude plugin install ponytail@ponytail` | Plugin and marketplace share a name; the suffix is the marketplace. |
| No `grep` guard | Both commands are idempotent at Claude Code 2.1.221 (`already …`, exit 0). |
| `user: "1000"` | `claude` and its config are the agent's. |
| Node.js | Upstream wants `node` on `PATH` in non-interactive shells for its activation notifications; the sandbox image ships it. Without it the skill still works, silently. |

Upstream documents the install as the in-session `/plugin marketplace add` and
`/plugin install` pair, sent as two separate prompts. The `claude plugin …` CLI form
above is the non-interactive equivalent, which is what an install step can run.

Intensity is `full` unless `PONYTAIL_DEFAULT_MODE` (`lite`/`full`/`ultra`/`off`) or
`~/.config/ponytail/config.json` says otherwise. To pin it for a sandbox, add an env
entry rather than editing the config file — nothing in this kit writes one.

## Adding a harness

Sibling directory, `name: ponytail-<harness>`, `requires.agent: <harness>`. Upstream
documents Claude Code and the Claude desktop app only; the desktop path is a GUI flow, so
there is nothing an install step can run for it. Check upstream for other harnesses before
adding one, and run it first.

## Cleanup

Goes away with the sandbox. Upstream's `node scripts/uninstall.js` (run *before*
`/plugin remove ponytail`, which deletes the script) clears config and state — only
relevant if the plugin is ever installed outside a disposable sandbox.
