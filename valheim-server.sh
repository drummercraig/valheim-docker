#!/bin/bash
set -e

# Function to handle shutdown
shutdown() {
    echo "Shutting down Valheim server..."
    if [ -n "$VALHEIM_PID" ]; then
        kill -TERM "$VALHEIM_PID" 2>/dev/null || true
        wait "$VALHEIM_PID" 2>/dev/null || true
    fi
    exit 0
}

trap shutdown SIGTERM SIGINT

# Wait for updater to install server
while [ ! -f /opt/valheim/valheim_server.x86_64 ]; do
    echo "Waiting for Valheim server installation..."
    sleep 5
done

echo "=== Setting up world file persistence ==="

# Ensure config directories exist
mkdir -p /config/worlds_local

# Remove any existing worlds_local in server directory (directory or symlink)
if [ -e /opt/valheim/worlds_local ] || [ -L /opt/valheim/worlds_local ]; then
    echo "Removing existing /opt/valheim/worlds_local..."
    
    # If it's a directory with files, back them up first
    if [ -d /opt/valheim/worlds_local ] && [ ! -L /opt/valheim/worlds_local ]; then
        if [ "$(ls -A /opt/valheim/worlds_local 2>/dev/null)" ]; then
            echo "Backing up existing worlds to /config/worlds_local..."
            cp -v /opt/valheim/worlds_local/* /config/worlds_local/ 2>/dev/null || true
        fi
    fi
    
    rm -rf /opt/valheim/worlds_local
fi

# Create symlink BEFORE server starts
echo "Creating symlink: /opt/valheim/worlds_local -> /config/worlds_local"
ln -sf /config/worlds_local /opt/valheim/worlds_local

# Verify symlink
echo "Verifying symlink..."
ls -la /opt/valheim/ | grep worlds_local
readlink -f /opt/valheim/worlds_local

echo "Contents of /config/worlds_local:"
ls -la /config/worlds_local/ || echo "Directory is empty"

echo "=== World persistence setup complete ==="

# Set timezone
if [ -n "$TZ" ]; then
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
fi

# Build server command
SERVER_CMD="/opt/valheim/valheim_server.x86_64"
SERVER_CMD="$SERVER_CMD -name \"$SERVER_NAME\""
SERVER_CMD="$SERVER_CMD -port $SERVER_PORT"
SERVER_CMD="$SERVER_CMD -world \"$WORLD_NAME\""
SERVER_CMD="$SERVER_CMD -password \"$SERVER_PASS\""

if [ "$SERVER_PUBLIC" = "true" ]; then
    SERVER_CMD="$SERVER_CMD -public 1"
else
    SERVER_CMD="$SERVER_CMD -public 0"
fi

# Add additional arguments if provided
if [ -n "$SERVER_ARGS" ]; then
    SERVER_CMD="$SERVER_CMD $SERVER_ARGS"
fi

echo "Starting Valheim server with command: $SERVER_CMD"
cd /opt/valheim

# Export library path for SteamCMD
export LD_LIBRARY_PATH="/opt/valheim/linux64:$LD_LIBRARY_PATH"

# Start server
eval "$SERVER_CMD" &
VALHEIM_PID=$!

echo "Valheim server started with PID: $VALHEIM_PID"

# Wait for the server process
wait "$VALHEIM_PID"