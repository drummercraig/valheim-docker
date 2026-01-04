#!/bin/bash
# Debug script to check BepInEx installation status
# Run: docker exec valheim-server /usr/local/bin/debug-bepinex

echo "=========================================="
echo "BEPINEX DEBUG INFORMATION"
echo "=========================================="
echo ""

echo "1. Environment Variables"
echo "--------------------------------------"
echo "MOD_LOADER: ${MOD_LOADER:-NOT SET}"
echo "VALHEIM_DIR: /opt/valheim"
echo ""

echo "2. Valheim Server Installation"
echo "--------------------------------------"
if [ -f /opt/valheim/valheim_server.x86_64 ]; then
    echo "✓ Valheim server installed"
    ls -lh /opt/valheim/valheim_server.x86_64
else
    echo "✗ Valheim server NOT installed"
fi
echo ""

echo "3. BepInEx Installation Status"
echo "--------------------------------------"
if [ -d /opt/valheim/BepInEx ]; then
    echo "✓ BepInEx directory exists"
    echo ""
    echo "BepInEx directory contents:"
    ls -la /opt/valheim/BepInEx/
else
    echo "✗ BepInEx directory NOT found"
fi
echo ""

echo "4. BepInEx Startup Scripts"
echo "--------------------------------------"
for script in start_server_bepinex.sh start_game_bepinex.sh; do
    if [ -f "/opt/valheim/${script}" ]; then
        echo "✓ ${script} exists"
        ls -lh "/opt/valheim/${script}"
    else
        echo "✗ ${script} NOT found"
    fi
done
echo ""

echo "5. Doorstop Files"
echo "--------------------------------------"
if [ -d /opt/valheim/doorstop_libs ]; then
    echo "✓ doorstop_libs directory exists"
    ls -la /opt/valheim/doorstop_libs/
else
    echo "✗ doorstop_libs NOT found"
fi

if [ -f /opt/valheim/doorstop_config.ini ]; then
    echo "✓ doorstop_config.ini exists"
else
    echo "✗ doorstop_config.ini NOT found"
fi
echo ""

echo "6. Persistent Storage (/userfiles/bepinex)"
echo "--------------------------------------"
if [ -d /userfiles/bepinex ]; then
    echo "✓ /userfiles/bepinex exists"
    echo ""
    echo "Plugins directory:"
    ls -la /userfiles/bepinex/plugins/ 2>/dev/null || echo "  (empty or doesn't exist)"
    echo ""
    echo "Patchers directory:"
    ls -la /userfiles/bepinex/patchers/ 2>/dev/null || echo "  (empty or doesn't exist)"
    echo ""
    echo "Config directory:"
    ls -la /userfiles/bepinex/config/ 2>/dev/null || echo "  (empty or doesn't exist)"
else
    echo "✗ /userfiles/bepinex does NOT exist"
fi
echo ""

echo "7. Symlink Status"
echo "--------------------------------------"
if [ -d /opt/valheim/BepInEx ]; then
    for dir in plugins patchers config; do
        target="/opt/valheim/BepInEx/${dir}"
        if [ -L "$target" ]; then
            echo "✓ ${dir} is a symlink"
            echo "  Target: $(readlink -f $target)"
        elif [ -d "$target" ]; then
            echo "✗ ${dir} is a DIRECTORY (should be symlink)"
        elif [ ! -e "$target" ]; then
            echo "✗ ${dir} does NOT exist"
        else
            echo "? ${dir} exists but is neither directory nor symlink"
        fi
    done
else
    echo "Cannot check symlinks - BepInEx not installed"
fi
echo ""

echo "8. BepInEx Installer Logs"
echo "--------------------------------------"
echo "Last 30 lines from bepinex-installer:"
docker logs valheim-server 2>&1 | grep -A 30 "BepInEx Installer Starting" | tail -30 || echo "No installer logs found"
echo ""

echo "9. Network Connectivity Test"
echo "--------------------------------------"
echo "Testing Thunderstore API access..."
if curl -s -f "https://thunderstore.io/api/v1/package/denikson/BepInExPack_Valheim/" > /dev/null 2>&1; then
    echo "✓ Can reach Thunderstore API"
else
    echo "✗ Cannot reach Thunderstore API"
    echo "  This might be a network issue"
fi
echo ""

echo "10. Process Status"
echo "--------------------------------------"
echo "BepInEx installer process:"
ps aux | grep bepinex-installer | grep -v grep || echo "  Not running"
echo ""
echo "Valheim server process:"
ps aux | grep valheim_server | grep -v grep || echo "  Not running"
echo ""

echo "=========================================="
echo "RECOMMENDATIONS"
echo "=========================================="

if [ "${MOD_LOADER}" != "BepInEx" ]; then
    echo "⚠ MOD_LOADER is not set to 'BepInEx'"
    echo "  Set MOD_LOADER=BepInEx in docker-compose.yml"
fi

if [ ! -d /opt/valheim/BepInEx ]; then
    echo "⚠ BepInEx is not installed"
    echo "  Check installer logs: docker compose logs bepinex-installer"
    echo "  Try rebuilding: docker compose down && docker compose up --build -d"
fi

if [ -d /opt/valheim/BepInEx ] && [ ! -L /opt/valheim/BepInEx/plugins ]; then
    echo "⚠ Symlinks not properly configured"
    echo "  Restart container: docker compose restart"
fi

echo ""