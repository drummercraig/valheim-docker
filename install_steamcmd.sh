
#!/bin/bash
set -e

# Create steamcmd directory and download SteamCMD
mkdir -p ~/steamcmd
cd ~/steamcmd
curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xzv
