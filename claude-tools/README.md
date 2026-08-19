# claude-tools

Mixin kit that installs the tooling the `claude` agent expects inside a Docker
Sandbox. Attached to every new sandbox at creation time. Declares
`requires.agent: claude`, since it registers a Claude Code hook.

| Item                | What it is                              |
| ------------------- | --------------------------------------- |
| `rtk`               | CLI proxy that trims dev-command tokens |
| `i-have-adhd`       | Claude Code plugin                      |
| `mattpocock-skills` | 35 skills from the official marketplace |
| `ccstatusline`      | Claude Code status line renderer        |

Schema and CLI:
[kit reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference.md),
[kits guide](https://docs.docker.com/ai/sandboxes/customize/kits.md).

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/claude-tools/ claude <workspace>
    sbx run claude --kit /abs/path/to/claude-tools/

Creation time only — the kit ships a `files/` directory, which `sbx kit add`
refuses:

    ERROR: kit "claude-tools" declares files, which the kit-add recreate flow
    does not yet apply

So updating the kit means `sbx rm` + `sbx create` on each sandbox.

No host-side prerequisites — no credentials, no host state. Everything the kit
installs lives in the sandboxes and goes away with them.

## Network

No `permissions.network.allow` rules, and none needed so far: every host the
install steps touch — `raw.githubusercontent.com`, `github.com`,
`release-assets.githubusercontent.com`, `registry.npmjs.org` — is already
permitted by the active preset. `registry.npmjs.org` matters after creation too,
since the `npx` status line re-resolves the package on every render.

If a step is ever blocked, take the hosts from `sbx policy log` — never from
reading an install script — add each with its reason, and recreate.

| Host | Needed for |
| ---- | ---------- |
| _(none yet)_ | |

## Install steps

All steps run at `user: "1000"` and must be idempotent; they re-run on every
creation.

### rtk

    rtk init -g --auto-patch

`--auto-patch` is required. Plain `rtk init -g` does not register the hook — it
writes `~/.claude/RTK.md`, prints the `PreToolUse` JSON, and leaves you to paste
it.

### Plugins

**A fresh sandbox has no marketplaces configured at all**, not even
`claude-plugins-official`, so each marketplace is added in its own step before
any install. The `grep` guards are what make the steps re-runnable.

```yaml
    - command: |
        set -eu
        claude plugin marketplace list | grep -q claude-plugins-official \
          || claude plugin marketplace add anthropics/claude-plugins-official
    - command: |
        set -eu
        claude plugin list | grep -q mattpocock-skills \
          || claude plugin install mattpocock-skills@claude-plugins-official
```

`claude plugin install` has no `-y` flag in-sandbox — Claude Code 2.1.221 accepts
only `--config` and `--scope`.

`/setup-matt-pocock-skills` is interactive and stays a manual step.

### ccstatusline

The config ships as a real file, `files/home/` mapping to `/home/agent/`:

    files/home/.config/ccstatusline/settings.json -> ~/.config/ccstatusline/settings.json

That file *is* the import. ccstatusline 2.2.27 has no import CLI — its whole
argument surface is `--version`, `--config <path>`, `--hook` — and the TUI's
import/export writes exactly this path. In-sandbox TUI edits survive restarts but
are reverted by the next recreate, so keep anything worth having in this file.

`statusLine` is registered by a `jq` merge, because `~/.claude/settings.json` is
co-owned by rtk's hook and the plugin steps and cannot be overwritten:

```yaml
        settings="$HOME/.claude/settings.json"
        mkdir -p "$HOME/.claude"
        [ -f "$settings" ] || printf '{}' > "$settings"
        tmp=$(mktemp)
        jq '.statusLine = {"type": "command", "command": "npx -y ccstatusline@latest", "padding": 0, "refreshInterval": 10}' \
          "$settings" > "$tmp"
        mv "$tmp" "$settings"
```

`npx -y ccstatusline@latest` needs one `registry.npmjs.org` connection per
render, at ~520 ms warm.
