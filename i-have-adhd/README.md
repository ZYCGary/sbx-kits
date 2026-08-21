# i-have-adhd

[`i-have-adhd`](https://github.com/ayghri/i-have-adhd) as a sandbox kit. One kit per
harness:

    i-have-adhd/claude/     # name: i-have-adhd-claude — verified

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/i-have-adhd/claude/ claude <workspace>
    sbx run claude --kit /abs/path/to/i-have-adhd/claude/
    sbx kit add <sandbox> /abs/path/to/i-have-adhd/claude/     # restarts it

The path is the variant directory; `i-have-adhd/` has no `spec.yaml`. No `files/`, no
host-side prerequisites, no network rules.

## The `claude` variant

| Entry | Note |
| ----- | ---- |
| `claude plugin marketplace add ayghri/i-have-adhd` | A fresh sandbox has no marketplaces configured; the `@marketplace` suffix only selects among configured ones. Its failure message ("your local copy may be out of date") misdescribes the cause. |
| `claude plugin install i-have-adhd@i-have-adhd` | Plugin and marketplace share a name; the suffix is the marketplace. |
| No `grep` guard | Both commands are idempotent at Claude Code 2.1.221 (`already …`, exit 0). No `-y` flag exists at that version. |
| `user: "1000"` | `claude` and its config are the agent's (`/home/agent/.local/bin/claude`). |

## Adding a harness

Sibling directory, `name: i-have-adhd-<harness>`, `requires.agent: <harness>`. From
upstream `INSTALL.md` (14+ harnesses; read it rather than this table):

| Harness | Install |
| ------- | ------- |
| Codex | `codex plugin marketplace add ayghri/i-have-adhd --ref main` + `codex plugin add i-have-adhd@i-have-adhd` |
| Gemini CLI | `gemini extensions install https://github.com/ayghri/i-have-adhd` |
| Qwen Code | `qwen extensions install ayghri/i-have-adhd` |
| Copilot | `npx skills add ayghri/i-have-adhd -a github-copilot -g` |
| OpenCode | `git clone` into `~/.config/opencode/vendor/` + edit `opencode.json` |

The generic `npx skills add` path writes to a harness's skills directory. Check where
that resolves first — `~/.claude/skills` is shared read-write across all sandboxes.

## Cleanup

Goes away with the sandbox.
