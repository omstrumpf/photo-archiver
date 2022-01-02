#!/bin/bash

cat > crontab <<< "
0 5 * * * /app/photo_archiver archive -config-file ${CONFIG_FILE} ${EXTRA_ARGS}
0 3 * * 0 /app/photo_archiver sync-db -config-file ${CONFIG_FILE} ${EXTRA_ARGS}
"

/usr/bin/crontab crontab

cron -f