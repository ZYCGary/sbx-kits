# pnpm

Mixin kit that installs [`pnpm`](https://pnpm.io) inside a Docker Sandbox.
Agent-neutral. One install step, no `files/`, so it is hot-addable.

Schema and CLI:
[kit reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference.md),
[kits guide](https://docs.docker.com/ai/sandboxes/customize/kits.md).

## What breaks without it

The image ships Node 22 and npm but no pnpm, and the obvious way in fails twice:

    $ corepack enable pnpm
    Internal Error: EACCES: permission denied, symlink
      '../share/nodejs/corepack/dist/pnpm.js' -> '/usr/bin/pnpm'

Corepack puts its shims next to the `node` binary — `/usr/bin`, which the `agent`
user cannot write. Redirecting them (`--install-directory ~/.local/bin`) clears
that, and then pnpm will not run at all:

    $ pnpm --version
    TypeError [ERR_VM_DYNAMIC_IMPORT_CALLBACK_MISSING]: A dynamic import
      callback was not specified.
        at Object.<anonymous> (~/.cache/node/corepack/pnpm/11.22.0/bin/pnpm.cjs:3:1)
        at Module2._compile (/usr/share/nodejs/corepack/dist/lib/corepack.cjs:39564:34)

The image's corepack is the Debian package at `/usr/share/nodejs/corepack`, too
old to load pnpm 11, which uses dynamic `import()`. So this kit skips corepack
and installs pnpm from the registry instead.

Nothing is lost by skipping it: **pnpm 11 honours `packageManager` itself**, so
version pinning still works. In a repo pinning `pnpm@10.15.0`, the installed
pnpm 11 fetches and hands off to 10.15.0, and `pnpm --version` reports
`10.15.0` (measured in-sandbox). Corepack is not needed to respect the pin.

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/pnpm/ claude <workspace>
    sbx run claude --kit /abs/path/to/pnpm/
    sbx kit add <sandbox> /abs/path/to/pnpm/     # existing one, restarts it

Prefer `sbx create --kit`. `sbx kit add` works here — the kit ships no `files/` —
but an already-attached kit cannot be re-added and cannot be removed, so
updating the kit still means `sbx rm` + `sbx create`.

No host-side prerequisites — no credentials, no host state.

## What it does, and why

| Entry                                    | Why                                                                                                                                                                                                                             |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm install -g pnpm`, as `user: "1000"` | `NPM_CONFIG_PREFIX=/usr/local/share/npm-global` is set container-wide and that tree is `agent:agent`, so the agent installs there without sudo and can update it later. `/usr/local/share/npm-global/bin` is already on `PATH`. |

The kit ships no `permissions.network.allow` rules and has not needed any; the
Balanced preset already covers `registry.npmjs.org`, which is all that
`npm install -g pnpm`, pnpm's own `packageManager` hand-off, and ordinary
installs require. If a step is ever blocked, take the hosts from
`sbx policy log`, never from reading an install script.

## Known limitation: `pnpm add -g` does not work

Deliberately out of scope. Project-level pnpm works; global installs fail:

    $ pnpm add -g <pkg>
    [ERROR] The configured global bin directory
      "/home/agent/.local/share/pnpm/bin" is not in PATH

pnpm 11's global bin dir is `$PNPM_HOME/bin` — not `$PNPM_HOME`, as older pnpm
docs and `pnpm setup` imply — and nothing puts it on `PATH`. `environment.variables`
cannot fix this, because the kit reference reserves `PATH`.

The fix, if it is ever wanted, is an install step appending an export to
`/etc/sandbox-persistent.sh` (`agent:agent 0644`, so a `user: "1000"` step can write
it). That needs two guards, both verified necessary in-sandbox: the export itself
guarded by a marker variable, since the file is sourced before *every* bash command
and an unguarded `export PATH=` grows the variable once per command; and the append
guarded by a sentinel comment, so re-applying the kit does not duplicate the block.

`pnpm setup` is not the answer — it edits `~/.bashrc`, which non-interactive shells,
including every Bash tool call, never read.

## Cleanup

Everything lives in the sandbox and goes away with it.

If you previously ran `corepack enable pnpm` by hand in a sandbox, its shim sits
in `~/.local/bin`, which precedes `/usr/local/share/npm-global/bin` on `PATH` and
will shadow this kit's pnpm with the broken one. Drop it:

    corepack disable pnpm --install-directory ~/.local/bin
    rm -f ~/.local/bin/pnpm ~/.local/bin/pnpx
