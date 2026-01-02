#!/usr/bin/env bash
set -e

echo "Starting bootstrap process..."

# Fix permissions on mounted volumes (ignore errors if not allowed)
for dir in /opt/valheim /opt/cache /opt/config /opt/backups; do
    echo "Ensuring permissions for $dir..."
    chown -R valheim:valheim "$dir" || echo "Skipping chown on $dir"
    chmod -R 755 "$dir" || echo "Skipping chmod on $dir"
done

# Variables
STEAMCMD_DIR="/opt/steamcmd"
VALHEIM_DIR="/opt/valheim"
CACHE_DIR="/opt/cache"
STEAMCMD_TAR="$CACHE_DIR/steamcmd_linux.tar.gz"
VALHEIM_CACHE="$CACHE_DIR/valheim_server"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# --- SteamCMD Installation ---
if ! command -v steamcmd &>/dev/null; then
    echo "SteamCMD not found. Checking cache..."
    if [ -f "$STEAMCMD_TAR" ]; then
        echo "Using cached SteamCMD archive..."
    else
        echo "Downloading SteamCMD..."
        curl -sSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -o "$STEAMCMD_TAR"
    fi

    echo "Installing SteamCMD from cache..."
    mkdir -p "$STEAMCMD_DIR"
    tar -xzf "$STEAMCMD_TAR" -C "$STEAMCMD_DIR"
    ln -sf "$STEAMCMD_DIR/steamcmd.sh" /usr/local/bin/steamcmd
else
    echo "SteamCMD already installed."
fi

# --- Valheim Server Installation ---
if [ ! -f "$VALHEIM_DIR/valheim_server.x86_64" ]; then
    echo "Valheim server not found or incomplete. Checking cache..."
    if [ -f "$VALHEIM_CACHE/valheim_server.x86_64" ]; then
        echo "Using cached Valheim server files..."
        cp -r "$VALHEIM_CACHE" "$VALHEIM_DIR"
    else
        echo "Downloading Valheim server via SteamCMD..."
        steamcmd +login anonymous \
                 +force_install_dir "$VALHEIM_DIR" \
                 +app_update 896660 validate \
                 +quit
        echo "Caching Valheim server files..."
        cp -r "$VALHEIM_DIR" "$VALHEIM_CACHE"
    fi
else
    echo "Valheim server already installed."
fi

echo "Bootstrap complete!"

# Drop privileges and start server
echo "Starting Valheim server as valheim user..."
exec su -s /bin/bash valheim -c "/opt/valheim/valheim_server.x86_64 \
    -name \"$SERVER_NAME\" \
    -port 2456 \
    -world \"$WORLD_NAME\" \
    -password \"$SERVER_PASS\" \
    -public \"$SERVER_PUBLIC\""
