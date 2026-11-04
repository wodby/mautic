# check=skip=InvalidDefaultArgInFrom

# The Makefile supplies the required digest-pinned BASE_IMAGE argument: the
# Apache variant of wodby/php, which serves the application and runs PHP-FPM in
# one container.
ARG BASE_IMAGE

# Mautic's recommended Composer project. Its Composer scripts install the npm
# packages and build Mautic's JavaScript and CSS, so this stage has Node.js.
FROM ${BASE_IMAGE} AS build

ARG MAUTIC_VER

USER root

RUN apk add --no-cache nodejs npm

USER wodby

# An npm package Mautic uses reports its installations to IBM unless told not to.
ENV IBM_TELEMETRY_DISABLED=true \
    COMPOSER_HOME=/tmp/composer

RUN set -ex; \
    composer create-project "mautic/recommended-project:${MAUTIC_VER}" /var/www/html \
        --no-interaction --no-progress --no-dev; \
    # Assets are built; the packages that built them aren't needed. \
    rm -rf node_modules /tmp/composer /home/wodby/.npm; \
    # The asset commands leave a cache compiled before Mautic has settings. \
    # Each container compiles its own on the first request. \
    rm -rf var/cache/*

FROM ${BASE_IMAGE}

ARG MAUTIC_VER

ENV MAUTIC_VER="${MAUTIC_VER}" \
    APACHE_DOCUMENT_ROOT="/var/www/html/docroot" \
    \
    # PHP-FPM runs as the owner of the code, like Mautic's console commands, \
    # so the cache, settings and files any of them write stay writable by the \
    # others. \
    PHP_FPM_USER="wodby" \
    # Imports, exports and installation take longer than PHP's default limit. \
    PHP_MAX_EXECUTION_TIME="300" \
    PHP_UPLOAD_MAX_FILESIZE="64M" \
    PHP_POST_MAX_SIZE="64M" \
    # Mautic's installer asks for both. \
    PHP_ZEND_ASSERTIONS="-1" \
    PHP_ZEND_EXCEPTION_IGNORE_ARGS="1"

COPY --from=build --chown=wodby:wodby /var/www/html /var/www/html
COPY --chown=wodby:wodby share/parameters_local.php /var/www/html/config/parameters_local.php
COPY apache/mautic.conf /etc/apache2/conf.d/mautic.conf
COPY bin /usr/local/bin/

# Mautic's settings, uploads, language packs, imports and logs are kept in the
# files directory, a volume shared by every replica and worker, so they outlive
# the container. The generated assets in docroot/media stay in the image.
RUN set -ex; \
    cd /var/www/html; \
    ln -s "${FILES_DIR}/config/local.php" config/local.php; \
    for link in \
        "docroot/media/files:${FILES_DIR}/media/files" \
        "docroot/media/images:${FILES_DIR}/media/images" \
        "docroot/translations:${FILES_DIR}/translations" \
        "var/import:${FILES_DIR}/import" \
        "var/logs:${FILES_DIR}/logs"; \
    do \
        path="${link%%:*}"; \
        rm -rf "${path}"; \
        mkdir -p "$(dirname "${path}")"; \
        ln -s "${link#*:}" "${path}"; \
    done
