#!/bin/bash
# Migration script to move from old paths to new paths
# Run this on the Docker host BEFORE rebuilding the container
# Usage: ./migrate-to-new-paths.sh

set -e

echo "=========================================="
echo "VALHEIM SERVER PATH MIGRATION"
echo "=========================================="
echo ""
echo "This script will migrate your Valheim server data from:"
echo "  ./config -> ./userfiles"
echo "  ./data   -> ./serverfiles"
echo ""

# Check if container is running
if docker ps --format '{{.Names}}' | grep -q "valheim-server"; then
    echo "⚠ WARNING: Container 'valheim-server' is currently running!"
    echo "Please stop it first with: docker compose stop"
    exit 1
fi

# Check if old directories exist
OLD_CONFIG_EXISTS=false
OLD_DATA_EXISTS=false

if [ -d "./config" ]; then
    OLD_CONFIG_EXISTS=true
    echo "✓ Found ./config directory"
fi

if [ -d "./data" ]; then
    OLD_DATA_EXISTS=true
    echo "✓ Found ./data directory"
fi

if [ "$OLD_CONFIG_EXISTS" = false ] && [ "$OLD_DATA_EXISTS" = false ]; then
    echo ""
    echo "No old directories found. Nothing to migrate."
    echo "Your setup might already be using the new paths."
    exit 0
fi

echo ""

# Check if new directories already exist
if [ -d "./userfiles" ] && [ "$(ls -A ./userfiles 2>/dev/null)" ]; then
    echo "⚠ WARNING: ./userfiles directory already exists and is not empty!"
    read -p "Overwrite/merge with old config data? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Migration cancelled"
        exit 1
    fi
fi

if [ -d "./serverfiles" ] && [ "$(ls -A ./serverfiles 2>/dev/null)" ]; then
    echo "⚠ WARNING: ./serverfiles directory already exists and is not empty!"
    read -p "Overwrite/merge with old data? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Migration cancelled"
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "Starting migration..."
echo "=========================================="
echo ""

# Migrate config -> userfiles
if [ "$OLD_CONFIG_EXISTS" = true ]; then
    echo "Migrating ./config -> ./userfiles"
    
    if [ -d "./userfiles" ]; then
        echo "  Merging into existing ./userfiles"
        cp -rv ./config/* ./userfiles/
    else
        echo "  Moving ./config to ./userfiles"
        mv -v ./config ./userfiles
    fi
    
    # Keep backup of old config
    if [ ! -d "./userfiles" ]; then
        echo "  Creating backup: ./config.backup"
        cp -r ./config ./config.backup
    fi
    
    echo "✓ Config migration complete"
fi

echo ""

# Migrate data -> serverfiles
if [ "$OLD_DATA_EXISTS" = true ]; then
    echo "Migrating ./data -> ./serverfiles"
    
    if [ -d "./serverfiles" ]; then
        echo "  Merging into existing ./serverfiles"
        cp -rv ./data/* ./serverfiles/
    else
        echo "  Moving ./data to ./serverfiles"
        mv -v ./data ./serverfiles
    fi
    
    # Keep backup of old data
    if [ ! -d "./serverfiles" ]; then
        echo "  Creating backup: ./data.backup"
        cp -r ./data ./data.backup
    fi
    
    echo "✓ Data migration complete"
fi

echo ""
echo "=========================================="
echo "Migration complete!"
echo "=========================================="
echo ""

# Show what was migrated
echo "New directory structure:"
if [ -d "./userfiles" ]; then
    echo "  ./userfiles ($(du -sh ./userfiles | cut -f1))"
    if [ -d "./userfiles/worlds_local" ]; then
        echo "    └─ worlds_local/ ($(ls ./userfiles/worlds_local/*.db 2>/dev/null | wc -l) world files)"
    fi
    if [ -d "./userfiles/backups" ]; then
        echo "    └─ backups/ ($(ls ./userfiles/backups/*.zip 2>/dev/null | wc -l) backup files)"
    fi
fi

if [ -d "./serverfiles" ]; then
    echo "  ./serverfiles ($(du -sh ./serverfiles | cut -f1))"
fi

echo ""
echo "Next steps:"
echo "  1. Review the migration above"
echo "  2. Rebuild the container: docker compose build --no-cache"
echo "  3. Start the server: docker compose up -d"
echo "  4. Verify worlds appear: ls -la userfiles/worlds_local/"
echo ""
echo "If everything works, you can delete the old directories:"
echo "  rm -rf ./config ./data"
echo ""

if [ -d "./config.backup" ]; then
    echo "Backup created at: ./config.backup"
fi
if [ -d "./data.backup" ]; then
    echo "Backup created at: ./data.backup"
fi