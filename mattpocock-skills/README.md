# mattpocock-skills

[`mattpocock-skills`](https://www.aihero.dev/skills) as a sandbox kit — skills for TDD,
bug diagnosis, code review, domain modeling and others. One kit per harness:

    mattpocock-skills/claude/     # name: mattpocock-skills-claude — verified

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/mattpocock-skills/claude/ claude <workspace>
    sbx run claude --kit /abs/path/to/mattpocock-skills/claude/
    sbx kit add <sandbox> /abs/path/to/mattpocock-skills/claude/     # restarts it

The path is the variant directory; `mattpocock-skills/` has no `spec.yaml`. No `files/`,
no host-side prerequisites, no network rules.

## The `claude` variant

| Entry | Note |
| ----- | ---- |
| `claude plugin marketplace add anthropics/claude-plugins-official` | A fresh sandbox has no marketplaces configured, not even the official one. Its failure message ("your local copy may be out of date") misdescribes the cause. |
| `claude plugin install mattpocock-skills@claude-plugins-official` | The suffix selects among configured marketplaces. |
| No `grep` guard | Both commands are idempotent at Claude Code 2.1.221 (`already …`, exit 0). |
| `user: "1000"` | `claude` and its config are the agent's. |

## Adding a harness

Distributed through the `anthropics/claude-plugins-official` marketplace. Whether another
harness can consume the same source is unverified — check before adding a sibling
directory.

## Cleanup

Goes away with the sandbox. The plugin is per-sandbox, not written to `~/.claude/skills`
(shared read-write across all sandboxes).
