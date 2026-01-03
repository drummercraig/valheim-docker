#!/bin/bash
set -e

WORLDS_DIR="/config/worlds_local"
BACKUP_DIR="${BACKUPS_DIRECTORY:-/config/backups}"
MAX_AGE="${BACKUPS_MAX_AGE:-3}"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to create backup
create_backup() {
    if [ ! -d "$WORLDS_DIR" ]; then
        echo "Worlds directory not found: $WORLDS_DIR"
        return 1
    fi
    
    # Check if there are any world files
    if [ -z "$(ls -A $WORLDS_DIR/*.db 2>/dev/null)" ]; then
        echo "No world files found to backup"
        return 0
    fi
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/worlds_backup_${TIMESTAMP}.zip"
    
    echo "Creating backup: $BACKUP_FILE"
    
    cd /config
    zip -r "$BACKUP_FILE" worlds_local/ -q
    
    if [ $? -eq 0 ]; then
        echo "Backup created successfully: $BACKUP_FILE"
        
        # Clean up old backups
        cleanup_old_backups
    else
        echo "Failed to create backup"
        return 1
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    echo "Cleaning up backups older than $MAX_AGE days..."
    
    find "$BACKUP_DIR" -name "worlds_backup_*.zip" -type f -mtime +$MAX_AGE -delete
    
    REMAINING=$(find "$BACKUP_DIR" -name "worlds_backup_*.zip" -type f | wc -l)
    echo "Backups remaining: $REMAINING"
}

# Create initial backup
if [ "${BACKUPS_ENABLED:-true}" = "true" ]; then
    echo "Waiting 60 seconds before creating initial backup..."
    sleep 60
    create_backup
fi

# Backup loop
while [ "${BACKUPS_ENABLED:-true}" = "true" ]; do
    sleep "${BACKUPS_INTERVAL:-3600}"
    create_backup
done

echo "Backups disabled, exiting..."