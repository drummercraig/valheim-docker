#!/bin/bash
set -e
source ./settings.env

if [ "$RESTART_IF_IDLE" = "true" ]; then
    PLAYER_COUNT=$(netstat -an | grep $SERVER_PORT | wc -l)
    if [ $PLAYER_COUNT -eq 0 ]; then
        echo "No players detected. Restarting Valheim server..."
        pkill -f start_server.sh
        sleep 5

        # Build and execute Valheim server command using shared script
        START_CMD=$(./build_start_cmd.sh)
        echo "Restarting Valheim server with command:"
        echo "$START_CMD"

        cd "$VALHEIM_DIR"
        eval $START_CMD
    else
        echo "Players are connected. Skipping restart."
    fi
else
    echo "RESTART_IF_IDLE is disabled. No restart performed."
fi
