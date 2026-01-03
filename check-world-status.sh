#!/bin/bash
# Host script to check world save status before stopping container
# Run from host: ./check-world-status.sh
# Or: docker compose exec valheim-server /usr/local/bin/check-world-status

CONTAINER_NAME="${1:-valheim-server}"

echo "=========================================="
echo "VALHEIM WORLD STATUS CHECK"
echo "=========================================="
echo ""

# Check if running via docker compose exec (already inside container)
if [ -f /opt/valheim/valheim_server.x86_64 ]; then
    # We're inside the container
    WORLDS_DIR="/userfiles/worlds_local"
    WORLD_NAME="${WORLD_NAME:-Dedicated}"
    DB_FILE="$WORLDS_DIR/${WORLD_NAME}.db"
    
    echo "World: $WORLD_NAME"
    echo "Location: $DB_FILE"
    echo ""
    
    if [ ! -f "$DB_FILE" ]; then
        echo "❌ Status: NO SAVE FILE EXISTS"
        echo ""
        echo "The world has never been saved to disk."
        echo "This means:"
        echo "  - Server has been running less than 20 minutes"
        echo "  - No players have connected yet"
        echo "  - World data only exists in memory"
        echo ""
        echo "⚠ STOPPING NOW WILL LOSE THE WORLD!"
        echo ""
        exit 1
    fi
    
    # Get file info
    TIMESTAMP=$(stat -c %Y "$DB_FILE" 2>/dev/null || stat -f %m "$DB_FILE" 2>/dev/null)
    FILE_DATE=$(date -d "@$TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    FILE_SIZE=$(stat -c %s "$DB_FILE" 2>/dev/null || stat -f %z "$DB_FILE" 2>/dev/null)
    FILE_SIZE_MB=$(echo "scale=2; $FILE_SIZE / 1024 / 1024" | bc)
    
    CURRENT_TIME=$(date +%s)
    AGE=$((CURRENT_TIME - TIMESTAMP))
    AGE_MIN=$((AGE / 60))
    AGE_SEC=$((AGE % 60))
    
    echo "✓ Save file exists"
    echo ""
    echo "File details:"
    echo "  Last modified: $FILE_DATE"
    echo "  File size: ${FILE_SIZE_MB} MB"
    echo "  Age: ${AGE_MIN}m ${AGE_SEC}s"
    echo ""
    
    # Determine status based on age
    if [ $AGE -lt 120 ]; then
        # Less than 2 minutes old
        echo "✓ Status: RECENTLY SAVED (Safe to stop)"
        echo "  World was saved within the last 2 minutes"
        exit 0
    elif [ $AGE -lt 1200 ]; then
        # Less than 20 minutes old
        echo "⚠ Status: SAVE IS ${AGE_MIN} MINUTES OLD"
        echo ""
        echo "Recommendation:"
        echo "  Run 'docker exec $CONTAINER_NAME /usr/local/bin/force-save'"
        echo "  to trigger a fresh save before stopping."
        exit 2
    else
        # More than 20 minutes old
        echo "❌ Status: SAVE IS STALE (${AGE_MIN} minutes old)"
        echo ""
        echo "⚠ You may lose up to ${AGE_MIN} minutes of progress!"
        echo ""
        echo "Recommendation:"
        echo "  Run 'docker exec $CONTAINER_NAME /usr/local/bin/force-save'"
        echo "  to trigger a fresh save before stopping."
        exit 2
    fi
    
else
    # We're on the host, need to exec into container
    echo "Checking container: $CONTAINER_NAME"
    echo ""
    
    if ! docker exec "$CONTAINER_NAME" test -f /opt/valheim/valheim_server.x86_64 2>/dev/null; then
        echo "❌ ERROR: Container '$CONTAINER_NAME' not found or not running"
        exit 1
    fi
    
    # Run this script inside the container
    docker exec "$CONTAINER_NAME" /usr/local/bin/check-world-status
    exit $?
fi