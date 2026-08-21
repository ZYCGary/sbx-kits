# ccstatusline

Mixin kit that gives Claude Code a
[ccstatusline](https://github.com/sirmalloc/ccstatusline) status line inside a
Docker Sandbox: it ships the ccstatusline config and registers the status line
in `~/.claude/settings.json`. Declares `requires.agent: claude`.

Unlike `rtk/` and `i-have-adhd/`, this kit is a single top-level directory with
no per-harness subdirectory: ccstatusline speaks Claude Code's status-line
protocol (session JSON on stdin), so there is no other harness to support. The
directory shape is the signal — a subdirectory layer means the tool has harness
variants, a flat kit means it does not.

Schema and CLI:
[kit reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference.md),
[kits guide](https://docs.docker.com/ai/sandboxes/customize/kits.md).

## What breaks without it

The sandbox falls back to the default status line, so the sandbox's git upstream,
branch, CI status, context bar, and usage counters are invisible. There is no
way to fix this from inside a session either: `statusLine` is a settings key with
no CLI, and ccstatusline's own import/export is a TUI menu item.

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/ccstatusline/ claude <workspace>
    sbx run claude --kit /abs/path/to/ccstatusline/

Creation time only — the kit ships a `files/` directory, which `sbx kit add`
refuses:

    ERROR: kit "ccstatusline" declares files, which the kit-add recreate flow
    does not yet apply

So updating it means `sbx rm` + `sbx create` on each sandbox.

No host-side prerequisites — no credentials, no host state.

## What it does, and why

| Entry | Why |
| ----- | --- |
| `files/home/.config/ccstatusline/settings.json` | ccstatusline has **no import CLI**. Its whole argument surface at 2.2.27 is `--version`, `--config`, `--hook`, and "stdin not a TTY → render". The README's import/export is a TUI menu item whose only effect is writing this file, so shipping the file *is* the non-interactive import. |
| `jq '.statusLine = …'`, as `user: "1000"` | Registering the status line has no CLI either. The merge is mandatory, not stylistic: the same `settings.json` holds rtk's PreToolUse hook and the plugin registrations, and neither `files/` nor `setup.files` merges — both overwrite. `user: "1000"` keeps `$HOME` pointing at `/home/agent` and the file `agent:agent`, so the agent can still edit its own settings. |
| `npx -y ccstatusline@latest` as the command | No install step: `npx` fetches it on first render, so the sandbox always gets the current version. |

The kit ships no `permissions.network.allow` rules and has not needed any — the
Balanced preset covers `registry.npmjs.org`, which is all `npx` requires. If it
is ever blocked, take the hosts from `sbx policy log`.

## Cleanup

Everything lives in the sandbox and goes away with it. Note that `files/` is
written at creation, not on every container start, so agent-side edits to the
config survive stop/start and are lost only on the recreate that reapplies the
kit.
