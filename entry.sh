#!/bin/bash

cat > crontab <<< "
0 5 * * * /app/photo_archiver archive -config-file ${CONFIG_FILE}
0 3 * * 0 /app/photo_archiver sync-db -config-file ${CONFIG_FILE}
"

/usr/bin/crontab crontab

cron -f