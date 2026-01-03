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

# Create worlds directory symlink if needed
if [ ! -L /opt/valheim/worlds_local ]; then
    ln -sf /config/worlds_local /opt/valheim/worlds_local
fi

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