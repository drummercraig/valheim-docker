#!/bin/bash
source ./settings.env
RETRIES=5
COUNT=0

while [ $COUNT -lt $RETRIES ]; do
    echo "Installing Valheim (Attempt $((COUNT+1)))..."
    mkdir -p $STEAMCMD_DIR && cd $STEAMCMD_DIR
    curl -s https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xz
    ./steamcmd.sh +force_install_dir $VALHEIM_DIR +login anonymous +app_update 896660 validate +quit && break
    COUNT=$((COUNT+1))
    sleep 10
done

if [ $COUNT -eq $RETRIES ]; then
    echo "Valheim installation failed after $RETRIES attempts."
    exit 1
fi
