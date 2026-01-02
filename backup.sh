#!/bin/bash
source ./settings.env
while true; do
    sleep $BACKUP_SAVEINTERVAL
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    tar -czf $WORLD_BACKUP/world_$TIMESTAMP.tar.gz $WORLD_SRC
    find $WORLD_BACKUP -type f -mtime +$BACKUP_LONG -delete
done
