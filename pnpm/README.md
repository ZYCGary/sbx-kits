# pnpm

Mixin kit that installs [`pnpm`](https://pnpm.io). Agent-neutral, one install step.

Requires the `node` kit (the v3 `claude` image ships no Node). Installs pnpm from the
registry rather than via corepack, so it does not depend on corepack's shim location.

pnpm 11 honours `packageManager` itself — in a repo pinning `pnpm@10.15.0` the installed
pnpm 11 hands off and `pnpm --version` reports `10.15.0`. Corepack is not needed for the
pin.

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/node/ --kit /abs/path/to/pnpm/ claude <workspace>
    sbx run claude --kit /abs/path/to/node/ --kit /abs/path/to/pnpm/

No host-side prerequisites, no network rules (`registry.npmjs.org` is in the Balanced
preset).

## Entries

| Entry | Note |
| ----- | ---- |
| `npm install -g pnpm`, `user: "1000"`, `env: [NPM_CONFIG_PREFIX]` | The workload sets `NPM_CONFIG_PREFIX=/usr/local/share/npm-global`; the `node` kit creates it `agent:agent`. v3 hooks see only declared env, hence `env:`, so the agent installs there without sudo and can update it later. `/usr/local/share/npm-global/bin` is already on `PATH`. |

## Known limitation: `pnpm add -g` does not work

Out of scope. Project-level pnpm works; global installs fail:

    $ pnpm add -g <pkg>
    [ERROR] The configured global bin directory
      "/home/agent/.local/share/pnpm/bin" is not in PATH

pnpm 11's global bin dir is `$PNPM_HOME/bin`, not `$PNPM_HOME`, and nothing puts it on
`PATH`. A v3 mixin has no static environment, and `PATH` is the workload's.

The fix, if wanted: an install step appending an export to
`/etc/sandbox-persistent.sh` (`agent:agent 0644`, writable by a `user: "1000"` step), with
two guards — a marker variable around the export, since the file is sourced before every
bash command and an unguarded `export PATH=` grows once per command; and a sentinel
comment around the append, so re-applying the kit does not duplicate it. `pnpm setup` is
not the answer — it edits `~/.bashrc`, which non-interactive shells never read.

## Cleanup

Goes away with the sandbox. A hand-run `corepack enable pnpm` leaves a shim in
`~/.local/bin`, which precedes `/usr/local/share/npm-global/bin` on `PATH` and shadows
this kit's pnpm:

    corepack disable pnpm --install-directory ~/.local/bin
    rm -f ~/.local/bin/pnpm ~/.local/bin/pnpx
