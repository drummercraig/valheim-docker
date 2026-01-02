#!/bin/bash
set -e

echo "Starting bootstrap process..."

# Fix permissions on mounted volumes (ignore errors if not allowed)
for dir in /opt/valheim /opt/cache /opt/config /opt/backups; do
    echo "Ensuring permissions for $dir..."
    chown -R valheim:valheim "$dir" || echo "Skipping chown on $dir"
    chmod -R 755 "$dir" || echo "Skipping chmod on $dir"
done

set -e

CACHE_DIR="/opt/cache"
STEAMCMD_ARCHIVE="$CACHE_DIR/steamcmd_linux.tar.gz"

mkdir -p ~/steamcmd

if [ -f "$STEAMCMD_ARCHIVE" ]; then
    echo "Using cached SteamCMD archive..."
else
    echo "Downloading SteamCMD..."
    curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz -o "$STEAMCMD_ARCHIVE"
fi

tar -xzvf "$STEAMCMD_ARCHIVE" -C ~/steamcmd

# Install Valheim at runtime if missing
if [ ! -f /opt/valheim/valheim_server.x86_64 ]; then
    echo "Valheim server binary missing. Installing latest version..."
    su -s /bin/bash valheim -c "~/steamcmd/steamcmd.sh +force_install_dir /opt/valheim +login anonymous +app_update 896660 validate +quit"
fi

# Drop privileges and start server
echo "Starting Valheim server as valheim user..."
exec su -s /bin/bash valheim -c "/opt/valheim/valheim_server.x86_64 -name \"$SERVER_NAME\" -port 2456 -world \"$WORLD_NAME\" -password \"$SERVER_PASS\" -public \"$SERVER_PUBLIC\"
