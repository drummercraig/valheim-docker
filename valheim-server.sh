#!/bin/bash
set -e

# Source the pre-stop hook
PRE_STOP_HOOK="/usr/local/bin/pre-stop-hook"

# Function to handle shutdown gracefully
shutdown() {
  echo "=========================================="
  echo "GRACEFUL SHUTDOWN INITIATED"
  echo "=========================================="

  if [ -n "$VALHEIM_PID" ] && kill -0 "$VALHEIM_PID" 2>/dev/null; then
    echo "Sending SIGTERM to Valheim server (PID: $VALHEIM_PID)..."
    echo "This will trigger a world save..."
    echo ""

    kill -TERM "$VALHEIM_PID"

    # Run pre-stop hook to monitor the save
    if [ -x "$PRE_STOP_HOOK" ]; then
      $PRE_STOP_HOOK
    fi

    # Wait for server to exit
    local waited=0
    while kill -0 "$VALHEIM_PID" 2>/dev/null && [ $waited -lt 30 ]; do
      echo "Waiting for server process to exit... (${waited}s)"
      sleep 5
      waited=$((waited + 5))
    done

    if kill -0 "$VALHEIM_PID" 2>/dev/null; then
      echo "Server did not exit gracefully, forcing shutdown..."
      kill -KILL "$VALHEIM_PID" 2>/dev/null || true
    else
      echo "✓ Server process exited cleanly"
    fi

    wait "$VALHEIM_PID" 2>/dev/null || true
  else
    echo "Server process not running"
  fi

  echo ""
  echo "=========================================="
  echo "SHUTDOWN COMPLETE"
  echo "=========================================="
  exit 0
}

# Trap SIGTERM and SIGINT for graceful shutdown
trap shutdown SIGTERM SIGINT

# Wait for updater to install server
while [ ! -f /opt/valheim/valheim_server.x86_64 ]; do
  echo "Waiting for Valheim server installation..."
  sleep 5
done

echo "=== Setting up world file persistence ==="

# Valheim uses Unity config directory
UNITY_WORLDS="/root/.config/unity3d/IronGate/Valheim/worlds_local"
USERFILES_WORLDS="/userfiles/worlds_local"

# Ensure userfiles directory exists
mkdir -p "$USERFILES_WORLDS"

# Create Unity config directory structure
mkdir -p /root/.config/unity3d/IronGate/Valheim

# Remove existing worlds_local in Unity directory
if [ -e "$UNITY_WORLDS" ] || [ -L "$UNITY_WORLDS" ]; then
  echo "Removing existing $UNITY_WORLDS..."

  # Backup if it's a directory with files
  if [ -d "$UNITY_WORLDS" ] && [ ! -L "$UNITY_WORLDS" ]; then
    if [ "$(ls -A $UNITY_WORLDS 2>/dev/null)" ]; then
      echo "Backing up existing worlds to $USERFILES_WORLDS..."
      cp -v "$UNITY_WORLDS"/* "$USERFILES_WORLDS/" 2>/dev/null || true
    fi
  fi

  rm -rf "$UNITY_WORLDS"
fi

# Create symlink from Unity directory to persistent storage
echo "Creating symlink: $UNITY_WORLDS -> $USERFILES_WORLDS"
ln -sf "$USERFILES_WORLDS" "$UNITY_WORLDS"

# Also symlink from /opt/valheim for compatibility
if [ -e /opt/valheim/worlds_local ] || [ -L /opt/valheim/worlds_local ]; then
  rm -rf /opt/valheim/worlds_local
fi
ln -sf "$USERFILES_WORLDS" /opt/valheim/worlds_local

# Verify symlinks
echo "Verifying symlinks..."
echo "Unity path:"
ls -la "$UNITY_WORLDS" || ls -la /root/.config/unity3d/IronGate/Valheim/ | grep worlds_local
echo "Server path:"
ls -la /opt/valheim/ | grep worlds_local

echo "Symlink targets:"
echo "  Unity: $(readlink -f $UNITY_WORLDS)"
echo "  Server: $(readlink -f /opt/valheim/worlds_local)"

echo "Contents of $USERFILES_WORLDS:"
ls -la "$USERFILES_WORLDS/" || echo "Directory is empty"

echo "=== World persistence setup complete ==="

# Set timezone
if [ -n "$TZ" ]; then
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
  echo $TZ > /etc/timezone
fi

# Build server command
SERVER_CMD="/opt/valheim/valheim_server.x86_64"
SERVER_CMD="$SERVER_CMD -name \"$SERVER_NAME\""
SERVER_CMD="$SERVER_CMD -port ${SERVER_PORT:-2456}"
SERVER_CMD="$SERVER_CMD -world \"$WORLD_NAME\""
SERVER_CMD="$SERVER_CMD -password \"$SERVER_PASS\""

# Apply public setting
if [ "$SERVER_PUBLIC" = "true" ]; then
  SERVER_CMD="$SERVER_CMD -public 1"
else
  SERVER_CMD="$SERVER_CMD -public 0"
fi

# Apply crossplay setting
if [ "$CROSSPLAY" = "true" ]; then
  echo "Enabling crossplay support"
  SERVER_CMD="$SERVER_CMD -crossplay"
fi

# Apply world seed if specified
if [ -n "$WORLD_SEED" ]; then
  echo "Setting world seed: $WORLD_SEED"
  SERVER_CMD="$SERVER_CMD -worldseed \"$WORLD_SEED\""
fi

# Apply world size if specified
if [ -n "$WORLD_SIZE" ]; then
  echo "Setting world size: $WORLD_SIZE km radius"
  SERVER_CMD="$SERVER_CMD -worldsize $WORLD_SIZE"
fi

# =============================================================================
# World Modifiers - Apply preset or individual modifiers
# =============================================================================

# Apply preset if specified
if [ -n "$PRESET" ]; then
  echo "Applying preset: $PRESET"
  SERVER_CMD="$SERVER_CMD -preset \"$PRESET\""
fi

# Apply individual combat modifier
if [ -n "$MODIFIER_COMBAT" ]; then
  echo "Setting combat modifier: $MODIFIER_COMBAT"
  SERVER_CMD="$SERVER_CMD -modifier combat $MODIFIER_COMBAT"
fi

# Apply death penalty modifier
if [ -n "$MODIFIER_DEATHPENALTY" ]; then
  echo "Setting death penalty modifier: $MODIFIER_DEATHPENALTY"
  SERVER_CMD="$SERVER_CMD -modifier deathpenalty $MODIFIER_DEATHPENALTY"
fi

# Apply resources modifier
if [ -n "$MODIFIER_RESOURCES" ]; then
  echo "Setting resources modifier: $MODIFIER_RESOURCES"
  SERVER_CMD="$SERVER_CMD -modifier resources $MODIFIER_RESOURCES"
fi

# Apply raids modifier
if [ -n "$MODIFIER_RAIDS" ]; then
  echo "Setting raids modifier: $MODIFIER_RAIDS"
  SERVER_CMD="$SERVER_CMD -modifier raids $MODIFIER_RAIDS"
fi

# Apply portals modifier
if [ -n "$MODIFIER_PORTALS" ]; then
  echo "Setting portals modifier: $MODIFIER_PORTALS"
  SERVER_CMD="$SERVER_CMD -modifier portals $MODIFIER_PORTALS"
fi

# =============================================================================
# Special Game Modifiers - Apply setkey modifiers
# =============================================================================

if [ "$SETKEY_NOBUILDCOST" = "true" ]; then
  echo "Enabling no build cost"
  SERVER_CMD="$SERVER_CMD -setkey nobuildcost"
fi

if [ "$SETKEY_PLAYEREVENTS" = "true" ]; then
  echo "Enabling individual player events"
  SERVER_CMD="$SERVER_CMD -setkey playerevents"
fi

if [ "$SETKEY_PASSIVEMOBS" = "true" ]; then
  echo "Enabling passive mobs"
  SERVER_CMD="$SERVER_CMD -setkey passivemobs"
fi

if [ "$SETKEY_NOMAP" = "true" ]; then
  echo "Disabling map"
  SERVER_CMD="$SERVER_CMD -setkey nomap"
fi

if [ "$NOPORTALS" = "true" ]; then
  echo "Disabling all portals"
  SERVER_CMD="$SERVER_CMD -noportals"
fi

# =============================================================================
# Additional Server Arguments
# =============================================================================

# Add additional arguments if provided
if [ -n "$SERVER_ARGS" ]; then
  SERVER_CMD="$SERVER_CMD $SERVER_ARGS"
fi

echo "=========================================="
echo "Starting Valheim server with command:"
echo "$SERVER_CMD"
echo "=========================================="
cd /opt/valheim

# Export library path for SteamCMD
export LD_LIBRARY_PATH="/opt/valheim/linux64:$LD_LIBRARY_PATH"

# Start server in background
eval "$SERVER_CMD" &
VALHEIM_PID=$!

echo "Valheim server started with PID: $VALHEIM_PID"
echo "Waiting for server process..."

# Wait for the server process
wait "$VALHEIM_PID"

echo "Valheim server process ended"