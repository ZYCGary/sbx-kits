# laravel-sail

Mixin kit that opens the outbound hosts needed to build the Laravel Sail runtime image.
Agent-neutral, network rules only, no `files/` — hot-addable.

Without it the Sail Dockerfile fails at `apt-get install php8.4-*` with exit code 100.

## Usage

    sbx run claude --kit /abs/path/to/laravel-sail/       # new sandbox
    sbx kit add <sandbox> /abs/path/to/laravel-sail/      # existing one, restarts it

No host-side prerequisites.

## The hosts

The Balanced preset already covers `dl.yarnpkg.com`, `registry.npmjs.org`,
`**.packagist.org`, `playwright.azureedge.net`, and `ports.ubuntu.com`. The gaps:

| Host | Dockerfile step | Preset |
| ---- | --------------- | ------ |
| `keyserver.ubuntu.com` | ondrej PPA GPG key | absent |
| `ppa.launchpadcontent.net` | all `php8.4-*` packages | has `ppa.launchpad.net`, a different domain |
| `deb.nodesource.com` | nodejs key and packages | has `nodesource.com`; exact rules do not match subdomains |
| `getcomposer.org` | composer installer script | absent |
| `www.postgresql.org` | pgdg signing key (ACCC4CF8.asc) | absent |
| `apt.postgresql.org` | `postgresql-client-*` | absent |

If the list drifts, add from `sbx policy log`, never from the Dockerfile.

`http-intake.logs.us5.datadoghq.com` is deliberately **not** allowlisted — source
unattributed, default-deny is holding it.

## Cleanup

No host state; rules disappear with the sandboxes that loaded the kit. If these hosts
were previously allowed globally, those rules survive:

    sbx policy ls --wide --source kit    # expect kit:laravel-sail
    sbx policy rm network --resource keyserver.ubuntu.com
    # ...repeat per host
