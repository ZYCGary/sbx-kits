# laravel-sail

Mixin kit that opens the outbound hosts required to build the Laravel Sail
runtime image inside a Docker Sandbox. Agent-neutral. Network rules only — no
credentials, no install commands, no files — so it is hot-addable.

Without it the Sail Dockerfile fails at `apt-get install php8.4-*` with exit
code 100: the ondrej PPA and its GPG keyserver are blocked by default-deny.

Schema and CLI:
[kit reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference.md),
[kits guide](https://docs.docker.com/ai/sandboxes/customize/kits.md).

## Usage

    sbx run claude --kit /abs/path/to/laravel-sail/       # new sandbox
    sbx kit add <sandbox> /abs/path/to/laravel-sail/      # existing one, restarts it

## The hosts

The Balanced preset already covers `dl.yarnpkg.com`, `registry.npmjs.org`,
`**.packagist.org`, `playwright.azureedge.net`, and `ports.ubuntu.com`. These
are the gaps:

| Host                       | Dockerfile step                 | Why the preset misses it                                             |
| -------------------------- | ------------------------------- | -------------------------------------------------------------------- |
| `keyserver.ubuntu.com`     | ondrej PPA GPG key              | not in any preset group                                              |
| `ppa.launchpadcontent.net` | all `php8.4-*` packages         | preset has `ppa.launchpad.net` — a different domain                  |
| `deb.nodesource.com`       | nodejs key and packages         | preset has `nodesource.com`; an exact rule does not match subdomains |
| `getcomposer.org`          | composer installer script       | not in any preset group                                              |
| `www.postgresql.org`       | pgdg signing key (ACCC4CF8.asc) | not in any preset group                                              |
| `apt.postgresql.org`       | `postgresql-client-*`           | not in any preset group                                              |

If the list drifts, add from `sbx policy log`, never from the Dockerfile.

`http-intake.logs.us5.datadoghq.com` is deliberately **not** allowlisted — the
source of those attempts is unidentified. Default-deny is holding it.

## Cleanup

No host state; the rules disappear with the sandboxes that loaded the kit. If you
previously added these hosts globally with `sbx policy allow network`, those
rules survive — confirm the kit's are live, then drop the globals:

    sbx policy ls --wide --source kit    # expect kit:laravel-sail
    sbx policy rm network --resource keyserver.ubuntu.com
    # ...repeat per host
