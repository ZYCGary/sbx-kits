# caveman

[`caveman`](https://github.com/JuliusBrussee/caveman) as a sandbox kit — a skill and
SessionStart hook that compress the agent's output register. One kit per harness:

    caveman/claude/     # name: caveman-claude

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/caveman/claude/ claude <workspace>
    sbx run claude --kit /abs/path/to/caveman/claude/
    sbx kit add <sandbox> /abs/path/to/caveman/claude/     # restarts it

The path is the variant directory; `caveman/` has no `spec.yaml`. No `files/`, no
host-side prerequisites, no network rules. Upstream needs no API key or background
service.

## The `claude` variant

| Entry | Note |
| ----- | ---- |
| `claude plugin marketplace add JuliusBrussee/caveman` | A fresh sandbox has no marketplaces configured; the `@marketplace` suffix only selects among configured ones. |
| `claude plugin install caveman@caveman` | Plugin and marketplace share a name; the suffix is the marketplace. |
| No `grep` guard | Both commands are idempotent at Claude Code 2.1.221 (`already …`, exit 0). |
| `user: "1000"` | `claude` and its config are the agent's. |

Upstream also describes a `[CAVEMAN]` statusline badge. `statusLine` in this repo is
owned by the `ccstatusline/` kit; the interaction is unverified.

## Adding a harness

Sibling directory, `name: caveman-<harness>`, `requires.agent: <harness>`. From upstream
`INSTALL.md`:

| Harness | Install |
| ------- | ------- |
| Gemini CLI | `gemini extensions install https://github.com/JuliusBrussee/caveman` |
| opencode | `node bin/install.js --only opencode` (AGENTS.md marker block) |
| OpenClaw | `npx -y github:JuliusBrussee/caveman -- --only openclaw` |
| Hermes | `npx -y github:JuliusBrussee/caveman -- --only hermes` |
| Cursor, Windsurf, Cline, Continue, 20+ others | `npx skills add JuliusBrussee/caveman -a <profile> -g` |

The `npx skills add` path writes to a harness's skills directory. Check where that
resolves first — `~/.claude/skills` is shared read-write across all sandboxes.

## Cleanup

Goes away with the sandbox.
