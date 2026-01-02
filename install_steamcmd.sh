#!/bin/bash
set -e

CACHE_DIR="/opt/cache"
STEAMCMD_ARCHIVE="$CACHE_DIR/steamcmd_linux.tar.gz"

mkdir -p ~/steamcmd

if [ -f "$STEAMCMD_ARCHIVE" ]; then
    echo "Using cached SteamCMD archive..."
else
    echo "Downloading SteamCMD..."
    curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz -o "$STEAMCMD_ARCHIVE"
fi

tar -xzvf "$STEAMCMD_ARCHIVE" -C ~/steamcmd
