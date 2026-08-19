# claude-tools

Mixin kit that installs the tooling the `claude` agent expects to find inside a
Docker Sandbox. Intended to be attached to every new sandbox, at creation time.

It declares `requires.agent: claude`, so composition fails loudly if it is ever
attached to a different base agent. That is honest rather than restrictive — the
kit registers a Claude Code hook, so it genuinely has nothing to offer another
agent. (Contrast `laravel-sail`, which is agent-neutral and so declares no
requirement.)

Currently installs:

| Item                | What it is                              | Status                       |
| ------------------- | --------------------------------------- | ---------------------------- |
| `mattpocock-skills` | 35 skills from the official marketplace | active                       |
| `rtk`               | CLI proxy that trims dev-command tokens | active                       |
| `i-have-adhd`       | Claude Code plugin                      | active                       |
| `ccstatusline`      | Claude Code status line renderer        | active                       |
| `caveman`           | Claude Code plugin                      | blocked upstream — see below |

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/claude-tools/ claude <workspace>
    sbx run claude --kit /abs/path/to/claude-tools/

**Creation time only.** This kit declares `setup.files`, and `sbx kit add`
refuses those outright:

    ERROR: kit "claude-tools" declares setup.files, which the kit-add recreate
    flow does not yet apply; recreate the sandbox from scratch via `sbx rm` +
    `sbx create --kit` to use this kit

That matches how this repo works — sandboxes are recreated, never hot-patched —
and it means updating the kit is always a `sbx rm` + `sbx create`. Two `kit add`
limits that no longer bite but are worth knowing if that ever changes: a kit
already attached cannot be re-added (`duplicate kit name`, no `--force`), and a
kit added by relative path later re-resolves against `$HOME` and breaks
subsequent adds.

## Host-side prerequisites

None. No credentials, no host state.

## Network: deliberately empty

This kit ships **no `permissions.network.allow` rules**, even though its install
steps clearly reach the network. That is a deliberate security choice: an
allowlist written from reading a script is a guess, and guesses are always wider
than the real contract. Default-deny plus a real failure gives you the exact
list instead.

So the first run of this kit is expected to fail. Recover the truth from the log
and add only what it names:

    sbx policy log                  # the hosts that were actually blocked
    # add those hosts to permissions.network.allow in spec.yaml
    sbx rm <sandbox> --force
    sbx create --name <sandbox> --kit /abs/path/to/claude-tools/ claude <workspace>

Repeat until the install completes — a blocked step can mask the host the *next*
step needs, so expect more than one pass. Record the reason for each host in the
table below as you add it, so a later reader can tell a required host from a
leftover.

| Host | Needed for |
| ---- | ---------- |
| _(none yet — populate from `sbx policy log`)_ | |

Nothing has needed an entry yet: every host these steps touch —
`raw.githubusercontent.com`, `github.com`, `release-assets.githubusercontent.com`,
`registry.npmjs.org` — is already permitted by the active preset, confirmed by
`sbx policy log` showing them forwarded and naming no blocked host for a probe
sandbox built from this kit. `registry.npmjs.org` stays relevant after creation
too, since the `npx` status-line command re-resolves the package on every render.

For reference, rtk's installer is known to reach `raw.githubusercontent.com`
(the script), `github.com` (the `/releases/latest` redirect and the download),
`release-assets.githubusercontent.com` (where that download redirects), and
`api.github.com` (only as a fallback when the redirect parse fails). Treat that
as a hint for interpreting the log, not as a list to paste in — some of it may
already be covered by the active network preset, and the fallback host may never
be touched.

## Extending it

The kit is applied at creation time, so the **full schema is available** — the
hot-add subset (`environment.variables`, `setup.install`,
`permissions.network.allow`) does not constrain it. `setup.files`,
`agentInstructions`, and `deny` rules are all fair game.

One rule still holds: **every install command must be idempotent.** They re-run
on every creation, and a step that assumes a clean slate will break the second
sandbox rather than the first. rtk's installer overwrites its own binary,
`rtk init -g --auto-patch` is safe to repeat, and the plugin steps carry `grep`
guards. New steps must be equally re-runnable.

Prefer `setup.files` for placing a whole file — it is declarative, sets `mode`,
and lands `agent:agent` under `/home/agent` without an install step. Use `jq` in
an install step for anything that has to merge into a file other steps also touch,
`~/.claude/settings.json` above all — ccstatusline's `statusLine` block is the
example.

## Install steps

### mattpocock-skills

```yaml
    - command: |
        set -eu
        claude plugin marketplace list | grep -q claude-plugins-official \
          || claude plugin marketplace add anthropics/claude-plugins-official
      user: "1000"
      description: Configure the official Claude Code marketplace
    - command: |
        set -eu
        claude plugin list | grep -q mattpocock-skills \
          || claude plugin install mattpocock-skills@claude-plugins-official
      user: "1000"
      description: Install the mattpocock-skills plugin
```

The marketplace is its own step rather than a preamble to the install. It is
shared infrastructure — every future plugin from the official marketplace
depends on it and none of them should re-declare it — and splitting it means a
failure names which half broke instead of pointing at a two-command block.

Verified in a scratch sandbox: the plugin installs, reports `✔ enabled`, and
ships 35 skills.

The upstream README says `claude plugins install mattpocock-skills` works with
"no additional setup, because the plugin is in the official marketplace." That
holds on a host but not in a sandbox. Tested directly — the kit was run once with
the marketplace line removed and only the README's command left:

    $ claude plugin marketplace list
    No marketplaces configured

    $ claude plugins install mattpocock-skills
    ✘ Failed to install plugin "mattpocock-skills":
      Plugin "mattpocock-skills" not found in any configured marketplace

**A fresh sandbox has no marketplaces at all**, not even
`claude-plugins-official`, so there is nothing for the README's command to
resolve against. Adding the marketplace first is the minimum fix; the install
itself is then exactly what the README describes, from the same official source,
so updates still arrive normally.

Two details that cost a debugging pass each, worth knowing before adding more
plugins:

- **`claude plugin install` has no `-y` flag in-sandbox.** The sandbox ships
  Claude Code 2.1.221, whose `install` accepts only `--config` and `--scope`;
  passing `-y` fails outright with `unknown option`. A newer host CLI is not a
  guide to what the sandbox accepts — check with
  `sbx exec <sandbox> -- claude plugin install --help`.
- **The `grep` guards are what make each step idempotent.** Both commands run
  again on every kit application, and neither is a no-op on its own.

Per-repo setup (`/setup-matt-pocock-skills`) is interactive and stays a manual
step; a kit cannot run it.

### ccstatusline

Fully automated, in two halves: the config goes in as an init file, and the
`statusLine` registration is a `jq` merge.

```yaml
  files:
    - path: /home/agent/.config/ccstatusline/settings.json
      mode: "0644"
      description: Imports the ccstatusline config, kept in sync with ccstatusline-config.json
      content: |
        { … contents of ccstatusline-config.json … }
```

**This `setup.files` entry *is* the non-interactive import.** ccstatusline 2.2.27
has no import CLI — its whole argument surface, read off the shipped
`dist/ccstatusline.js`, is `--version`, `--config <path>`, `--hook`, plus
"stdin is not a TTY → render, TTY → run the TUI". The import/export feature the
README advertises is a TUI menu item, and all it does is write this file. So
placing the file directly is not a workaround; it is the same operation.

Verified: it lands `agent:agent`, mode 0644, agent-writable — `setup.files` has no
`user:` field, but a path under `/home/agent` still comes out owned correctly.
Files are written at *creation*, not on every container start (tested: an
in-sandbox edit survived a stop/start), so no `onlyIfMissing` guard — this kit is
the source of truth at creation time.

The `statusLine` block cannot be an init file, because `~/.claude/settings.json`
is co-owned — rtk's `PreToolUse` hook, `enabledPlugins`, `extraKnownMarketplaces`
all live there — and `setup.files` overwrites. A `jq` merge in an install step is
the only automated path; the TUI's install option is the manual one.

```yaml
        settings="$HOME/.claude/settings.json"
        mkdir -p "$HOME/.claude"
        [ -f "$settings" ] || printf '{}' > "$settings"
        tmp=$(mktemp)
        jq '.statusLine = {"type": "command", "command": "npx -y ccstatusline@latest", "padding": 0, "refreshInterval": 10}' \
          "$settings" > "$tmp"
        mv "$tmp" "$settings"
```

An assignment rather than an append, so a re-run replaces one key and leaves the
rest alone. Verified in a fresh sandbox: the step runs, the nine keys are all
present, `rtk hook claude` and both plugins intact, and running the step a second
time left the file byte-identical.

`npx -y ccstatusline@latest` rather than a globally installed binary, so nothing
has to be installed in the image and every render tracks upstream. The cost,
measured in a probe sandbox: ~520 ms per render warm versus ~250 ms for an
installed binary, and **one `registry.npmjs.org` connection per render**
(policy-log counter moved 11 → 16 across five renders) — so the status line needs
npm reachable for as long as it is displayed, not just at setup. Dropping
`@latest` from the command is the cheap way to trade auto-update for fewer
lookups.

`ccstatusline-config.json` in this directory is the source copy, exported from a
host TUI session, and the `content:` block must be kept in sync with it by hand.
`content` is a required field and the kit reference documents no `source:`/`from:`
alternative, so there is no way to point at the sibling file — the duplication is
the schema's, not a shortcut.

In-sandbox TUI edits survive restarts but are reverted by the next recreate, so
anything worth keeping belongs back in `ccstatusline-config.json`.

### rtk and i-have-adhd

Both are active. `rtk` needed one detail beyond its docs: plain `rtk init -g` does **not** register the hook — it writes
`~/.claude/RTK.md`, prints the `PreToolUse` JSON, and leaves you to paste it —
so the kit passes `--auto-patch`, which writes the hook itself.

### caveman — blocked upstream

`caveman` is blocked upstream, not by the kit. Its `plugin.json` declares
`agents` as an array of file paths, which current Claude Code rejects:

    ✘ Failed to install plugin "caveman@caveman": invalid manifest file
      Validation errors: agents: Invalid input

The same failure is visible on the host, where `claude plugin list` reports
caveman as `✘ failed to load`. A host that already has it installed will report
`already installed` and skip validation entirely, which makes the command look
like it succeeded.

## Cleanup

The kit creates no host state. Everything it installs lives in sandboxes that
load it and disappears when those sandboxes are removed.
