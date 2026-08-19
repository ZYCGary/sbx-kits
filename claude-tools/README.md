# claude-tools

Mixin kit that installs the tooling the `claude` agent expects to find inside a
Docker Sandbox. Intended to be attached to every new sandbox, and re-applied to
existing ones as the kit grows.

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

**`rtk init -g`** runs as the agent user (`1000`), not root, because it writes
the hook and `RTK.md` into the agent's own `~/.claude/`. Running it as root
would write to root's home and the hook would silently never fire. The official
guide says to restart Claude Code afterwards; here the agent has not started
yet when `setup.install` runs, so there is nothing to restart.

## Why these hosts

All four are the installer's outbound contract, not guesses from the docs page:

| Host                                   | Needed for                                          |
| -------------------------------------- | --------------------------------------------------- |
| `raw.githubusercontent.com`            | fetching `install.sh` itself                        |
| `github.com`                           | the `/releases/latest` redirect and the download URL |
| `api.github.com`                       | the installer's fallback path for resolving the tag |
| `release-assets.githubusercontent.com` | where the download URL redirects to for the bytes   |

Two of these are easy to miss. GitHub serves release assets from a redirect
host, so allowing `github.com` alone yields a download that dies after the 302.
And the installer resolves the version from the redirect first, falling back to
the REST API — the fallback only fires when the primary path fails, so leaving
`api.github.com` blocked would break installs rarely and confusingly rather than
never. If a future step's downloads fail, read the real blocked host out of
`sbx policy log` rather than guessing from the URL.

## Cleanup

The kit creates no host state. Everything it installs lives in sandboxes that
load it and disappears when those sandboxes are removed.
