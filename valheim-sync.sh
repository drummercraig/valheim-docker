#!/bin/bash
set -e

# This script ensures world files are synced to persistent storage
# This is a safety mechanism in case the symlink fails

VALHEIM_WORLDS="/opt/valheim/worlds_local"
CONFIG_WORLDS="/config/worlds_local"
SYNC_INTERVAL=60

echo "Starting world sync monitor..."

while true; do
    # Wait for valheim server to be installed
    if [ -f /opt/valheim/valheim_server.x86_64 ]; then
        
        # If /opt/valheim/worlds_local is a regular directory (not symlink)
        if [ -d "$VALHEIM_WORLDS" ] && [ ! -L "$VALHEIM_WORLDS" ]; then
            echo "WARNING: $VALHEIM_WORLDS is not a symlink! Syncing files..."
            
            # Sync any new or modified files to config
            if [ "$(ls -A $VALHEIM_WORLDS 2>/dev/null)" ]; then
                rsync -a --ignore-existing "$VALHEIM_WORLDS/" "$CONFIG_WORLDS/"
                echo "Synced world files to $CONFIG_WORLDS"
            fi
        fi
        
        # Check if symlink is valid
        if [ -L "$VALHEIM_WORLDS" ]; then
            TARGET=$(readlink -f "$VALHEIM_WORLDS")
            if [ "$TARGET" != "$CONFIG_WORLDS" ]; then
                echo "WARNING: Symlink points to wrong location: $TARGET"
                echo "Expected: $CONFIG_WORLDS"
            fi
        fi
    fi
    
    sleep $SYNC_INTERVAL
done