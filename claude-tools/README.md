# claude-tools

Mixin kit that installs the tooling the `claude` agent expects inside a Docker
Sandbox. Attached to every new sandbox at creation time. Declares
`requires.agent: claude`, since it registers a Claude Code hook.

- [`rtk`](https://github.com/rtk-ai/rtk)
- [`i-have-adhd`](https://github.com/ayghri/i-have-adhd)
- [`mattpocock-skills`](https://www.aihero.dev/skills)
- [`ccstatusline`](https://github.com/sirmalloc/ccstatusline)

Schema and CLI:
[kit reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference.md),
[kits guide](https://docs.docker.com/ai/sandboxes/customize/kits.md).

## Usage

    sbx create --name <sandbox> --kit /abs/path/to/claude-tools/ claude <workspace>
    sbx run claude --kit /abs/path/to/claude-tools/

Creation time only — the kit ships a `files/` directory, which `sbx kit add`
refuses:

    ERROR: kit "claude-tools" declares files, which the kit-add recreate flow
    does not yet apply

So updating the kit means `sbx rm` + `sbx create` on each sandbox.

No host-side prerequisites — no credentials, no host state. Everything the kit
installs lives in the sandboxes and goes away with them.

See `spec.yaml` for the install steps. The kit ships no
`permissions.network.allow` rules and has not needed any — if a step is ever
blocked, take the hosts from `sbx policy log`, never from reading an install
script, and record each with its reason.

Two things not to regress when editing the steps: `rtk init -g` must keep
`--auto-patch` or the hook is never registered, and `statusLine` must be merged
into `~/.claude/settings.json` with `jq`, never written over it — rtk's hook and
the plugin registrations live in the same file.
