#!/usr/bin/env bash
set -e

echo "Starting bootstrap process..."

# Ensure required directories exist
mkdir -p /serverdata/downloadcache
mkdir -p /userdata/worlds
mkdir -p /userdata/bepinex/plugins
mkdir -p /userdata/bepinex/patchers
mkdir -p /userdata/bepinex/config
mkdir -p /userdata/backups
chown -R 1000:1000 /serverdata
chown -R 1000:1000 /userdata
chmod -R 755 /serverdata
chmod -R 755 /userdata


# Fix permissions on mounted volumes
for dir in /opt/valheim /userdata; do
    echo "Ensuring permissions for $dir..."
    chown -R valheim:valheim "$dir" || echo "Skipping chown on $dir"
    chmod -R 755 "$dir" || echo "Skipping chmod on $dir"
done

# Variables
STEAMCMD_DIR="/opt/steamcmd"
VALHEIM_DIR="/opt/valheim"
CACHE_DIR="/opt/downloadcache"
STEAMCMD_TAR="$CACHE_DIR/steamcmd_linux.tar.gz"
VALHEIM_CACHE="$CACHE_DIR/valheim_server"

mkdir -p "$CACHE_DIR"

# --- SteamCMD Installation ---
if ! command -v steamcmd &>/dev/null; then
    echo "SteamCMD not found. Checking downloadcache..."
    if [ -f "$STEAMCMD_TAR" ]; then
        echo "Using cached SteamCMD archive..."
    else
        echo "Downloading SteamCMD..."
        curl -sSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -o "$STEAMCMD_TAR"
    fi

    echo "Installing SteamCMD from downloadcache..."
    mkdir -p "$STEAMCMD_DIR"
    tar -xzf "$STEAMCMD_TAR" -C "$STEAMCMD_DIR"

    # Create wrapper to run SteamCMD from its directory
    echo "Creating SteamCMD wrapper..."
    cat << 'EOF' > /usr/local/bin/steamcmd
#!/usr/bin/env bash
cd /opt/steamcmd && exec ./steamcmd.sh "$@"
EOF
    chmod +x /usr/local/bin/steamcmd
else
    echo "SteamCMD already installed."
fi

# --- Valheim Server Installation with Retry ---
if [ ! -f "$VALHEIM_DIR/valheim_server.x86_64" ]; then
    echo "Valheim server not found or incomplete. Checking downloadcache..."
    if [ -f "$VALHEIM_CACHE/valheim_server.x86_64" ]; then
        echo "Using cached Valheim server files..."
        cp -r "$VALHEIM_CACHE" "$VALHEIM_DIR"
    else
        echo "Downloading Valheim server via SteamCMD with retry..."
        ATTEMPT=1
        MAX_ATTEMPTS=5
        while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
            echo "Attempt $ATTEMPT of $MAX_ATTEMPTS..."
            if steamcmd +force_install_dir "$VALHEIM_DIR" \
                        +login anonymous \
                        +app_update 896660 validate \
                        +quit; then
                echo "Valheim server installed successfully."
                break
            else
                echo "Valheim install failed. Retrying in 5 seconds..."
                sleep 5
            fi
            ATTEMPT=$((ATTEMPT + 1))
        done

        if [ ! -f "$VALHEIM_DIR/valheim_server.x86_64" ]; then
            echo "ERROR: Valheim server installation failed after $MAX_ATTEMPTS attempts."
            exit 1
        fi

        echo "Caching Valheim server files..."
        cp -r "$VALHEIM_DIR" "$VALHEIM_CACHE"
    fi
else
    echo "Valheim server already installed."
fi

echo "Bootstrap complete!"

# --- Start Valheim Server ---
echo "Starting Valheim server as valheim user..."
exec su -s /bin/bash valheim -c "/opt/valheim/valheim_server.x86_64 \
    -nographics -batchmode \
    -name \"${SERVER_NAME:-MyValheimServer}\" \
    -port 2456 \
    -world \"${WORLD_NAME:-Dedicated}\" \
    -password \"${SERVER_PASS:-secret}\" \
    -public \"${SERVER_PUBLIC:-1}\" \
    -savedir /opt/valheim/worlds"
