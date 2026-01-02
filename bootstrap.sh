#!/bin/bash
set -e

echo "Starting bootstrap process..."

# Fix permissions on mounted volumes (ignore errors if not allowed)
for dir in /opt/valheim /opt/cache /opt/config /opt/backups; do
    echo "Ensuring permissions for $dir..."
    chown -R valheim:valheim "$dir" || echo "Skipping chown on $dir"
    chmod -R 755 "$dir" || echo "Skipping chmod on $dir"
done

# Prepare backup and config directories
mkdir -p /opt/backups /opt/config

# Drop privileges to valheim user and start server
echo "Starting Valheim server as valheim user..."
exec su -s /bin/bash valheim -c "/opt/valheim/valheim_server.x86_64 -name \"$SERVER_NAME\" -port 2456 -world \"$WORLD_NAME\" -password \"$SERVER_PASS\" -public \"$SERVER_PUBLIC\""
