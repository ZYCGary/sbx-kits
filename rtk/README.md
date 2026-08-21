# rtk

[`rtk`](https://github.com/rtk-ai/rtk) (Rust Token Killer) filters command output
before it reaches an agent's context. This directory holds one kit **per
harness**, because `rtk init` patches a different place for each one and
`requires.agent` takes a single base-agent name, enforced during composition.

    rtk/claude/     # rtk-claude — verified in-sandbox

Schema and CLI:
[kit reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference.md),
[kits guide](https://docs.docker.com/ai/sandboxes/customize/kits.md).

## Harness coverage

`rtk init` targets many harnesses; only the Claude Code variant exists here,
because it is the only one that has been run. To add another, create a sibling
directory with `name: rtk-<harness>` and `requires.agent: <harness>`, changing
the *harness selector* — which is a separate axis from `--auto-patch`. Claude
Code is `--agent`'s default, so the Claude variant passes no selector at all.

Selectors from `rtk init --help` at rtk 0.45.0 (the binary, not the README):

| Harness            | Selector                    |
| ------------------ | --------------------------- |
| Claude Code        | *(default)*                 |
| Gemini CLI         | `--gemini`                  |
| Codex CLI          | `--codex`                   |
| OpenCode           | `--opencode`                |
| GitHub Copilot     | `--copilot`                 |
| Cursor, Windsurf, Cline/Roo, Kilo Code, Antigravity, Kimi, Pi, Hermes, Factory Droid, Mistral Vibe | `--agent <name>` |

One trap for a future variant: `--codex` is documented as "uses AGENTS.md +
RTK.md, **no Claude hook patching**". So an `rtk/codex/` kit would ship
instructions telling the agent to use rtk, with nothing enforcing it — decide
whether that is worth a kit before writing one.

Re-check `rtk init --help` in the sandbox before adding a variant; this table is
one version's snapshot. Add the directory only once you have actually run it — an
unverified variant is worse than a missing one, because, as the `--auto-patch`
finding below shows, rtk's failure mode here is a clean exit 0.

## What breaks without it

Nothing breaks — the agent just burns tokens on raw command output. The host's
global `RTK.md` instructions assume `rtk` exists, so without the kit every
`rtk gain` / `rtk discover` the agent tries is a `command not found`.

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/rtk/claude/ claude <workspace>
    sbx run claude --kit /abs/path/to/rtk/claude/
    sbx kit add <sandbox> /abs/path/to/rtk/claude/     # existing one, restarts it

The path is the *variant* directory, not `rtk/` — `rtk/` itself has no
`spec.yaml`.

No `files/`, so `sbx kit add` works. Prefer `sbx create --kit`: an
already-attached kit cannot be re-added or removed, so *updating* the kit still
means `sbx rm` + `sbx create`.

No host-side prerequisites — no credentials, no host state.

## The `claude` variant, entry by entry

| Entry | Why |
| ----- | --- |
| `curl … install.sh \| sh`, as `user: "1000"` | The installer defaults to `~/.local/bin`, which is already on the agent's `PATH` including inside install steps. As root it would land in `/root` and the step would still report success. |
| `rtk init -g` | Registers the PreToolUse hook and writes `RTK.md`. `-g` puts both in the global assistant config dir rather than the project. |
| `--auto-patch` | **Do not drop it**, even though upstream's README marks plain `rtk init -g` as "recommended" — that recommendation assumes a human who can answer a prompt. Measured at rtk 0.45.0 with a throwaway `HOME`: without the flag, `rtk init -g` detects the non-interactive stdin, prints `Patch existing …/settings.json? [y/N]` → `(non-interactive mode, defaulting to N)` and a `MANUAL STEP:` block, leaves `settings.json` untouched, **and exits 0** — so `set -eu` does not catch it. It still writes `RTK.md` and the `@RTK.md` reference into `CLAUDE.md`, so the sandbox looks configured and the agent reads rtk's instructions while no filtering is active. |
| `< /dev/null` | Belt and braces for a *different* prompt: `rtk init` also has `--trust-filters` / `--no-trust-filters` for custom filters it detects, which `--auto-patch` does not cover. A fresh sandbox has no custom filters, so this has not been observed to be load-bearing. |

`--auto-patch` **merges** rather than overwrites: measured against a `settings.json`
already holding a `statusLine` key, rtk added `hooks.PreToolUse` and left
`statusLine` intact. So this kit and `ccstatusline/` can be applied in either
order without clobbering each other.

`rtk init` patches `~/.claude/settings.json` in place, which is why every other
kit touching that file uses a `jq` merge instead of a whole-file write.

The kit ships no `permissions.network.allow` rules and has not needed any —
`raw.githubusercontent.com` and the installer's release download are covered by
the Balanced preset. If a step is ever blocked, take the hosts from
`sbx policy log`, never from reading the install script, and record each with
its reason.

## Cleanup

Everything lives in the sandbox and goes away with it. Inside a live sandbox the
filtering can be turned off by deleting rtk's `PreToolUse` entry from
`~/.claude/settings.json`.
