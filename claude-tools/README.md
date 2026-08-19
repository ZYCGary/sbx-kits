# claude-tools

Mixin kit that installs the tooling the `claude` agent expects to find inside a
Docker Sandbox. Intended to be attached to every new sandbox, and re-applied to
existing ones as the kit grows.

It declares `requires.agent: claude`, so composition fails loudly if it is ever
attached to a different base agent. That is honest rather than restrictive — the
kit registers a Claude Code hook, so it genuinely has nothing to offer another
agent. (Contrast `laravel-sail`, which is agent-neutral and so declares no
requirement.)

Currently installs:

| Item                | What it is                            | Status                         |
| ------------------- | ------------------------------------- | ------------------------------ |
| `mattpocock-skills` | 35 skills from the official marketplace | active                       |
| `rtk`               | CLI proxy that trims dev-command tokens | commented out, pending review |
| `i-have-adhd`       | Claude Code plugin                      | commented out, pending review |
| `caveman`           | Claude Code plugin                      | blocked upstream — see below  |

Everything except `mattpocock-skills` is commented out in `spec.yaml` while each
one is verified individually.

## Usage

Creating a new sandbox:

    sbx run claude --kit ./.sbx/kits/claude-tools/

Adding to a sandbox that does not have it yet:

    sbx kit add <sandbox> /abs/path/to/claude-tools/

Two limits found by testing, both worth knowing before relying on this:

- **A kit already attached cannot be re-added.** `sbx kit add` refuses with
  `duplicate kit name "claude-tools"`, and there is no `--force` or update flag.
  Picking up a newer version of this kit on a sandbox that already has it means
  recreating that sandbox. Only brand-new sandboxes get the update for free.
- **Pass an absolute path.** A kit added as `./claude-tools/` is recorded in a
  way that later re-resolves against `$HOME` — a subsequent `sbx kit add` of any
  kit then fails with `path does not exist` for the original one.

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
    sbx kit add <sandbox> ./.sbx/kits/claude-tools/

Repeat until the install completes — a blocked step can mask the host the *next*
step needs, so expect more than one pass. Record the reason for each host in the
table below as you add it, so a later reader can tell a required host from a
leftover.

| Host | Needed for |
| ---- | ---------- |
| _(none yet — populate from `sbx policy log`)_ | |

For reference, rtk's installer is known to reach `raw.githubusercontent.com`
(the script), `github.com` (the `/releases/latest` redirect and the download),
`release-assets.githubusercontent.com` (where that download redirects), and
`api.github.com` (only as a fallback when the redirect parse fails). Treat that
as a hint for interpreting the log, not as a list to paste in — some of it may
already be covered by the active network preset, and the fallback host may never
be touched.

## Staying hot-addable

This kit deliberately stays inside the subset `sbx kit add` supports —
`environment.variables`, `setup.install`, and `permissions.network.allow`. That
is the whole point of the kit: adding a tool should be a restart, not a sandbox
recreate. Two consequences to respect when extending it:

- **No `setup.files` and no `agentInstructions`.** Anything that has to land as
  a file must be written by an `install` command instead, or split into a
  separate kit that is accepted at creation time only.
- **Every install command must be idempotent.** They re-run whenever the kit is
  applied. rtk's installer
  overwrites its own binary cleanly and `rtk init -g` is safe to repeat; new
  steps must be equally re-runnable, which for most package installs means a
  guard rather than a bare install command.

## Install steps

### mattpocock-skills

```yaml
    - command: |
        set -eu
        claude plugin marketplace list | grep -q claude-plugins-official \
          || claude plugin marketplace add anthropics/claude-plugins-official
        claude plugin list | grep -q mattpocock-skills \
          || claude plugin install mattpocock-skills@claude-plugins-official
      user: "1000"
      description: Install the mattpocock-skills plugin
```

Verified in a scratch sandbox: the plugin installs, reports `✔ enabled`, and
ships 35 skills.

The upstream README says `claude plugins install mattpocock-skills` works with
"no additional setup, because the plugin is in the official marketplace." That
holds on a host but **not in a fresh sandbox, which has no marketplaces
configured at all** — not even `claude-plugins-official`. So the marketplace has
to be added first; the install itself is then exactly what the README describes,
and updates still arrive from the official source.

Two details that cost a debugging pass each, worth knowing before adding more
plugins:

- **`claude plugin install` has no `-y` flag in-sandbox.** The sandbox ships
  Claude Code 2.1.221, whose `install` accepts only `--config` and `--scope`;
  passing `-y` fails outright with `unknown option`. A newer host CLI is not a
  guide to what the sandbox accepts — check with
  `sbx exec <sandbox> -- claude plugin install --help`.
- **The `grep` guards are what make the step idempotent.** Both commands run
  again on every kit application, and neither is a no-op on its own.

Per-repo setup (`/setup-matt-pocock-skills`) is interactive and stays a manual
step; a kit cannot run it.

### Not yet enabled

`rtk` and `i-have-adhd` are written and were verified working before being
commented out. `rtk` needs one extra step beyond its docs: **`rtk init -g` does
not register the hook**, it only writes `~/.claude/RTK.md` and prints the JSON
for you to paste, so the kit has to merge the `PreToolUse` entry into
`settings.json` itself.

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
