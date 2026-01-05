#!/bin/bash
# =============================================================================
# Valheim Server - Docker Run Script
# =============================================================================
# This script runs the Valheim server using docker run instead of docker-compose
# Make sure you have created an .env file in the same directory first!
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if .env file exists
if [ ! -f .env ]; then
    print_error ".env file not found!"
    echo ""
    echo "Please create a .env file with your configuration."
    echo "You can copy the example .env file and customize it."
    exit 1
fi

print_info "Loading configuration from .env file..."

# Load environment variables from .env
set -a
source .env
set +a

# Set defaults for required variables
SERVER_NAME="${SERVER_NAME:-My Valheim Server}"
WORLD_NAME="${WORLD_NAME:-Dedicated}"
SERVER_PASS="${SERVER_PASS:-secret123}"
SERVER_PUBLIC="${SERVER_PUBLIC:-true}"
CROSSPLAY="${CROSSPLAY:-false}"
WORLD_SEED="${WORLD_SEED:-}"
WORLD_SIZE="${WORLD_SIZE:-}"
SERVER_PORT="${SERVER_PORT:-2456}"
GAME_PORT="${GAME_PORT:-2456}"
QUERY_PORT="${QUERY_PORT:-2457}"
CROSSPLAY_PORT="${CROSSPLAY_PORT:-2458}"
UPDATE_INTERVAL="${UPDATE_INTERVAL:-900}"
BACKUPS_ENABLED="${BACKUPS_ENABLED:-true}"
BACKUPS_INTERVAL="${BACKUPS_INTERVAL:-3600}"
BACKUPS_DIRECTORY="${BACKUPS_DIRECTORY:-/userfiles/backups}"
BACKUPS_MAX_AGE="${BACKUPS_MAX_AGE:-3}"
TZ="${TZ:-Etc/UTC}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
MEMORY_LIMIT="${MEMORY_LIMIT:-8G}"
USERFILES_PATH="${USERFILES_PATH:-./userfiles}"
SERVERFILES_PATH="${SERVERFILES_PATH:-./serverfiles}"

# Container name
CONTAINER_NAME="valheim-server"

# Check if container is already running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_error "Container '$CONTAINER_NAME' is already running!"
    echo ""
    echo "To stop it, run: docker stop $CONTAINER_NAME"
    echo "To remove it, run: docker rm $CONTAINER_NAME"
    exit 1
fi

# Create necessary directories
print_info "Creating necessary directories..."
mkdir -p "$USERFILES_PATH/worlds_local"
mkdir -p "$USERFILES_PATH/backups"
mkdir -p "$USERFILES_PATH/bepinex/plugins"
mkdir -p "$USERFILES_PATH/bepinex/patchers"
mkdir -p "$USERFILES_PATH/bepinex/config"
mkdir -p "$SERVERFILES_PATH"

# Print configuration
echo ""
print_info "Configuration:"
echo "  Server Name: $SERVER_NAME"
echo "  World Name: $WORLD_NAME"
echo "  Server Port: $SERVER_PORT"
echo "  Public Server: $SERVER_PUBLIC"
echo "  Crossplay: $CROSSPLAY"
if [ -n "$WORLD_SEED" ]; then
    echo "  World Seed: $WORLD_SEED"
fi
if [ -n "$WORLD_SIZE" ]; then
    echo "  World Size: $WORLD_SIZE km"
fi
echo "  Game Port: $GAME_PORT"
echo "  Query Port: $QUERY_PORT"
echo "  Crossplay Port: $CROSSPLAY_PORT"
echo "  Timezone: $TZ"
echo "  Memory Limit: $MEMORY_LIMIT"
echo ""

# Build environment variables list
ENV_VARS=(
    -e "SERVER_NAME=$SERVER_NAME"
    -e "WORLD_NAME=$WORLD_NAME"
    -e "SERVER_PASS=$SERVER_PASS"
    -e "SERVER_PUBLIC=$SERVER_PUBLIC"
    -e "CROSSPLAY=$CROSSPLAY"
    -e "SERVER_PORT=$SERVER_PORT"
    -e "UPDATE_INTERVAL=$UPDATE_INTERVAL"
    -e "BACKUPS_ENABLED=$BACKUPS_ENABLED"
    -e "BACKUPS_INTERVAL=$BACKUPS_INTERVAL"
    -e "BACKUPS_DIRECTORY=$BACKUPS_DIRECTORY"
    -e "BACKUPS_MAX_AGE=$BACKUPS_MAX_AGE"
    -e "TZ=$TZ"
    -e "PUID=$PUID"
    -e "PGID=$PGID"
)

# Add crossplay info
if [ "$CROSSPLAY" = "true" ]; then
    print_info "Crossplay enabled"
fi

# Add world seed if specified
if [ -n "$WORLD_SEED" ]; then
    ENV_VARS+=(-e "WORLD_SEED=$WORLD_SEED")
    print_info "World seed: $WORLD_SEED"
fi

# Add world size if specified
if [ -n "$WORLD_SIZE" ]; then
    ENV_VARS+=(-e "WORLD_SIZE=$WORLD_SIZE")
    print_info "World size: $WORLD_SIZE km radius"
fi

# Add world modifiers if set
if [ -n "$PRESET" ]; then
    ENV_VARS+=(-e "PRESET=$PRESET")
    print_info "Using preset: $PRESET"
fi

if [ -n "$MODIFIER_COMBAT" ]; then
    ENV_VARS+=(-e "MODIFIER_COMBAT=$MODIFIER_COMBAT")
    print_info "Combat modifier: $MODIFIER_COMBAT"
fi

if [ -n "$MODIFIER_DEATHPENALTY" ]; then
    ENV_VARS+=(-e "MODIFIER_DEATHPENALTY=$MODIFIER_DEATHPENALTY")
    print_info "Death penalty modifier: $MODIFIER_DEATHPENALTY"
fi

if [ -n "$MODIFIER_RESOURCES" ]; then
    ENV_VARS+=(-e "MODIFIER_RESOURCES=$MODIFIER_RESOURCES")
    print_info "Resources modifier: $MODIFIER_RESOURCES"
fi

if [ -n "$MODIFIER_RAIDS" ]; then
    ENV_VARS+=(-e "MODIFIER_RAIDS=$MODIFIER_RAIDS")
    print_info "Raids modifier: $MODIFIER_RAIDS"
fi

if [ -n "$MODIFIER_PORTALS" ]; then
    ENV_VARS+=(-e "MODIFIER_PORTALS=$MODIFIER_PORTALS")
    print_info "Portals modifier: $MODIFIER_PORTALS"
fi

# Add special setkey modifiers
if [ "$SETKEY_NOBUILDCOST" = "true" ]; then
    ENV_VARS+=(-e "SETKEY_NOBUILDCOST=true")
    print_info "No build cost enabled"
fi

if [ "$SETKEY_PLAYEREVENTS" = "true" ]; then
    ENV_VARS+=(-e "SETKEY_PLAYEREVENTS=true")
    print_info "Individual player events enabled"
fi

if [ "$SETKEY_PASSIVEMOBS" = "true" ]; then
    ENV_VARS+=(-e "SETKEY_PASSIVEMOBS=true")
    print_info "Passive mobs enabled"
fi

if [ "$SETKEY_NOMAP" = "true" ]; then
    ENV_VARS+=(-e "SETKEY_NOMAP=true")
    print_info "Map disabled"
fi

# Add server args if set
if [ -n "$SERVER_ARGS" ]; then
    ENV_VARS+=(-e "SERVER_ARGS=$SERVER_ARGS")
    print_info "Additional server args: $SERVER_ARGS"
fi

# Add BepInEx if enabled
if [ "$BEPINEX_ENABLED" = "true" ]; then
    ENV_VARS+=(-e "BEPINEX_ENABLED=true")
    print_info "BepInEx modding enabled"
fi

echo ""
print_info "Starting Valheim server container..."

# Run the container
docker run -d \
    --name "$CONTAINER_NAME" \
    --cap-add=sys_nice \
    -p "${GAME_PORT}:${GAME_PORT}/udp" \
    -p "${QUERY_PORT}:${QUERY_PORT}/udp" \
    -p "${CROSSPLAY_PORT}:${CROSSPLAY_PORT}/udp" \
    -v "$(pwd)/${USERFILES_PATH}:/userfiles" \
    -v "$(pwd)/${SERVERFILES_PATH}:/opt/valheim" \
    "${ENV_VARS[@]}" \
    --memory="$MEMORY_LIMIT" \
    --restart=unless-stopped \
    --stop-timeout=120 \
    valheim-server:latest

if [ $? -eq 0 ]; then
    echo ""
    print_info "Container started successfully!"
    echo ""
    echo "Container name: $CONTAINER_NAME"
    echo ""
    echo "Useful commands:"
    echo "  View logs:          docker logs -f $CONTAINER_NAME"
    echo "  Stop server:        docker stop $CONTAINER_NAME"
    echo "  Start server:       docker start $CONTAINER_NAME"
    echo "  Restart server:     docker restart $CONTAINER_NAME"
    echo "  Force save:         docker exec $CONTAINER_NAME /usr/local/bin/force-save"
    echo "  Check world status: docker exec $CONTAINER_NAME /usr/local/bin/check-world-status"
    echo "  Debug worlds:       docker exec $CONTAINER_NAME /usr/local/bin/debug-worlds"
    echo "  Remove container:   docker rm -f $CONTAINER_NAME"
    echo ""
    print_info "Server is starting up. Use 'docker logs -f $CONTAINER_NAME' to monitor progress."
else
    echo ""
    print_error "Failed to start container!"
    exit 1
fi