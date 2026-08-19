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

| Tool  | What it is                                       | How it's installed          |
| ----- | ------------------------------------------------ | --------------------------- |
| `rtk` | CLI proxy that trims token usage on dev commands | official `install.sh` script |

Claude Code plugins and marketplaces are the next additions; each is added
deliberately rather than in bulk.

## Usage

Creating a new sandbox:

    sbx run claude --kit ./.sbx/kits/claude-tools/

Adding to a sandbox that already exists, or picking up a newer version of this
kit:

    sbx kit add <sandbox> ./.sbx/kits/claude-tools/

`sbx kit add` restarts the sandbox and re-runs `setup.install`. Installed
packages, Docker images, volumes, and agent history survive the restart.

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
- **Every install command must be idempotent.** They re-run on every
  `sbx kit add` and on every restart. rtk's installer overwrites its own binary
  cleanly and `rtk init -g` is safe to repeat; new steps must be equally
  re-runnable, which for most package installs means a guard rather than a bare
  install command.

## Install steps

**rtk** is installed with the project's own installer, exactly as its README
documents:

    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

The one deviation is `RTK_INSTALL_DIR=/usr/local/bin` — a variable the installer
itself supports. Its default is `~/.local/bin`, which is not reliably on `PATH`
in the sandbox image; the script notices and prints a warning telling you to edit
your shell profile. Installing to `/usr/local/bin` (the step runs as root)
avoids editing a dotfile the kit does not otherwise own, and means the `rtk`
hook resolves no matter which shell Claude Code spawns.

The installer resolves the latest release, verifies it against the release's
`checksums.txt`, and re-runs cleanly, so it stays current as new versions ship.
To pin instead, export `RTK_VERSION=vX.Y.Z` alongside `RTK_INSTALL_DIR`.

**`rtk init -g`** carries `user: "1000"`. Sandbox images are required to provide
a non-root `agent` user at UID 1000, and `setup.install` steps run as root
(`user: "0"`) unless told otherwise — so without that line, `rtk init -g` would
write the hook and `RTK.md` into *root's* `~/.claude/` instead of the agent's,
and the hook would silently never fire. The field takes the numeric UID, not the
name. The first step keeps the root default because `/usr/local/bin` is not
writable by the agent user.

(`setup.startup` steps have the opposite default — UID 1000 — so a startup step
needing root is the case that must be spelled out.)

The official guide says to restart Claude Code afterwards; here the agent has
not started yet when `setup.install` runs, so there is nothing to restart.

## Cleanup

The kit creates no host state. Everything it installs lives in sandboxes that
load it and disappears when those sandboxes are removed.
