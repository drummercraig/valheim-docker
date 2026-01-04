#!/bin/bash
set -e

# This script ensures world files and BepInEx files are synced to persistent storage
# This is a safety mechanism in case the symlinks fail

VALHEIM_WORLDS="/opt/valheim/worlds_local"
USER_WORLDS="/userfiles/worlds_local"
BEPINEX_DIR="/opt/valheim/BepInEx"
USER_BEPINEX="/userfiles/bepinex"
UNITY_CONFIG_DIR="/root/.config/unity3d/IronGate/Valheim"
USERFILES_DIR="/userfiles"
SYNC_INTERVAL=30

echo "=== Starting world and mod sync monitor ==="
echo "Monitoring worlds: $VALHEIM_WORLDS -> $USER_WORLDS"
echo "Monitoring BepInEx: $BEPINEX_DIR -> $USER_BEPINEX"

# Counter for periodic status updates
counter=0

while true; do
    sleep $SYNC_INTERVAL
    counter=$((counter + 1))

    # Wait for valheim server to be installed
    if [ ! -f /opt/valheim/valheim_server.x86_64 ]; then
        continue
    fi

    # === Check world files symlink ===
    if [ -L "$VALHEIM_WORLDS" ]; then
        TARGET=$(readlink -f "$VALHEIM_WORLDS")

        # Status update every 10 cycles (5 minutes)
        if [ $((counter % 10)) -eq 0 ]; then
            echo "[$(date)] Symlink OK: $VALHEIM_WORLDS -> $TARGET"

            # Show world files if any exist
            if [ -d "$USER_WORLDS" ] && [ "$(ls -A $USER_WORLDS 2>/dev/null)" ]; then
                echo "World files in persistent storage:"
                ls -lh "$USER_WORLDS"
            fi
        fi

        if [ "$TARGET" != "$(readlink -f $USER_WORLDS)" ]; then
            echo "WARNING: Symlink points to wrong location!"
            echo "  Current: $TARGET"
            echo "  Expected: $(readlink -f $USER_WORLDS)"
        fi
    else
        # If not a symlink, this is a problem
        if [ -d "$VALHEIM_WORLDS" ]; then
            echo "ERROR: $VALHEIM_WORLDS is a directory, not a symlink!"
            echo "Attempting to sync files and recreate symlink..."

            # Sync files to persistent storage
            if [ "$(ls -A $VALHEIM_WORLDS 2>/dev/null)" ]; then
                echo "Syncing files to persistent storage..."
                cp -av "$VALHEIM_WORLDS"/* "$USER_WORLDS/"
                echo "Files synced successfully"
            fi

            # Try to fix by recreating symlink
            echo "Removing directory and recreating symlink..."
            rm -rf "$VALHEIM_WORLDS"
            ln -sf "$USER_WORLDS" "$VALHEIM_WORLDS"

            if [ -L "$VALHEIM_WORLDS" ]; then
                echo "Symlink recreated successfully"
            else
                echo "ERROR: Failed to recreate symlink!"
            fi
        elif [ ! -e "$VALHEIM_WORLDS" ]; then
            echo "WARNING: $VALHEIM_WORLDS does not exist! Creating symlink..."
            ln -sf "$USER_WORLDS" "$VALHEIM_WORLDS"
        fi
    fi

    # === Check BepInEx symlinks (if MOD_LOADER is BepInEx) ===
    if [ "${MOD_LOADER:-Vanilla}" = "BepInEx" ] && [ -d "$BEPINEX_DIR" ]; then
        # Check plugins symlink
        if [ -L "${BEPINEX_DIR}/plugins" ]; then
            TARGET=$(readlink -f "${BEPINEX_DIR}/plugins")
            if [ "$TARGET" != "$(readlink -f ${USER_BEPINEX}/plugins)" ]; then
                echo "WARNING: BepInEx plugins symlink points to wrong location!"
                echo "  Current: $TARGET"
                echo "  Expected: $(readlink -f ${USER_BEPINEX}/plugins)"
            fi
        elif [ -d "${BEPINEX_DIR}/plugins" ]; then
            echo "ERROR: ${BEPINEX_DIR}/plugins is a directory, not a symlink!"
            echo "Attempting to fix..."
            if [ "$(ls -A ${BEPINEX_DIR}/plugins 2>/dev/null)" ]; then
                cp -av "${BEPINEX_DIR}/plugins"/* "${USER_BEPINEX}/plugins/"
            fi
            rm -rf "${BEPINEX_DIR}/plugins"
            ln -sf "${USER_BEPINEX}/plugins" "${BEPINEX_DIR}/plugins"
            echo "BepInEx plugins symlink recreated"
        fi

        # Check patchers symlink
        if [ -L "${BEPINEX_DIR}/patchers" ]; then
            TARGET=$(readlink -f "${BEPINEX_DIR}/patchers")
            if [ "$TARGET" != "$(readlink -f ${USER_BEPINEX}/patchers)" ]; then
                echo "WARNING: BepInEx patchers symlink points to wrong location!"
            fi
        elif [ -d "${BEPINEX_DIR}/patchers" ]; then
            echo "ERROR: ${BEPINEX_DIR}/patchers is a directory, not a symlink!"
            echo "Attempting to fix..."
            if [ "$(ls -A ${BEPINEX_DIR}/patchers 2>/dev/null)" ]; then
                cp -av "${BEPINEX_DIR}/patchers"/* "${USER_BEPINEX}/patchers/"
            fi
            rm -rf "${BEPINEX_DIR}/patchers"
            ln -sf "${USER_BEPINEX}/patchers" "${BEPINEX_DIR}/patchers"
            echo "BepInEx patchers symlink recreated"
        fi

        # Check config symlink
        if [ -L "${BEPINEX_DIR}/config" ]; then
            TARGET=$(readlink -f "${BEPINEX_DIR}/config")
            if [ "$TARGET" != "$(readlink -f ${USER_BEPINEX}/config)" ]; then
                echo "WARNING: BepInEx config symlink points to wrong location!"
            fi
        elif [ -d "${BEPINEX_DIR}/config" ]; then
            echo "ERROR: ${BEPINEX_DIR}/config is a directory, not a symlink!"
            echo "Attempting to fix..."
            if [ "$(ls -A ${BEPINEX_DIR}/config 2>/dev/null)" ]; then
                cp -av "${BEPINEX_DIR}/config"/* "${USER_BEPINEX}/config/"
            fi
            rm -rf "${BEPINEX_DIR}/config"
            ln -sf "${USER_BEPINEX}/config" "${BEPINEX_DIR}/config"
            echo "BepInEx config symlink recreated"
        fi

        # Periodic status for BepInEx
        if [ $((counter % 10)) -eq 0 ]; then
            echo "[$(date)] BepInEx symlinks verified"
        fi
    fi

    # === Check admin/ban/permitted list symlinks ===
    if [ -d "$UNITY_CONFIG_DIR" ]; then
        for filename in adminlist.txt bannedlist.txt permittedlist.txt; do
            source_file="${UNITY_CONFIG_DIR}/${filename}"
            target_file="${USERFILES_DIR}/${filename}"
            
            # Check if symlink exists and is correct
            if [ -L "$source_file" ]; then
                current_target=$(readlink "$source_file")
                if [ "$current_target" != "$target_file" ]; then
                    echo "WARNING: ${filename} symlink points to wrong location!"
                    echo "  Current: $current_target"
                    echo "  Expected: $target_file"
                    echo "  Fixing..."
                    rm -f "$source_file"
                    ln -sf "$target_file" "$source_file"
                fi
            elif [ -f "$source_file" ]; then
                # File exists but is not a symlink
                echo "WARNING: ${filename} is a file, not a symlink!"
                echo "  Backing up and creating symlink..."
                
                # Ensure target exists
                if [ ! -f "$target_file" ]; then
                    touch "$target_file"
                fi
                
                # Append content to target
                cat "$source_file" >> "$target_file"
                rm -f "$source_file"
                ln -sf "$target_file" "$source_file"
                echo "  ${filename} symlink recreated"
            elif [ ! -e "$source_file" ]; then
                # Symlink doesn't exist, create it
                if [ ! -f "$target_file" ]; then
                    touch "$target_file"
                fi
                ln -sf "$target_file" "$source_file"
                echo "Created missing ${filename} symlink"
            fi
        done
    fi

    # Also check if there are any orphaned .db files in the server root
    if [ -f /opt/valheim/*.db ]; then
        echo "WARNING: Found world files in /opt/valheim root!"
        ls -lh /opt/valheim/*.db
        echo "Moving to persistent storage..."
        mv -v /opt/valheim/*.db /opt/valheim/*.fwl "$USER_WORLDS/" 2>/dev/null || true
    fi
done