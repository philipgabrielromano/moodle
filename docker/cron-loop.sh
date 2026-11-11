#!/bin/bash
# Runs Moodle's scheduled tasks every minute, as the web user, inside the web container.
if [ -d /var/www/moodle/public/admin/cli ]; then CLI=/var/www/moodle/public/admin/cli; else CLI=/var/www/moodle/admin/cli; fi
sleep 30  # let Apache finish starting
while true; do
    start=$(date +%s)
    su -s /bin/bash www-data -c "php $CLI/cron.php --keep-alive=0" || echo "cron run failed"
    elapsed=$(( $(date +%s) - start ))
    [ "$elapsed" -lt 60 ] && sleep $(( 60 - elapsed ))
done
