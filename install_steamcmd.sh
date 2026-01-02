#!/bin/bash
set -e
source ./settings.env

echo "======================================"
echo "SteamCMD Installation"
echo "======================================"

if [ ! -f "${STEAMCMD_DIR}/steamcmd.sh" ]; then
    echo "Installing SteamCMD..."
    mkdir -p ${STEAMCMD_DIR}
    cd ${STEAMCMD_DIR}
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - > /dev/null 2>&1
    chmod +x ${STEAMCMD_DIR}/steamcmd.sh
    echo "✓ SteamCMD installed"
else
    echo "✓ SteamCMD already installed"
fi

echo "======================================"
