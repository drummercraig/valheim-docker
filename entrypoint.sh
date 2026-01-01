#!/bin/bash
set -e
source /settings.env

/install-steamcmd.sh
/install-valheim.sh
#/install-modloader.sh

service cron start

echo "Starting Valheim server..."
exec ${VALHEIM_DIR}/valheim_server.x86_64 \
    -name "$SERVER_NAME" \
    -port $SERVER_PORT \
    -world "$WORLD_NAME" \
    -password "$SERVER_PASSWORD" \
    -public $SERVER_PUBLIC
