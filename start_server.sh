#!/bin/bash
# Start Valheim Server

set -e
source /settings.env

echo "======================================"
echo "Server Configuration"
echo "======================================"
echo "Name: ${SERVER_NAME}"
echo "World: ${WORLD_NAME}"
echo "Port: ${SERVER_PORT}"
echo "Public: ${SERVER_PUBLIC}"
if [ "${CROSSPLAY_ENABLED}" = "true" ]; then
    echo "Crossplay: Enabled"
fi
if [ "${MOD_LOADER}" = "BepInEx" ]; then
    echo "BepInEx: Enabled"
fi
echo "======================================"

# Validate password
if [ -z "${SERVER_PASSWORD}" ] || [ ${#SERVER_PASSWORD} -lt 5 ]; then
    echo "ERROR: SERVER_PASSWORD must be at least 5 characters"
    exit 1
fi

# Setup environment
export templdpath=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=${VALHEIM_DIR}/linux64:$LD_LIBRARY_PATH
export SteamAppId=892970

cd ${VALHEIM_DIR}

# Start with BepInEx if enabled
if [ "${MOD_LOADER}" = "BepInEx" ]; then
    # Check for plugins
    if [ -d "${VALHEIM_DIR}/BepInEx/plugins" ]; then
        PLUGIN_COUNT=$(find "${VALHEIM_DIR}/BepInEx/plugins" -name "*.dll" -type f 2>/dev/null | wc -l)
        if [ $PLUGIN_COUNT -gt 0 ]; then
            echo ""
            echo "Loaded $PLUGIN_COUNT BepInEx plugin(s):"
            find "${VALHEIM_DIR}/BepInEx/plugins" -name "*.dll" -type f -exec basename {} \; 2>/dev/null | sed 's/^/  - /'
            echo ""
        fi
    fi
    
    # Set BepInEx environment
    export DOORSTOP_ENABLE=TRUE
    export DOORSTOP_INVOKE_DLL_PATH="${VALHEIM_DIR}/BepInEx/core/BepInEx.Preloader.dll"
    export DOORSTOP_CORLIB_OVERRIDE_PATH="${VALHEIM_DIR}/unstripped_corlib"
    export LD_LIBRARY_PATH="${VALHEIM_DIR}/doorstop_libs:$LD_LIBRARY_PATH"
    export LD_PRELOAD="${VALHEIM_DIR}/doorstop_libs/libdoorstop_x64.so:$LD_PRELOAD"
fi

echo "Starting server..."
echo "======================================"

# Build base server command
SERVER_ARGS="-name \"${SERVER_NAME}\" -port ${SERVER_PORT} -world \"${WORLD_NAME}\" -password \"${SERVER_PASSWORD}\" -public ${SERVER_PUBLIC} -savedir \"/config\""

# Add backup settings
SERVER_ARGS="${SERVER_ARGS} -saveinterval ${BACKUP_SAVEINTERVAL} -backups ${BACKUP_COUNT} -backupshort ${BACKUP_SHORT} -backuplong ${BACKUP_LONG}"

# Add standard flags
SERVER_ARGS="${SERVER_ARGS} -nographics -batchmode"

# Add crossplay if enabled
if [ "${CROSSPLAY_ENABLED}" = "true" ]; then
    SERVER_ARGS="${SERVER_ARGS} -crossplay"
fi

# Add preset if specified
if [ -n "$PRESET" ]; then
    SERVER_ARGS="${SERVER_ARGS} -preset ${PRESET}"
    echo "World Preset: ${PRESET}"
fi

# Add modifiers
if [ -n "$MODIFIER_COMBAT" ]; then
    SERVER_ARGS="${SERVER_ARGS} -modifier combat ${MODIFIER_COMBAT}"
    echo "Combat Modifier: ${MODIFIER_COMBAT}"
fi

if [ -n "$MODIFIER_DEATHPENALTY" ]; then
    SERVER_ARGS="${SERVER_ARGS} -modifier deathpenalty ${MODIFIER_DEATHPENALTY}"
    echo "Death Penalty: ${MODIFIER_DEATHPENALTY}"
fi

if [ -n "$MODIFIER_RESOURCES" ]; then
    SERVER_ARGS="${SERVER_ARGS} -modifier resources ${MODIFIER_RESOURCES}"
    echo "Resources: ${MODIFIER_RESOURCES}"
fi

if [ -n "$MODIFIER_RAIDS" ]; then
    SERVER_ARGS="${SERVER_ARGS} -modifier raids ${MODIFIER_RAIDS}"
    echo "Raids: ${MODIFIER_RAIDS}"
fi

if [ -n "$MODIFIER_PORTALS" ]; then
    SERVER_ARGS="${SERVER_ARGS} -modifier portals ${MODIFIER_PORTALS}"
    echo "Portals: ${MODIFIER_PORTALS}"
fi

# Add setkeys
if [ "${SETKEY_NOBUILDCOST}" = "true" ]; then
    SERVER_ARGS="${SERVER_ARGS} -setkey nobuildcost"
    echo "No Build Cost: Enabled"
fi

if [ "${SETKEY_PLAYEREVENTS}" = "true" ]; then
    SERVER_ARGS="${SERVER_ARGS} -setkey playerevents"
    echo "Player Events: Enabled"
fi

if [ "${SETKEY_PASSIVEMOBS}" = "true" ]; then
    SERVER_ARGS="${SERVER_ARGS} -setkey passivemobs"
    echo "Passive Mobs: Enabled"
fi

if [ "${SETKEY_NOMAP}" = "true" ]; then
    SERVER_ARGS="${SERVER_ARGS} -setkey nomap"
    echo "No Map: Enabled"
fi

echo "======================================"

# Execute the server
exec bash -c "${VALHEIM_DIR}/valheim_server.x86_64 ${SERVER_ARGS}"