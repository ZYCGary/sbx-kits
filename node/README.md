# node

Mixin kit that adds Node.js 24 LTS with `npm`, `npx` and `corepack` to a sandbox.
Agent-neutral. The v3 `claude` workload (a Docker Hardened Image) ships no Node, so
`pnpm/`, `buf/`, `ccstatusline/` and `mattpocock-skills-claude/` `require` this kit.

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/node/ claude <workspace>
    sbx run claude --kit /abs/path/to/node/

Host prerequisite: a buildx builder with an OCI exporter (this is the repo's one kit
with a build recipe). OrbStack's default `docker` driver has none:

    docker buildx create --name sbx-kits --driver docker-container --bootstrap
    BUILDX_BUILDER=sbx-kits sbx env create <file>.sbxenv.yaml

No network rules: the download happens on the host builder, not in the sandbox.

## Entries

| Entry | Note |
| ----- | ---- |
| `FROM node:24-trixie-slim` | Official build, glibc-linked; runs on the workload's Debian 13 base. Floating `24` tag — rebuilt per sandbox create, so patch releases track upstream. |
| `cp -a` `node`, `npm`, `npx`, `corepack`, `lib/node_modules` → `FROM scratch` | Only Node lands in the sandbox; the overlay's `/usr/local/{bin,lib,share}` entries match the base's `root 0755`. |
| `/usr/local/share/npm-global`, `chown 1000:1000` | The workload already sets `NPM_CONFIG_PREFIX` to it and puts its `bin/` on `PATH`, but does not create it. Agent-owned, so `npm install -g` needs no sudo. |
| `provides: ["node@24"]` | What `requires: ["node"]` in other kits resolves against. |

## Cleanup

Goes away with the sandbox. The image layer stays in the builder's cache:
`docker buildx prune --builder sbx-kits`.
