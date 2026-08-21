# mattpocock-skills

[`mattpocock-skills`](https://www.aihero.dev/skills) as a sandbox kit — skills
for TDD, bug diagnosis, code review, domain modeling and others. Laid out one
kit **per harness** like its siblings, since `requires.agent` takes a single
base-agent name, enforced during composition.

    mattpocock-skills/claude/     # mattpocock-skills-claude — verified in-sandbox

Schema and CLI:
[kit reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference.md),
[kits guide](https://docs.docker.com/ai/sandboxes/customize/kits.md).

## Harness coverage

Claude Code only, and unlike `rtk/` and `i-have-adhd/` there is no upstream table
to work from: the plugin is distributed through the
`anthropics/claude-plugins-official` marketplace. Whether another harness can
consume the same source has **not** been checked — the per-harness layout here is
a slot for that answer, not a claim that one exists. Verify before adding a
sibling directory.

## What breaks without it

The skills are simply absent from the session. Installing the plugin by hand
mid-session works but has to be redone in every new sandbox.

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/mattpocock-skills/claude/ claude <workspace>
    sbx run claude --kit /abs/path/to/mattpocock-skills/claude/
    sbx kit add <sandbox> /abs/path/to/mattpocock-skills/claude/     # existing one, restarts it

The path is the *variant* directory — `mattpocock-skills/` itself has no
`spec.yaml`.

No `files/`, so `sbx kit add` works. Prefer `sbx create --kit`: an
already-attached kit cannot be re-added or removed, so *updating* it still means
`sbx rm` + `sbx create`.

No host-side prerequisites. The plugin is installed per sandbox and goes away
with it — deliberately **not** by dropping skills into `~/.claude/skills`, which
is a persistent store shared read-write across all sandboxes and survives their
removal.

## The `claude` variant, entry by entry

| Entry | Why |
| ----- | --- |
| `claude plugin marketplace add anthropics/claude-plugins-official` | A fresh sandbox has no marketplaces configured **at all, not even the official one**. This is the surprising part: the install below looks like it should just work, and its failure message ("your local copy may be out of date") misdescribes the cause. |
| `claude plugin install mattpocock-skills@claude-plugins-official` | The suffix selects among configured marketplaces. |
| No `grep` guard over `claude plugin list` | Both commands are idempotent at Claude Code 2.1.221 — each prints `already …` and exits 0 (measured in-sandbox). A guard cannot prevent an error that does not happen, and its substring match can silently skip a needed install. |
| `user: "1000"` | The `claude` binary and its config are the agent's; as root the plugin would install into `/root`. |

The kit ships no `permissions.network.allow` rules and has not needed any — the
GitHub hosts the marketplace and plugin fetch use are covered by the Balanced
preset. If a step is ever blocked, take the hosts from `sbx policy log`.

## Cleanup

Everything lives in the sandbox and goes away with it.
