# Mautic Docker Container Image

[![Build Status](https://github.com/wodby/mautic/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/mautic/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/mautic.svg)](https://hub.docker.com/r/wodby/mautic)

[Mautic](https://www.mautic.org), the open source marketing automation platform, ready to run. The image holds Mautic's
[recommended Composer project](https://github.com/mautic/recommended-project) with its assets built, on the Apache
variant of [wodby/php](https://github.com/wodby/php): Apache serves Mautic and its `.htaccess` rules and passes PHP to
PHP-FPM in the same container. It adds a command that installs Mautic into an empty database or migrates an installed
one, and workers for Mautic's cron jobs and queues.

## Docker Images

❗For better reliability we release images with stability tags (`wodby/mautic:7-rN`) which correspond to
[git tags](https://github.com/wodby/mautic/releases). We strongly recommend using images only with stability tags.

- Base image: [wodby/php](https://github.com/wodby/php) `8.4-apache`, pinned by digest
- [GitHub actions builds](https://github.com/wodby/mautic/actions)
- [Docker Hub](https://hub.docker.com/r/wodby/mautic)

| Tag                   | Mautic | PHP |
|-----------------------|--------|-----|
| `7`, `7.2`, `latest`  | 7.2    | 8.4 |

All images are built for `linux/amd64` and `linux/arm64`.

## Running

The default command runs Apache and PHP-FPM on port 80. The same image runs the workers and the install command:

| Command          | What it does                                                                                       |
|------------------|----------------------------------------------------------------------------------------------------|
| _(default)_      | Serves Mautic on port 80                                                                           |
| `mautic-update`  | Installs Mautic into an empty database, or migrates the database of an installed Mautic. Run it after every new image |
| `mautic-cron`    | Runs Mautic's cron jobs one after another, then again every `MAUTIC_CRON_INTERVAL` seconds         |
| `mautic-worker`  | Sends queued email and records queued page hits with `messenger:consume`                           |

Every container of a Mautic site must share the files directory, `/mnt/files`, and the database. Mautic needs MariaDB
10.11 or later or MySQL 8.4 or later, and can't connect to a database server over TLS.

## Installing and updating

`mautic-update` runs `bin/console mautic:install` when Mautic isn't installed:

- The database is the one in `DB_*`, and the administrator is `MAUTIC_ADMIN_USERNAME` (default `admin`),
  `MAUTIC_ADMIN_PASSWORD` (at least 6 characters) and `MAUTIC_ADMIN_EMAIL`. The installer reads them from the settings
  file rather than its command line, and the administrator's entries are removed from the file when it ends. Without a
  password or email the command fails and installs nothing.
- Email goes out through `MSMTP_HOST`:`MSMTP_PORT`, from the administrator's address with `MAUTIC_SITE_NAME` as the
  sender name, and email and page hits are queued in the database for `mautic-worker`. These are Mautic settings and
  can be changed in Mautic afterwards.
- The installer would rename existing tables and start over, so `mautic-update` refuses to install into a database
  that has any tables. That happens when the settings file is lost: restore it rather than reinstalling.

When Mautic is installed, `mautic-update` runs `doctrine:migrations:migrate` and `mautic:plugins:reload`.

## Files

Mautic keeps these in the files directory, `/mnt/files`; the paths in the code are links to it:

| In the code            | In the files directory          |
|------------------------|---------------------------------|
| `config/local.php`     | `config/local.php`              |
| `docroot/media/files`  | `media/files`                   |
| `docroot/media/images` | `media/images`                  |
| `docroot/translations` | `translations`                  |
| `var/import`           | `import`                        |
| `var/logs`             | `logs`                          |

`config/local.php` holds Mautic's secret key and every setting saved in Mautic. Back it up with the database. PHP
sessions are kept in `/mnt/files/sessions`, so any container can serve a signed-in user. Mautic's cache stays in each
container.

Apache doesn't serve `/media/files/` or `/translations/` (Mautic serves uploaded files itself), doesn't run scripts in
`/media/images/`, and doesn't serve the web installer.

## Environment Variables

The variables of [wodby/php](https://github.com/wodby/php), including its `-apache` variant, apply. In addition:

| Variable                    | Default                     | Description                                                                       |
|-----------------------------|-----------------------------|-----------------------------------------------------------------------------------|
| `DB_HOST`                   |                             |                                                                                   |
| `DB_PORT`                   | `3306`                      |                                                                                   |
| `DB_NAME`                   |                             |                                                                                   |
| `DB_USERNAME`               |                             |                                                                                   |
| `DB_PASSWORD`               |                             |                                                                                   |
| `MAUTIC_SITE_URL`           | `WODBY_PRIMARY_URL`         | The site's public address once Mautic is installed; the one saved in Mautic is ignored |
| `MAUTIC_TRUSTED_PROXIES`    | `PRIVATE_SUBNETS`           | Comma-separated addresses of the proxies whose forwarded headers are trusted       |
| `MAUTIC_ADMIN_USERNAME`     | `admin`                     | Installation only                                                                 |
| `MAUTIC_ADMIN_PASSWORD`     |                             | Installation only                                                                 |
| `MAUTIC_ADMIN_EMAIL`        |                             | Installation only                                                                 |
| `MAUTIC_SITE_NAME`          | `Mautic`                    | Installation only: the sender name of Mautic's email                              |
| `MSMTP_HOST`, `MSMTP_PORT`  | `25`                        | Installation only: the SMTP server                                                |
| `MAUTIC_CRON_INTERVAL`      | `300`                       | Seconds between the starts of `mautic-cron` runs                                  |
| `MAUTIC_CRON_COMMANDS`      | Mautic's required jobs      | Space-separated console commands `mautic-cron` runs                               |
| `MAUTIC_WORKER_TRANSPORTS`  | `email hit`                 | Queues `mautic-worker` consumes                                                   |

The database and site address come from these variables through `config/parameters_local.php`, which Mautic reads
after `config/local.php` and never writes.

`mautic-cron` runs `mautic:segments:update`, `mautic:campaigns:update`, `mautic:campaigns:trigger`,
`mautic:messages:send`, `mautic:broadcasts:send`, `mautic:import`, `mautic:contacts:scheduled_export`,
`mautic:webhooks:process` and `mautic:reports:scheduler` by default.

The image sets `APACHE_DOCUMENT_ROOT=/var/www/html/docroot`, `PHP_FPM_USER=wodby` (PHP-FPM writes as the owner of the
code, like the console commands), `PHP_MAX_EXECUTION_TIME=300`, 64 MB upload limits, `PHP_ZEND_ASSERTIONS=-1` and
`PHP_ZEND_EXCEPTION_IGNORE_ARGS=1`.

## Building

`make` builds the image for `MAUTIC_VER` on the pinned base image, and `make test` runs the tests in `tests/` with
MariaDB and Mailpit. `make BASE_IMAGE=wodby/php:8.4-apache` builds on another base image.
