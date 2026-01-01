#!/bin/bash
source /settings.env

PLAYERS=$(netstat -anu | grep ":$SERVER_PORT" | wc -l)

if [ "$PLAYERS" -eq 0 ]; then
    echo "No players online. Restarting server..."
    docker restart valheim-server
else
    echo "Players online. Skipping restart."
fi
