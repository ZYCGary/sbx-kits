# buf

Mixin kit that installs the [Buf CLI](https://buf.build/docs/cli/installation/#npm) from
npm and allowlists `buf.build`. Agent-neutral, one install step, no `files/` —
hot-addable.

npm is the install channel Buf documents alongside the standalone binary; it needs no
sudo here because the agent owns the npm global prefix. The `@bufbuild/buf` package
resolves a platform-specific binary through optional dependencies on
`registry.npmjs.org`, which the Balanced preset already allows.

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/buf/ claude <workspace>
    sbx run claude --kit /abs/path/to/buf/
    sbx kit add <sandbox> /abs/path/to/buf/     # existing one, restarts it

Verify:

    buf --version
    buf lint

No host-side prerequisites.

## Entries

| Entry | Note |
| ----- | ---- |
| `npm install -g @bufbuild/buf`, `user: "1000"` | `NPM_CONFIG_PREFIX=/usr/local/share/npm-global` is set container-wide and is `agent:agent`, so the agent installs there without sudo. `/usr/local/share/npm-global/bin` is already on `PATH`. |
| `permissions.network.allow: buf.build` | The Buf Schema Registry host — needed for `buf dep update` against BSR modules and for `buf push`. Local-only workflows (`buf lint`, `buf build`, `buf generate` with local plugins) do not touch it. |

## Notes

- **Authentication is not provided.** `buf push` and private BSR modules need a token:
  `buf registry login` interactively, or `BUF_TOKEN` in the environment. Do not put a
  token in the kit.
- **Rule matching is exact in both directions.** `buf.build` covers the registry host
  only. If a `buf` command is still blocked, take the host from `sbx policy log` and add
  it — do not guess subdomains.
- **Local plugins are out of scope.** Remote plugins (`buf.build/...` in `buf.gen.yaml`)
  work over the allowlisted host; local `protoc-gen-*` binaries must be installed
  separately.

## Cleanup

Goes away with the sandbox. To remove by hand inside a running one:

    npm uninstall -g @bufbuild/buf

The network rule cannot be removed from a running sandbox — kits are not detachable.
Recreate without `--kit` to drop it.
