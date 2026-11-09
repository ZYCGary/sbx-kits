# mattpocock-skills

[`mattpocock/skills`](https://github.com/mattpocock/skills) as a sandbox kit — skills for TDD,
bug diagnosis, code review, domain modeling and others. One kit per harness:

    mattpocock-skills-claude/     # verified

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/node/ --kit /abs/path/to/mattpocock-skills-claude/ claude <workspace>
    sbx run claude --kit /abs/path/to/node/ --kit /abs/path/to/mattpocock-skills-claude/

No host-side prerequisites, no network rules.

## The `claude` variant

| Entry | Note |
| ----- | ---- |
| `npx -y skills add mattpocock/skills` | The [skills CLI](https://skills.sh). Every skill in the repo (`-s '*'`), for Claude Code only (`-a claude-code`). |
| `-g` | User scope, `~/.claude/skills`. Project scope would write into the workspace. |
| `--copy` | The default symlinks from `~/.agents/skills`, which is per-sandbox; the links would dangle in other sandboxes sharing `~/.claude/skills`. |
| `user: "1000"` | Resolves `$HOME` to `/home/agent`. |
| No network rules | npm and GitHub are already allowed. `www.skills.sh` (install telemetry) is blocked and not needed. |

## Adding a harness

The skills CLI takes other agents through `-a`. Unverified here — run one before adding a
sibling directory.

## Cleanup

The skills land in `~/.claude/skills`, the store shared read-write across all sandboxes,
and survive `sbx rm`. Remove them on the host from
`~/Library/Application Support/com.docker.sandboxes/sandboxes/agent-skills`, or create the
sandbox with `--no-share-skills` to keep them per-sandbox.
