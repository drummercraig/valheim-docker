#!/bin/bash
set -e

# Load environment variables from /opt
source /opt/settings.env

# Set timezone
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

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

# Setup cron for scheduled restart
echo "$RESTART_CRON root /restart.sh" >> /etc/crontab
service cron start

# Prepare persistent directories
mkdir -p "$PLUGIN_SRC" "$PATCHER_SRC" "$CONFIG_SRC"
mkdir -p "$PLUGIN_DEST" "$PATCHER_DEST" "$CONFIG_DEST"
mkdir -p "$WORLD_SRC" "$WORLD_BACKUP"

# Sync persistent data using rsync
rsync -a "$PLUGIN_SRC/" "$PLUGIN_DEST/" || true
rsync -a "$PATCHER_SRC/" "$PATCHER_DEST/" || true
rsync -a "$CONFIG_SRC/" "$CONFIG_DEST/" || true

# Start backup process in background
./backup.sh &

# Build Valheim server start command using shared script
START_CMD=$(./build_start_cmd.sh)
echo "Starting Valheim server with command:"
echo "$START_CMD"

# Change to Valheim directory and execute command
cd "$VALHEIM_DIR"
eval $START_CMD
