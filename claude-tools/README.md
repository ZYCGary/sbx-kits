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
  `sbx kit add`, which is how this kit is meant to be updated. rtk's installer
  overwrites its own binary cleanly and `rtk init -g` is safe to repeat; new
  steps must be equally re-runnable, which for most package installs means a
  guard rather than a bare install command.

## Install steps

The kit follows the shape the Docker docs use for this exact case — their `nvm`
example is the same problem, a `curl … | sh` installer that writes into the
agent's home:

```yaml
setup:
  install:
    - command: "curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
      user: "1000"
      description: Install rtk
    - command: "rtk init -g"
      user: "1000"
      description: Register the rtk hook in the agent's Claude config
```

That is rtk's official installer with no environment overrides, followed by the
official Claude Code setup step, `rtk init -g`.

**Install location.** rtk lands in `~/.local/bin`, the installer's default. That
is the right place rather than merely a tolerable one: the sandbox's own
`claude` binary lives at `/home/agent/.local/bin/claude`, and an install step's
`PATH` is

    /home/agent/.local/bin:/usr/local/share/npm-global/bin:/usr/local/sbin:...

so the second step resolves `rtk` with no help. An earlier version of this kit
redirected the install to `/usr/local/bin` via `RTK_INSTALL_DIR` and prefixed
the second step with `PATH="$HOME/.local/bin:$PATH"`; both were guarding against
a problem that does not exist here.

**Why `user: "1000"`.** `setup.install` steps default to root, and root's
`$HOME` is `/root`. Both steps resolve their target from `$HOME` — the installer
writes `$HOME/.local/bin`, and `rtk init -g` writes `$HOME/.claude/` — so as
root they would land in `/root` while still reporting success. Measured with a
probe kit:

    default        uid=0    user=root   HOME=/root
    user: "1000"   uid=1000 user=agent  HOME=/home/agent

Ownership is a second, independent reason: files a root step creates under
`/home/agent` stay `root:root`, which would leave the agent unable to rewrite
its own `settings.json` later. The numeric form is what the Docker examples use;
`"agent"` also works.

**When these run.** `setup.install` runs once when the kit is applied — at
sandbox creation or at `sbx kit add` — and *not* on ordinary restarts (verified:
a stop/start left the step's run counter at 1). So the idempotency that matters
is across re-applications of this kit, which is exactly the workflow it is built
for. rtk's installer overwrites its own binary cleanly and `rtk init -g` is safe
to repeat.

`setup.startup` is the other option and is wrong for this kit: it runs on every
container start and is meant for daemons, cache warming, and config refresh.
Nothing here needs to happen more than once per kit application.

The official guide's last instruction — restart Claude Code — has no analogue
here: the agent has not started yet when `setup.install` runs.

## Cleanup

The kit creates no host state. Everything it installs lives in sandboxes that
load it and disappears when those sandboxes are removed.
