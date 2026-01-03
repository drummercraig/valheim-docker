#!/bin/bash
# Force Valheim to save the world by gracefully restarting the server
# Run: docker exec valheim-server /usr/local/bin/force-save

echo "=========================================="
echo "FORCING WORLD SAVE"
echo "=========================================="
echo ""

WORLDS_DIR="/userfiles/worlds_local"
WORLD_NAME="${WORLD_NAME:-Dedicated}"
DB_FILE="$WORLDS_DIR/${WORLD_NAME}.db"

echo "World: $WORLD_NAME"
echo "Database file: $DB_FILE"
echo ""

# Get current timestamp of .db file (if it exists)
if [ -f "$DB_FILE" ]; then
    OLD_TIMESTAMP=$(stat -c %Y "$DB_FILE" 2>/dev/null || stat -f %m "$DB_FILE" 2>/dev/null)
    OLD_DATE=$(date -d "@$OLD_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$OLD_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    echo "Current .db file timestamp: $OLD_DATE ($OLD_TIMESTAMP)"
else
    OLD_TIMESTAMP=0
    echo "⚠ No existing .db file found (this is normal for new worlds)"
fi

echo ""
echo "Current world files in /userfiles/worlds_local:"
ls -lh "$WORLDS_DIR/" 2>/dev/null || echo "(empty)"
echo ""

# Record the time before restart
RESTART_TIME=$(date +%s)
echo "Restart initiated at: $(date "+%Y-%m-%d %H:%M:%S") ($RESTART_TIME)"
echo ""

echo "Gracefully restarting Valheim server to force save..."
echo "This will:"
echo "  1. Send SIGTERM to the server"
echo "  2. Wait for server to save and shut down (up to 120s)"
echo "  3. Restart the server"
echo ""

supervisorctl restart valheim-server

echo ""
echo "Waiting for restart to complete and world to be saved..."

# Wait up to 120 seconds for the .db file to be updated
MAX_WAIT=120
WAITED=0
SAVED=false

while [ $WAITED -lt $MAX_WAIT ]; do
    sleep 2
    WAITED=$((WAITED + 2))
    
    if [ -f "$DB_FILE" ]; then
        NEW_TIMESTAMP=$(stat -c %Y "$DB_FILE" 2>/dev/null || stat -f %m "$DB_FILE" 2>/dev/null)
        
        # Check if timestamp is newer than our restart time
        if [ $NEW_TIMESTAMP -ge $RESTART_TIME ]; then
            NEW_DATE=$(date -d "@$NEW_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$NEW_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
            echo ""
            echo "=========================================="
            echo "✓ SUCCESS: World saved!"
            echo "=========================================="
            echo "New .db file timestamp: $NEW_DATE ($NEW_TIMESTAMP)"
            echo "Time to save: ${WAITED}s"
            echo ""
            echo "Updated world files:"
            ls -lh "$WORLDS_DIR/"
            echo ""
            SAVED=true
            break
        fi
    fi
    
    # Show progress every 10 seconds
    if [ $((WAITED % 10)) -eq 0 ]; then
        echo "  Still waiting... (${WAITED}s / ${MAX_WAIT}s)"
    fi
done

echo ""

if [ "$SAVED" = false ]; then
    echo "=========================================="
    echo "⚠ WARNING: World may not have been saved!"
    echo "=========================================="
    
    if [ -f "$DB_FILE" ]; then
        CURRENT_TIMESTAMP=$(stat -c %Y "$DB_FILE" 2>/dev/null || stat -f %m "$DB_FILE" 2>/dev/null)
        CURRENT_DATE=$(date -d "@$CURRENT_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$CURRENT_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
        AGE=$(($(date +%s) - CURRENT_TIMESTAMP))
        
        echo "Current .db timestamp: $CURRENT_DATE ($CURRENT_TIMESTAMP)"
        echo "Age of .db file: ${AGE}s old"
        echo ""
        
        if [ $CURRENT_TIMESTAMP -lt $RESTART_TIME ]; then
            echo "❌ CRITICAL: .db file is OLDER than restart time!"
            echo "   The world was NOT saved during this restart."
            echo ""
            echo "Recommendations:"
            echo "  1. Wait for automatic save (occurs every 20 minutes)"
            echo "  2. Run this script again"
            echo "  3. Check server logs: docker compose logs valheim-server"
            echo ""
            exit 1
        else
            echo "✓ .db file timestamp is recent"
            echo "  The file may have been saved just before the restart."
            echo ""
        fi
    else
        echo "❌ CRITICAL: No .db file exists!"
        echo ""
        echo "This means:"
        echo "  - World has never been saved to disk yet"
        echo "  - Server needs to run for 20 minutes for first auto-save"
        echo "  - Or players need to join and play"
        echo ""
        exit 1
    fi
fi

echo "=========================================="