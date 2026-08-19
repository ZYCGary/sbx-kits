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
documents — no environment overrides:

    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

It lands in `~/.local/bin`, the installer's default. That is the right place
here rather than merely an acceptable one: the sandbox's own `claude` binary
lives at `/home/agent/.local/bin/claude`, so the directory is demonstrably on
the agent's `PATH` already. An earlier version of this kit redirected the
install to `/usr/local/bin` via `RTK_INSTALL_DIR` out of a worry about `PATH`
that turned out to be unfounded.

The installer resolves the latest release, verifies it against the release's
`checksums.txt`, and re-runs cleanly, so it stays current as new versions ship.
To pin, export `RTK_VERSION=vX.Y.Z` in the step.

**Both steps carry `user: "1000"`,** and the reason is the same for each: they
resolve their target from `$HOME`, not from a fixed path. `setup.install` steps
run as root unless told otherwise, and root's `$HOME` is `/root` — so as root
the installer would write `/root/.local/bin/rtk` and `rtk init -g` would write
`/root/.claude/`. Neither is where the agent looks. UID 1000 is the non-root
`agent` user that every sandbox image is required to provide; the field takes
the numeric UID, not the name.

(`setup.startup` steps have the opposite default — UID 1000 — so there it is a
step needing *root* that must be spelled out.)

The `PATH="$HOME/.local/bin:$PATH"` prefix on the second step is a hedge: each
install step gets a fresh environment, and it is not established that
`~/.local/bin` is on `PATH` in that context the way it is in the agent's own
shell. The prefix costs nothing and removes the question.

**Worth verifying on first run:** this all assumes `sbx` sets `$HOME` to
`/home/agent` for a step declared `user: "1000"`. If it instead keeps root's
environment while dropping privileges, the installer will fail trying to write
into `/root` — loudly, and the fix is to hardcode
`RTK_INSTALL_DIR=/home/agent/.local/bin`. Confirm with:

    sbx exec <sandbox> -- ls -l /home/agent/.local/bin/rtk
    sbx exec <sandbox> -- grep -c rtk /home/agent/.claude/settings.json

The official guide's final instruction — restart Claude Code — has no analogue
here: the agent has not started yet when `setup.install` runs.

## Cleanup

The kit creates no host state. Everything it installs lives in sandboxes that
load it and disappears when those sandboxes are removed.
