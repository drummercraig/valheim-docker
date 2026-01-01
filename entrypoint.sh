#!/bin/bash
set -e

# Load environment variables
set -a
. /settings.env
set +a

## Ensure folder structure exists
#mkdir -p /valheim-data/BepInEx/plugins /valheim-data/BepInEx/patchers /valheim-data/BepInEx/config
#mkdir -p /valheim-data/worlds /valheim-data/backups

## Apply initial permissions
#chown -R ${PUID}:${PGID} /valheim-data
#chmod -R 755 /valheim-data

/install_steamcmd.sh
/install_valheim.sh
/install_modloader.sh

service cron start

echo "Starting Valheim server..."
exec ${VALHEIM_DIR}/valheim_server.x86_64 \
    -name "$SERVER_NAME" \
    -port $SERVER_PORT \
    -world "$WORLD_NAME" \
    -password "$SERVER_PASSWORD" \
    -public $SERVER_PUBLIC
