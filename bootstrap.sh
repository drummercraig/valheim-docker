
#!/bin/bash
set -e

echo "Starting bootstrap process..."

# Fix permissions on mounted volumes (ignore errors if not allowed)
for dir in /opt/valheim /opt/cache /opt/config /opt/backups; do
    echo "Ensuring permissions for $dir..."
    chown -R valheim:valheim "$dir" || echo "Skipping chown on $dir"
    chmod -R 755 "$dir" || echo "Skipping chmod on $dir"
done

# Install Valheim at runtime if missing
if [ ! -f /opt/valheim/valheim_server.x86_64 ]; then
    echo "Valheim server binary missing. Installing latest version..."
    su -s /bin/bash valheim -c "~/steamcmd/steamcmd.sh +force_install_dir /opt/valheim +login anonymous +app_update 896660 validate +quit"
fi

# Drop privileges and start server
echo "Starting Valheim server as valheim user..."
exec su -s /bin/bash valheim -c "/opt/valheim/valheim_server.x86_64 -name \"$SERVER_NAME\" -port 2456 -world \"$WORLD_NAME\" -password \"$SERVER_PASS\" -public \"$SERVER_PUBLIC\"
