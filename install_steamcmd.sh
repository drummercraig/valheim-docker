#!/bin/bash
set -e

# Create steamcmd directory and download SteamCMD
mkdir -p ~/steamcmd
cd ~/steamcmd
curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xzv

# Ensure valheim user owns steamcmd directory
#chown -R valheim:valheim ~/steamcmd
#chmod -R 755 ~/steamcmd
