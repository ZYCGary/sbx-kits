# ccstatusline

Mixin kit that gives Claude Code a
[ccstatusline](https://github.com/sirmalloc/ccstatusline) status line: ships the
ccstatusline config and registers `statusLine` in `~/.claude/settings.json`. Shows
upstream repo, branch, working-tree changes, CI status, model, thinking effort, context
bar, session and weekly usage.

Flat, with no per-harness subdirectory — ccstatusline speaks Claude Code's status-line
protocol, so there is no other harness.

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/ccstatusline/ claude <workspace>
    sbx run claude --kit /abs/path/to/ccstatusline/

Creation time only — `sbx kit add` refuses a kit with `files/`:

    ERROR: kit "ccstatusline" declares files, which the kit-add recreate flow
    does not yet apply

No host-side prerequisites, no network rules.

## Entries

| Entry | Note |
| ----- | ---- |
| `files/home/.config/ccstatusline/settings.json` | ccstatusline has no import CLI. At 2.2.27 its arguments are `--version`, `--config <path>`, `--hook`, plus "stdin not a TTY → render, TTY → TUI"; import/export is a TUI menu item that writes this file. |
| `jq '.statusLine = …'`, `user: "1000"` | Registering the status line has no CLI. Merge, not a whole-file write — the same `settings.json` holds rtk's hook and the plugin registrations, and neither `files/` nor `setup.files` merges. `user: "1000"` keeps the file `agent:agent`. |
| `npx -y ccstatusline@latest` | No install step; fetched on first render. |

## Cleanup

Goes away with the sandbox. `files/` is written at creation, not on container start, so
agent-side edits to the config survive stop/start and are lost only on a recreate.
