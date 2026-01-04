#!/bin/bash
# Debug script to check world file locations
# Run inside container: docker exec valheim-server /usr/local/bin/debug-worlds

echo "=========================================="
echo "VALHEIM WORLD FILES DEBUG"
echo "=========================================="
echo ""

echo "1. Checking Unity config directory (ACTUAL location)"
echo "--------------------------------------"
UNITY_WORLDS="/root/.config/unity3d/IronGate/Valheim/worlds_local"
if [ -L "$UNITY_WORLDS" ]; then
    echo "✓ Is a symlink"
    echo "  Target: $(readlink -f $UNITY_WORLDS)"
    ls -la "$UNITY_WORLDS"/ 2>/dev/null || echo "  (empty or inaccessible)"
elif [ -d "$UNITY_WORLDS" ]; then
    echo "✗ Is a DIRECTORY (should be symlink!)"
    ls -la "$UNITY_WORLDS"/
elif [ -e "$UNITY_WORLDS" ]; then
    echo "✗ Exists but is not a directory or symlink"
    ls -la "$UNITY_WORLDS"
else
    echo "✗ Does NOT exist"
fi
echo ""

echo "2. Checking /opt/valheim/worlds_local"
echo "--------------------------------------"
if [ -L /opt/valheim/worlds_local ]; then
    echo "✓ Is a symlink"
    echo "  Target: $(readlink -f /opt/valheim/worlds_local)"
    ls -la /opt/valheim/worlds_local/ 2>/dev/null || echo "  (empty or inaccessible)"
elif [ -d /opt/valheim/worlds_local ]; then
    echo "✗ Is a DIRECTORY (should be symlink!)"
    ls -la /opt/valheim/worlds_local/
elif [ -e /opt/valheim/worlds_local ]; then
    echo "✗ Exists but is not a directory or symlink"
    ls -la /opt/valheim/worlds_local
else
    echo "✗ Does NOT exist"
fi
echo ""

echo "3. Checking /userfiles/worlds_local (PERSISTENT storage)"
echo "--------------------------------------"
if [ -d /userfiles/worlds_local ]; then
    echo "✓ Directory exists"
    echo "  Contents:"
    ls -lah /userfiles/worlds_local/ 2>/dev/null || echo "  (empty)"
else
    echo "✗ Directory does NOT exist"
fi
echo ""

echo "4. Searching for .db and .fwl files EVERYWHERE"
echo "--------------------------------------"
echo "In /root/.config/unity3d/:"
find /root/.config/unity3d/ -name "*.db" -o -name "*.fwl" 2>/dev/null || echo "  (none found)"
echo ""
echo "In /opt/valheim:"
find /opt/valheim -maxdepth 2 -name "*.db" -o -name "*.fwl" 2>/dev/null || echo "  (none found)"
echo ""
echo "In /userfiles:"
find /userfiles -name "*.db" -o -name "*.fwl" 2>/dev/null || echo "  (none found)"
echo ""

echo "5. Server configuration"
echo "--------------------------------------"
echo "  SERVER_NAME: $SERVER_NAME"
echo "  WORLD_NAME: $WORLD_NAME"
echo "  SERVER_PORT: $SERVER_PORT"
echo ""

echo "6. Process status"
echo "--------------------------------------"
ps aux | grep valheim_server || echo "  (server not running)"
echo ""

echo "7. Recent server logs (last 30 lines)"
echo "--------------------------------------"
tail -30 /var/log/supervisor/valheim-server-stdout*.log 2>/dev/null || echo "  (no logs found)"
echo ""

echo "=========================================="
echo "EXPECTED: Unity path should be symlink to /userfiles/worlds_local"
echo "=========================================="