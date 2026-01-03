#!/bin/bash
set -e

# This script ensures world files are synced to persistent storage
# This is a safety mechanism in case the symlink fails

VALHEIM_WORLDS="/opt/valheim/worlds_local"
CONFIG_WORLDS="/config/worlds_local"
SYNC_INTERVAL=30

echo "=== Starting world sync monitor ==="
echo "Monitoring: $VALHEIM_WORLDS"
echo "Target: $CONFIG_WORLDS"

# Counter for periodic status updates
counter=0

while true; do
    sleep $SYNC_INTERVAL
    counter=$((counter + 1))
    
    # Wait for valheim server to be installed
    if [ ! -f /opt/valheim/valheim_server.x86_64 ]; then
        continue
    fi
    
    # Check symlink status every cycle
    if [ -L "$VALHEIM_WORLDS" ]; then
        TARGET=$(readlink -f "$VALHEIM_WORLDS")
        
        # Status update every 10 cycles (5 minutes)
        if [ $((counter % 10)) -eq 0 ]; then
            echo "[$(date)] Symlink OK: $VALHEIM_WORLDS -> $TARGET"
            
            # Show world files if any exist
            if [ -d "$CONFIG_WORLDS" ] && [ "$(ls -A $CONFIG_WORLDS 2>/dev/null)" ]; then
                echo "World files in persistent storage:"
                ls -lh "$CONFIG_WORLDS"
            fi
        fi
        
        if [ "$TARGET" != "$(readlink -f $CONFIG_WORLDS)" ]; then
            echo "WARNING: Symlink points to wrong location!"
            echo "  Current: $TARGET"
            echo "  Expected: $(readlink -f $CONFIG_WORLDS)"
        fi
    else
        # If not a symlink, this is a problem
        if [ -d "$VALHEIM_WORLDS" ]; then
            echo "ERROR: $VALHEIM_WORLDS is a directory, not a symlink!"
            echo "Attempting to sync files and recreate symlink..."
            
            # Sync files to config
            if [ "$(ls -A $VALHEIM_WORLDS 2>/dev/null)" ]; then
                echo "Syncing files to persistent storage..."
                cp -av "$VALHEIM_WORLDS"/* "$CONFIG_WORLDS/"
                echo "Files synced successfully"
            fi
            
            # Try to fix by recreating symlink
            echo "Removing directory and recreating symlink..."
            rm -rf "$VALHEIM_WORLDS"
            ln -sf "$CONFIG_WORLDS" "$VALHEIM_WORLDS"
            
            if [ -L "$VALHEIM_WORLDS" ]; then
                echo "Symlink recreated successfully"
            else
                echo "ERROR: Failed to recreate symlink!"
            fi
        elif [ ! -e "$VALHEIM_WORLDS" ]; then
            echo "WARNING: $VALHEIM_WORLDS does not exist! Creating symlink..."
            ln -sf "$CONFIG_WORLDS" "$VALHEIM_WORLDS"
        fi
    fi
    
    # Also check if there are any orphaned .db files in the server root
    if [ -f /opt/valheim/*.db ]; then
        echo "WARNING: Found world files in /opt/valheim root!"
        ls -lh /opt/valheim/*.db
        echo "Moving to persistent storage..."
        mv -v /opt/valheim/*.db /opt/valheim/*.fwl "$CONFIG_WORLDS/" 2>/dev/null || true
    fi
done