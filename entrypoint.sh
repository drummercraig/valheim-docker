#!/bin/bash
set -e
source ./settings.env

# Set timezone
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install SteamCmd
./install_steamcmd.sh

# Install Valheim with retry logic
./install_valheim.sh

# Install mods based on MOD_LOADER
case "$MOD_LOADER" in
  BepInEx)
    [ "$BEPINEX_ENABLED" = "true" ] && ./install_bepinex.sh
    ;;
  ValheimPlus)
    ./install_valheimplus.sh
    ;;
esac

# Setup cron for restart
echo "$RESTART_CRON root /restart.sh" >> /etc/crontab
service cron start

# Prepare persistent directories
mkdir -p "$PLUGIN_DEST" "$PATCHER_DEST" "$CONFIG_DEST" "$WORLD_SRC" "$WORLD_BACKUP"

# Sync persistent data
rsync -a "$PLUGIN_SRC/" "$PLUGIN_DEST/" || true
rsync -a "$PATCHER_SRC/" "$PATCHER_DEST/" || true
rsync -a "$CONFIG_SRC/" "$CONFIG_DEST/" || true

# Start backup process in background
./backup.sh &

# Build and execute Valheim server command using shared script
START_CMD=$(./build_start_cmd.sh)
echo "Starting Valheim server with command:"
echo "$START_CMD"

cd "$VALHEIM_DIR"
eval $START_CMD
