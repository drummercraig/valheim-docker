#!/bin/bash
set -e

CACHE_DIR="/opt/cache"
VALHEIM_DIR="/opt/valheim"
VALHEIM_CACHE="$CACHE_DIR/valheim"

MAX_RETRIES=5
RETRY_DELAY=5
COUNTER=0

if [ -d "$VALHEIM_CACHE" ]; then
    echo "Restoring Valheim from cache..."
    rsync -a "$VALHEIM_CACHE/" "$VALHEIM_DIR/"
fi

while [ $COUNTER -lt $MAX_RETRIES ]; do
    echo "Attempt $(($COUNTER+1)) to install/update Valheim server..."
    if ~/steamcmd/steamcmd.sh +force_install_dir "$VALHEIM_DIR" +login anonymous +app_update 896660 validate +quit; then
        echo "Valheim server installed successfully."
        break
    else
        echo "Installation failed. Retrying in $RETRY_DELAY seconds..."
        sleep $RETRY_DELAY
        COUNTER=$(($COUNTER+1))
    fi
done

if [ $COUNTER -eq $MAX_RETRIES ]; then
    echo "Valheim installation failed after $MAX_RETRIES attempts."
    exit 1
fi

echo "Caching Valheim installation..."
rsync -a --delete "$VALHEIM_DIR/" "$VALHEIM_CACHE/"
#chown -R valheim:valheim "$VALHEIM_DIR" "$VALHEIM_CACHE" || true
#chmod -R 755 "$VALHEIM_DIR" "$VALHEIM_CACHE" || true
