# laravel-sail

Mixin kit that opens the outbound hosts required to build the Laravel Sail
runtime image inside a Docker Sandbox. Pairs with the `claude` agent, but
carries nothing agent-specific — any agent that needs to run `sail build`
in-sandbox can use it.

Without this kit the Sail Dockerfile fails at `apt-get install php8.4-*`
with exit code 100, because the ondrej PPA and its GPG keyserver are blocked
by the default-deny network policy.

## Usage

Creating a new sandbox:

    sbx run claude --kit ./.sbx/kits/laravel-sail/

Adding to a sandbox that already exists:

    sbx kit add <sandbox> ./.sbx/kits/laravel-sail/

`sbx kit add` restarts the sandbox. Installed packages, Docker images,
volumes, and agent history survive the restart. Kits cannot be removed from
a running sandbox — remove and recreate it to start clean.

## Host-side prerequisites

None. The kit declares network rules only: no credentials, no install
commands, no injected files.

## Why these six hosts

The allowlist is the complete outbound contract for the build. The Balanced
preset already covers `dl.yarnpkg.com`, `registry.npmjs.org`,
`**.packagist.org`, `playwright.azureedge.net`, and `ports.ubuntu.com`, so
those are deliberately absent. What remains are the gaps:

| Host                       | Dockerfile step                 | Why the preset misses it                                             |
| -------------------------- | ------------------------------- | -------------------------------------------------------------------- |
| `keyserver.ubuntu.com`     | ondrej PPA GPG key              | not in any preset group                                              |
| `ppa.launchpadcontent.net` | all `php8.4-*` packages         | preset has `ppa.launchpad.net` — a different domain                  |
| `deb.nodesource.com`       | nodejs key and packages         | preset has `nodesource.com`; an exact rule does not match subdomains |
| `getcomposer.org`          | composer installer script       | not in any preset group                                              |
| `www.postgresql.org`       | pgdg signing key (ACCC4CF8.asc) | not in any preset group                                              |
| `apt.postgresql.org`       | `postgresql-client-*`           | not in any preset group                                              |

The two near-miss cases are the ones worth remembering: wildcard semantics
are strict in both directions, so `example.com` does not match subdomains and
`*.example.com` does not match the root.

Package managers make the contract wider than it looks — `apt-get update`
refreshes metadata for every configured source, not just the one whose
package you asked for. If the list drifts, `sbx policy log` shows the actual
blocked hosts; add from that rather than from the Dockerfile.

## Scope

Network rules only, which keeps the kit inside the subset `sbx kit add`
supports (`environment.variables`, `setup.install`,
`permissions.network.allow`). Adding a `deny` rule or an `agentInstructions`
block would push it outside that subset and force a sandbox recreate, so
anything beyond the allowlist belongs in a follow-up kit.

## Cleanup

The kit creates no host state. Its rules are scoped to sandboxes that load
it and disappear when those sandboxes are removed.

If you previously added these hosts with `sbx policy allow network`, those
rules are global and remain in effect. Verify the kit rules are live first,
then drop the globals:

    sbx policy ls --wide --source kit    # expect kit:laravel-sail
    sbx policy rm network --resource keyserver.ubuntu.com
    # ...repeat per host

## Known gap

Something in the sandbox repeatedly attempts to reach
`http-intake.logs.us5.datadoghq.com`. The source is unidentified and it is
deliberately not allowlisted. Default-deny is currently holding it.
