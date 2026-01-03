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

# Valheim actually uses the Unity config directory!
UNITY_WORLDS="/root/.config/unity3d/IronGate/Valheim/worlds_local"
CONFIG_WORLDS="/config/worlds_local"

# Ensure config directory exists
mkdir -p /config/worlds_local

# Create Unity config directory structure if needed
mkdir -p /root/.config/unity3d/IronGate/Valheim

# Remove any existing worlds_local in Unity directory (directory or symlink)
if [ -e "$UNITY_WORLDS" ] || [ -L "$UNITY_WORLDS" ]; then
    echo "Removing existing $UNITY_WORLDS..."
    
    # If it's a directory with files, back them up first
    if [ -d "$UNITY_WORLDS" ] && [ ! -L "$UNITY_WORLDS" ]; then
        if [ "$(ls -A $UNITY_WORLDS 2>/dev/null)" ]; then
            echo "Backing up existing worlds to /config/worlds_local..."
            cp -v "$UNITY_WORLDS"/* "$CONFIG_WORLDS/" 2>/dev/null || true
        fi
    fi
    
    rm -rf "$UNITY_WORLDS"
fi

# Create symlink from Unity directory to persistent storage
echo "Creating symlink: $UNITY_WORLDS -> $CONFIG_WORLDS"
ln -sf "$CONFIG_WORLDS" "$UNITY_WORLDS"

# Also symlink from /opt/valheim for compatibility
if [ -e /opt/valheim/worlds_local ] || [ -L /opt/valheim/worlds_local ]; then
    rm -rf /opt/valheim/worlds_local
fi
ln -sf "$CONFIG_WORLDS" /opt/valheim/worlds_local

# Verify symlinks
echo "Verifying symlinks..."
echo "Unity path:"
ls -la "$UNITY_WORLDS" || ls -la /root/.config/unity3d/IronGate/Valheim/ | grep worlds_local
echo "Server path:"
ls -la /opt/valheim/ | grep worlds_local

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