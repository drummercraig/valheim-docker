#!/bin/bash
# This script builds the Valheim server start command dynamically from settings.env
source ./settings.env

START_CMD="./start_server.sh \
    -name \"$SERVER_NAME\" \
    -port \"$SERVER_PORT\" \
    -world \"$WORLD_NAME\" \
    -password \"$SERVER_PASSWORD\" \
    -public \"$SERVER_PUBLIC\""

[ "$CROSSPLAY_ENABLED" = "true" ] && START_CMD="$START_CMD -crossplay"

START_CMD="$START_CMD \
    -modifier_combat \"$MODIFIER_COMBAT\" \
    -modifier_resources \"$MODIFIER_RESOURCES\" \
    -modifier_portals \"$MODIFIER_PORTALS\" \
    -modifier_deathpenalty \"$MODIFIER_DEATHPENALTY\" \
    -preset \"$GAME_PRESET\" \
    -difficulty \"$DIFFICULTY\" \
    -day_length \"$DAY_LENGTH\" \
    -enemy_respawn \"$ENEMY_RESPAWN\" \
    -event_frequency \"$EVENT_FREQUENCY\""

[ "$SETKEY_PLAYEREVENTS" = "true" ] && START_CMD="$START_CMD -setkey_playerevents"

echo "$START_CMD"
