# claude-tools

Mixin kit that installs the tooling the `claude` agent expects to find inside a
Docker Sandbox. Intended to be attached to every new sandbox, and re-applied to
existing ones as the kit grows.

Currently installs:

| Tool  | What it is                                          | How it's installed              |
| ----- | --------------------------------------------------- | ------------------------------- |
| `rtk` | CLI proxy that trims token usage on dev commands    | pinned GitHub release tarball   |

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
  `sbx kit add` and on every restart. The rtk step checks the installed version
  and exits early; new steps should do the equivalent.

## Install steps

**rtk** is fetched as a pinned release tarball rather than through a package
manager — the Homebrew formula builds from source (it depends on Rust), and the
published `.deb` is amd64-only, so neither works in an arm64 sandbox. The
tarball is a single static binary and both Linux architectures are published,
so the step selects on `uname -m`, verifies a pinned SHA-256, and installs to
`/usr/local/bin`.

To bump the version, change `RTK_VERSION` in `spec.yaml` and replace both
digests from the release's `checksums.txt`:

    curl -sL https://github.com/rtk-ai/rtk/releases/download/v<VERSION>/checksums.txt | grep linux

**`rtk init --global --agent claude`** runs as the agent user (`1000`), not
root, because it writes the `PreToolUse` hook into the agent's own
`~/.claude/settings.json`. Running it as root would write to the wrong home and
the hook would silently never fire. This mirrors the host-side setup, so
commands are rewritten (`git status` → `rtk git status`) transparently
in-sandbox.

## Why these hosts

| Host                                | Needed for                                        |
| ----------------------------------- | ------------------------------------------------- |
| `github.com`                        | the release download URL                          |
| `release-assets.githubusercontent.com` | where that URL redirects to for the actual bytes |

GitHub serves release assets from a redirect host, so allowing `github.com`
alone yields a download that fails after the 302. If a future step's downloads
start failing, read the real blocked host out of `sbx policy log` rather than
guessing from the URL.

## Cleanup

The kit creates no host state. Everything it installs lives in sandboxes that
load it and disappears when those sandboxes are removed.
