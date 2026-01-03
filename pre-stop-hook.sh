#!/bin/bash
# Pre-stop hook to verify world save before shutdown
# This runs when the container receives SIGTERM

WORLDS_DIR="/userfiles/worlds_local"
WORLD_NAME="${WORLD_NAME:-Dedicated}"
DB_FILE="$WORLDS_DIR/${WORLD_NAME}.db"

echo "=========================================="
echo "PRE-STOP HOOK: Verifying world save"
echo "=========================================="

# Record when stop was requested
STOP_TIME=$(date +%s)
STOP_DATE=$(date "+%Y-%m-%d %H:%M:%S")

echo "Stop requested at: $STOP_DATE ($STOP_TIME)"
echo ""

# Get current .db timestamp if it exists
if [ -f "$DB_FILE" ]; then
    OLD_TIMESTAMP=$(stat -c %Y "$DB_FILE" 2>/dev/null || stat -f %m "$DB_FILE" 2>/dev/null)
    OLD_DATE=$(date -d "@$OLD_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$OLD_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    echo "Current .db timestamp: $OLD_DATE ($OLD_TIMESTAMP)"
else
    OLD_TIMESTAMP=0
    echo "⚠ No existing .db file (will wait for creation)"
fi

echo ""
echo "Waiting for Valheim server to save world..."
echo "(Timeout: 90 seconds)"
echo ""

# Wait up to 90 seconds for the .db file to be updated
MAX_WAIT=90
WAITED=0
SAVED=false

while [ $WAITED -lt $MAX_WAIT ]; do
    sleep 2
    WAITED=$((WAITED + 2))
    
    if [ -f "$DB_FILE" ]; then
        NEW_TIMESTAMP=$(stat -c %Y "$DB_FILE" 2>/dev/null || stat -f %m "$DB_FILE" 2>/dev/null)
        
        # Check if timestamp is newer than or equal to stop time
        if [ $NEW_TIMESTAMP -ge $STOP_TIME ]; then
            NEW_DATE=$(date -d "@$NEW_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$NEW_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
            echo "✓ World saved successfully!"
            echo "  New timestamp: $NEW_DATE ($NEW_TIMESTAMP)"
            echo "  Save completed in ${WAITED}s"
            SAVED=true
            break
        fi
    fi
    
    # Show progress every 10 seconds
    if [ $((WAITED % 10)) -eq 0 ]; then
        echo "  Waiting for save... (${WAITED}s / ${MAX_WAIT}s)"
    fi
done

echo ""

if [ "$SAVED" = false ]; then
    echo "=========================================="
    echo "⚠ WARNING: Could not verify world save!"
    echo "=========================================="
    
    if [ -f "$DB_FILE" ]; then
        FINAL_TIMESTAMP=$(stat -c %Y "$DB_FILE" 2>/dev/null || stat -f %m "$DB_FILE" 2>/dev/null)
        FINAL_DATE=$(date -d "@$FINAL_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$FINAL_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
        AGE=$(($(date +%s) - FINAL_TIMESTAMP))
        
        echo "Final .db timestamp: $FINAL_DATE ($FINAL_TIMESTAMP)"
        echo "Age: ${AGE}s old"
        echo ""
        
        if [ $FINAL_TIMESTAMP -lt $STOP_TIME ]; then
            echo "⚠ .db file was NOT updated during shutdown"
            echo "  Last save was ${AGE}s ago"
            echo ""
            echo "This could mean:"
            echo "  - No players were connected (no changes to save)"
            echo "  - Server hasn't run 20 minutes yet (no auto-save)"
            echo "  - World data is still only in memory"
        fi
    else
        echo "⚠ No .db file exists - world never saved to disk"
        echo "  Server may have been running less than 20 minutes"
    fi
    
    echo ""
    echo "Proceeding with shutdown..."
fi

echo "=========================================="
echo ""