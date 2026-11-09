# ccstatusline

Mixin kit that gives Claude Code a
[ccstatusline](https://github.com/sirmalloc/ccstatusline) status line: ships the
ccstatusline config and registers `statusLine` in `~/.claude/settings.json`. Shows
upstream repo, branch, working-tree changes, CI status, model, thinking effort, context
bar, session and weekly usage.

Flat, with no per-harness subdirectory — ccstatusline speaks Claude Code's status-line
protocol, so there is no other harness.

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/node/ --kit /abs/path/to/ccstatusline/ claude <workspace>
    sbx run claude --kit /abs/path/to/node/ --kit /abs/path/to/ccstatusline/

Requires the `node` kit — the status line runs `npx`, and the v3 `claude` image ships no
Node. No host-side prerequisites, no network rules.

## Entries

| Entry | Note |
| ----- | ---- |
| lifecycle `files:` → `~/.config/ccstatusline/settings.json`, `overwrite: false` | ccstatusline has no import CLI. At 2.2.27 its arguments are `--version`, `--config <path>`, `--hook`, plus "stdin not a TTY → render, TTY → TUI"; import/export is a TUI menu item that writes this file. |
| `jq '.statusLine = …'`, `user: "1000"` | Registering the status line has no CLI. Merge, not a whole-file write — the same `settings.json` holds rtk's hook and the plugin registrations, and a lifecycle `files:` entry overwrites rather than merges. Runs after the workload's own settings seed (hooks run in dependency order), and replaces the workload's `sbx-claude-hook claude-status` status line. `user: "1000"` keeps the file `agent:agent`. |
| `npx -y ccstatusline@latest` | No install step; fetched on first render. |

## Cleanup

Goes away with the sandbox. The config is written on start only when missing
(`overwrite: false`), so agent-side edits survive stop/start and are lost only on a recreate.
