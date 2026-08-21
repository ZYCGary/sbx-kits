# i-have-adhd

[`i-have-adhd`](https://github.com/ayghri/i-have-adhd) as a sandbox kit. This
directory holds one kit **per harness**: upstream ships a different install
command for each, and `requires.agent` takes a single base-agent name, enforced
during composition.

    i-have-adhd/claude/     # i-have-adhd-claude — verified in-sandbox

Schema and CLI:
[kit reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference.md),
[kits guide](https://docs.docker.com/ai/sandboxes/customize/kits.md).

## Harness coverage

Upstream `INSTALL.md` documents 14+ harnesses. Only the Claude Code variant
exists here, because it is the only one that has been run. To add another,
create a sibling directory with `name: i-have-adhd-<harness>` and
`requires.agent: <harness>`. A condensed sample of upstream's commands:

| Harness     | Install command                                                    |
| ----------- | ------------------------------------------------------------------ |
| Claude Code | `claude plugin marketplace add …` + `claude plugin install …`       |
| Codex       | `codex plugin marketplace add ayghri/i-have-adhd --ref main` + `codex plugin add i-have-adhd@i-have-adhd` |
| Gemini CLI  | `gemini extensions install https://github.com/ayghri/i-have-adhd`   |
| Qwen Code   | `qwen extensions install ayghri/i-have-adhd`                       |
| Copilot     | `npx skills add ayghri/i-have-adhd -a github-copilot -g`           |
| OpenCode    | `git clone` into `~/.config/opencode/vendor/` + edit `opencode.json` |

Read upstream's `INSTALL.md` before adding one; do not treat this table as
authoritative. Add a directory only once you have actually run it.

Note that the generic `npx skills add` path installs into a harness's *skills*
directory. Inside a sandbox, check where that resolves before using it —
`~/.claude/skills` is a persistent store shared read-write across **all**
sandboxes and surviving their removal, which is exactly what a kit should not
write to.

## What breaks without it

The plugin's skills and commands are simply absent from the session. Installing
it by hand mid-session is possible but has to be redone in every new sandbox.

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/i-have-adhd/claude/ claude <workspace>
    sbx run claude --kit /abs/path/to/i-have-adhd/claude/
    sbx kit add <sandbox> /abs/path/to/i-have-adhd/claude/     # existing one, restarts it

The path is the *variant* directory — `i-have-adhd/` itself has no `spec.yaml`.

No `files/`, so `sbx kit add` works. Prefer `sbx create --kit`: an
already-attached kit cannot be re-added or removed, so *updating* it still means
`sbx rm` + `sbx create`.

No host-side prerequisites. The plugin is installed per sandbox and goes away
with it.

## The `claude` variant, entry by entry

| Entry | Why |
| ----- | --- |
| `claude plugin marketplace add ayghri/i-have-adhd` | A fresh sandbox has **no** marketplaces configured at all. Without this the install fails with a message ("your local copy may be out of date") that misdescribes the cause — the `@marketplace` suffix only selects among *configured* marketplaces. |
| `claude plugin install i-have-adhd@i-have-adhd` | Plugin and marketplace happen to share a name; the suffix is the marketplace. |
| No `grep` guard over `claude plugin list` | Both commands are idempotent at Claude Code 2.1.221 — each prints `already …` and exits 0 (measured in-sandbox). A guard cannot prevent an error that does not happen, and its substring match can silently skip a needed install. |
| `user: "1000"` | The `claude` binary and its config are the agent's (`/home/agent/.local/bin/claude`); as root the plugin would install into `/root`. |

There is no `-y` flag on `claude plugin install` at 2.1.221 — check CLI flags
against the sandbox, not the host.

The kit ships no `permissions.network.allow` rules and has not needed any — the
GitHub hosts the plugin fetch uses are covered by the Balanced preset. If a step
is ever blocked, take the hosts from `sbx policy log`.

## Cleanup

Everything lives in the sandbox and goes away with it.
