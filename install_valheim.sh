#!/bin/bash
set -e
source /settings.env

echo "======================================"
echo "Valheim Server Installation"
echo "======================================"

if [ -f "${VALHEIM_DIR}/valheim_server.x86_64" ]; then
    echo "✓ Valheim server already installed (skipping full download)"
    echo "Checking for updates..."
    
    OUTPUT=$(mktemp)
    if "${STEAMCMD_DIR}/steamcmd.sh" \
        +force_install_dir "${VALHEIM_DIR}" \
        +login anonymous \
        +app_update 896660 \
        +quit > "$OUTPUT" 2>&1; then
        rm -f "$OUTPUT"
        echo "✓ Valheim server up to date"
        echo "======================================"
        exit 0
    fi
    rm -f "$OUTPUT"
fi

install_valheim() {
    local MAX_RETRIES=5
    local RETRY_DELAY=10
    local attempt=1
    
    while [ $attempt -le $MAX_RETRIES ]; do
        echo "Installation attempt $attempt of $MAX_RETRIES..."
        
        OUTPUT=$(mktemp)
        if "${STEAMCMD_DIR}/steamcmd.sh" \
            +force_install_dir "${VALHEIM_DIR}" \
            +login anonymous \
            +app_update 896660 validate \
            +quit > "$OUTPUT" 2>&1; then
            rm -f "$OUTPUT"
            echo "✓ Valheim server ready"
            return 0
        else
            EXIT_CODE=$?
            if grep -q "Missing configuration" "$OUTPUT"; then
                echo "⚠ Steam CDN issue detected (Missing configuration)"
                if [ $attempt -lt $MAX_RETRIES ]; then
                    echo "Retrying in ${RETRY_DELAY} seconds..."
                    sleep $RETRY_DELAY
                    RETRY_DELAY=$((RETRY_DELAY * 2))
                    attempt=$((attempt + 1))
                    rm -f "$OUTPUT"
                    continue
                fi
            fi
            echo "ERROR: SteamCMD failed with exit code $EXIT_CODE"
            echo "Last 30 lines of output:"
            tail -30 "$OUTPUT"
            rm -f "$OUTPUT"
            return $EXIT_CODE
        fi
    done
    
    echo "ERROR: Failed after $MAX_RETRIES attempts"
    return 1
}

install_valheim
echo "======================================"
