
#!/bin/bash
set -e

# Ensure valheim user owns the mounted volume and its contents
chown -R valheim:valheim /opt/valheim
chmod -R 755 /opt/valheim

# Start the Valheim server
exec /opt/valheim/valheim_server.x86_64 -name "$SERVER_NAME" -port 2456 -world "$WORLD_NAME" -password "$SERVER_PASS" -public "$SERVER_PUBLIC"
