#!/bin/bash
set -e

VALHEIM_APP_ID=896660
STEAMCMD_PATH="/opt/steamcmd/steamcmd.sh"
INSTALL_DIR="/opt/valheim"

# Function to install/update Valheim server
update_valheim() {
    echo "Checking for Valheim server updates..."
    
    # Run steamcmd to install/update
    $STEAMCMD_PATH \
        +force_install_dir "$INSTALL_DIR" \
        +login anonymous \
        +app_update $VALHEIM_APP_ID validate \
        +quit
    
    echo "Valheim server update check complete"
}

# Function to check if server is running
is_server_running() {
    pgrep -f "valheim_server.x86_64" > /dev/null 2>&1
    return $?
}

# Initial install
if [ ! -f "$INSTALL_DIR/valheim_server.x86_64" ]; then
    echo "Performing initial Valheim server installation..."
    update_valheim
fi

# Update loop
while true; do
    sleep "${UPDATE_INTERVAL:-900}"
    
    echo "Checking for updates..."
    
    # Check if there are any updates available
    OLD_BUILDID=$(cat "$INSTALL_DIR/steamapps/appmanifest_$VALHEIM_APP_ID.acf" 2>/dev/null | grep -oP '(?<="buildid"\s{2,}")[^"]+' || echo "0")
    
    # Check Steam for latest build
    update_valheim
    
    NEW_BUILDID=$(cat "$INSTALL_DIR/steamapps/appmanifest_$VALHEIM_APP_ID.acf" 2>/dev/null | grep -oP '(?<="buildid"\s{2,}")[^"]+' || echo "0")
    
    if [ "$OLD_BUILDID" != "$NEW_BUILDID" ]; then
        echo "Update detected: $OLD_BUILDID -> $NEW_BUILDID"
        
        if is_server_running; then
            echo "Restarting server to apply update..."
            supervisorctl restart valheim-server
        else
            echo "Server not running, update applied"
        fi
    else
        echo "Server is up to date (build: $NEW_BUILDID)"
    fi
done