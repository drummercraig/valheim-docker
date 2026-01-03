#!/bin/bash
# Force Valheim to save the world by gracefully restarting the server
# Run: docker exec valheim-server /usr/local/bin/force-save

echo "=========================================="
echo "FORCING WORLD SAVE"
echo "=========================================="
echo ""

echo "Current world files in /config/worlds_local:"
ls -lh /config/worlds_local/
echo ""

echo "Gracefully restarting Valheim server to force save..."
echo "This will:"
echo "  1. Send SIGTERM to the server"
echo "  2. Wait for server to save and shut down"
echo "  3. Restart the server"
echo ""

supervisorctl restart valheim-server

echo ""
echo "Waiting for restart to complete..."
sleep 10

echo ""
echo "Updated world files in /config/worlds_local:"
ls -lh /config/worlds_local/
echo ""

if [ -f /config/worlds_local/*.db ]; then
    echo "✓ SUCCESS: .db file created/updated"
else
    echo "⚠ WARNING: .db file not yet created"
    echo "  Wait another 10-20 minutes or check server logs"
fi

echo ""
echo "=========================================="