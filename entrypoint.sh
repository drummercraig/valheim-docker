#!/bin/bash
set -e

# Fix permissions on mounted volumes (ignore errors if not allowed)
echo "Fixing permissions on /opt/valheim and /opt/cache..."
chown -R valheim:valheim /opt/valheim /opt/cache || echo "Skipping chown on mounted volumes"
chmod -R 755 /opt/valheim /opt/cache || echo "Skipping chmod on mounted volumes"

# Drop privileges to valheim user
exec su -s /bin/bash valheim -c "/opt/valheim/valheim_server.x86_64 -name \"$SERVER_NAME\" -port 2456 -world \"$WORLD_NAME\" -password \"$SERVER_PASS\" -public \"$SERVER_PUBLIC\""
