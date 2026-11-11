# Moodle on Render — PHP + Apache + cron in one container
FROM php:8.3-apache

# Moodle release to install (e.g. 405 = 4.5 LTS, 502 = 5.2). Change and redeploy to upgrade.
ARG MOODLE_VERSION=502

# System packages + PHP extensions Moodle needs
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates git supervisor ghostscript \
        libpq-dev libicu-dev libzip-dev libpng-dev libjpeg62-turbo-dev \
        libfreetype6-dev libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" pgsql intl zip gd soap opcache exif \
    && rm -rf /var/lib/apt/lists/*

# Download the official Moodle release package
RUN curl -fsSL "https://download.moodle.org/download.php/direct/stable${MOODLE_VERSION}/moodle-latest-${MOODLE_VERSION}.tgz" \
        -o /tmp/moodle.tgz \
    && tar -xzf /tmp/moodle.tgz -C /var/www \
    && rm /tmp/moodle.tgz

# Microsoft 365 plugin suite (OpenID Connect SSO, Entra user sync, Teams, OneDrive, Outlook calendar, OneNote).
# Pulled from Microsoft's official repo on the branch matching this Moodle release.
# Plugins land in Moodle's web root (public/ on 5.1+). Set INSTALL_O365=0 to leave it out; set O365_BRANCH to pin a different branch or tag.
ARG INSTALL_O365=1
ARG O365_BRANCH=MOODLE_${MOODLE_VERSION}_STABLE
RUN if [ "$INSTALL_O365" = "1" ]; then \
        git clone --depth 1 --branch "$O365_BRANCH" https://github.com/microsoft/o365-moodle.git /tmp/o365 \
          || { echo "ERROR: branch $O365_BRANCH not found in microsoft/o365-moodle. Set O365_BRANCH to a valid branch."; exit 1; }; \
        if [ -d /var/www/moodle/public ]; then DEST=/var/www/moodle/public; else DEST=/var/www/moodle; fi; \
        if [ -d /tmp/o365/public ]; then SRC=/tmp/o365/public; else SRC=/tmp/o365; fi; \
        for dir in "$SRC"/*/; do \
            name=$(basename "$dir"); \
            case "$name" in .git|.github|tests|docs) continue ;; esac; \
            cp -a "$dir" "$DEST/"; \
        done; \
        test -f "$DEST/local/o365/version.php" && test -f "$DEST/auth/oidc/version.php" \
          || { echo "ERROR: Microsoft 365 plugins not found where expected after copy."; exit 1; }; \
        rm -rf /tmp/o365; \
    fi \
    && chown -R root:www-data /var/www/moodle \
    && chmod -R 0755 /var/www/moodle

# Config and helper scripts
COPY docker/config.php /var/www/moodle/config.php
COPY docker/moodle.ini /usr/local/etc/php/conf.d/moodle.ini
COPY docker/apache-vhost.conf /etc/apache2/sites-available/000-default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/moodle.conf
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/cron-loop.sh /usr/local/bin/moodle-cron-loop.sh
COPY docker/db-check.php /usr/local/bin/moodle-db-check.php
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/moodle-cron-loop.sh

# Moodle 5.1+ serves from /public and uses a router (r.php); older versions serve from the root.
# Point Apache at whichever layout this release uses.
RUN if [ -d /var/www/moodle/public ]; then DOCROOT=/var/www/moodle/public; else DOCROOT=/var/www/moodle; fi \
    && sed -i "s#__DOCROOT__#${DOCROOT}#g" /etc/apache2/sites-available/000-default.conf \
    && if [ -f "${DOCROOT}/r.php" ]; then \
         sed -i "s#__FALLBACK__#FallbackResource /r.php#" /etc/apache2/sites-available/000-default.conf; \
       else \
         sed -i "s#__FALLBACK__##" /etc/apache2/sites-available/000-default.conf; \
       fi \
    && sed -i 's/^Listen 80$/Listen ${PORT}/' /etc/apache2/ports.conf

# Render routes traffic to $PORT (10000 by default)
ENV PORT=10000 \
    MOODLE_DATAROOT=/var/moodledata
EXPOSE 10000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
