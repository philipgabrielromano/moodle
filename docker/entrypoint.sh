#!/bin/bash
# Prepares the persistent disk, installs or upgrades Moodle, then starts Apache + cron.
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL is not set}"
: "${MOODLE_WWWROOT:?MOODLE_WWWROOT is not set (e.g. https://learn.example.org)}"

MOODLE_DIR=/var/www/moodle
DATAROOT="${MOODLE_DATAROOT:-/var/moodledata}"

# Moodle 5.1+ keeps admin/ under public/
if [ -d "$MOODLE_DIR/public/admin/cli" ]; then CLI="$MOODLE_DIR/public/admin/cli"; else CLI="$MOODLE_DIR/admin/cli"; fi

# Persistent disk (mounted by Render as root) and local cache
mkdir -p "$DATAROOT" /var/cache/moodle
chown -R www-data:www-data "$DATAROOT" /var/cache/moodle
chmod 2770 "$DATAROOT"

as_www() { su -s /bin/bash www-data -c "$(printf '%q ' "$@")"; }

# Wait for the database (up to ~2 minutes)
for i in $(seq 1 60); do
    set +e; php /usr/local/bin/moodle-db-check.php; status=$?; set -e
    [ "$status" -ne 2 ] && break
    echo "Waiting for database... ($i)"; sleep 2
done
if [ "$status" -eq 2 ]; then echo "Database unreachable, giving up."; exit 1; fi

if [ "$status" -eq 1 ]; then
    echo "Fresh database: installing Moodle..."
    : "${MOODLE_ADMIN_PASSWORD:?MOODLE_ADMIN_PASSWORD must be set for first install}"
    as_www php "$CLI/install_database.php" \
        --agree-license \
        --lang=en \
        --fullname="${MOODLE_SITE_NAME:-Learning Portal}" \
        --shortname="${MOODLE_SITE_SHORTNAME:-Learning}" \
        --adminuser="${MOODLE_ADMIN_USER:-admin}" \
        --adminpass="${MOODLE_ADMIN_PASSWORD}" \
        --adminemail="${MOODLE_ADMIN_EMAIL:-admin@example.org}"
else
    echo "Existing site: running any pending upgrade..."
    as_www php "$CLI/upgrade.php" --non-interactive || echo "Upgrade step reported an error; check logs."
fi

# Clear caches after deploys so new code is picked up
as_www php "$CLI/purge_caches.php" || true

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
