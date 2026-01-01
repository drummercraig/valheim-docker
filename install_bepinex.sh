#!/bin/bash
# Install BepInEx

echo "======================================"
echo "BepInEx Installation"
echo "======================================"

BEPINEX_INSTALL_PATH="${VALHEIM_DIR}"
BEPINEX_DL_DIR="/tmp/bepinex"
mkdir -p "${BEPINEX_DL_DIR}"

# Fetch latest version from Thunderstore API
echo "Fetching BepInEx version info..."
API_RESPONSE=$(curl -sfSL -H "accept: application/json" "https://thunderstore.io/api/experimental/package/denikson/BepInExPack_Valheim/" 2>/dev/null)

if [ -z "$API_RESPONSE" ]; then
    echo "ERROR: Could not connect to Thunderstore API"
    echo "BepInEx installation skipped - server will start without mods"
    exit 0
fi

LATEST_VERSION=$(echo "$API_RESPONSE" | grep -o '"version_number":"[^"]*"' | head -1 | cut -d'"' -f4)
DOWNLOAD_URL=$(echo "$API_RESPONSE" | grep -o '"download_url":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$DOWNLOAD_URL" ] || [ -z "$LATEST_VERSION" ]; then
    echo "ERROR: Could not parse BepInEx version info"
    echo "BepInEx installation skipped - server will start without mods"
    exit 0
fi

# Check if update needed
NEEDS_INSTALL=false
INSTALLED_VERSION_FILE="${VALHEIM_DIR}/.bepinex_version"

if [ ! -f "${VALHEIM_DIR}/BepInEx/core/BepInEx.Preloader.dll" ]; then
    NEEDS_INSTALL=true
elif [ -f "$INSTALLED_VERSION_FILE" ]; then
    INSTALLED_VERSION=$(cat "$INSTALLED_VERSION_FILE")
    if [ "$INSTALLED_VERSION" != "$LATEST_VERSION" ]; then
        NEEDS_INSTALL=true
    fi
else
    NEEDS_INSTALL=true
fi

if [ "$NEEDS_INSTALL" = true ]; then
    echo "Installing BepInEx ${LATEST_VERSION}..."
    cd "${BEPINEX_DL_DIR}"
    
    if ! curl -sL -o "BepInEx.zip" "${DOWNLOAD_URL}"; then
        echo "ERROR: Failed to download BepInEx"
        echo "BepInEx installation skipped - server will start without mods"
        exit 0
    fi
    
    if ! unzip -q "BepInEx.zip" -d extracted; then
        echo "ERROR: Failed to extract BepInEx"
        echo "BepInEx installation skipped - server will start without mods"
        rm -rf "${BEPINEX_DL_DIR}"
        exit 0
    fi
    
    if [ -d "extracted/BepInExPack_Valheim" ]; then
        cp -rf extracted/BepInExPack_Valheim/* "${BEPINEX_INSTALL_PATH}/"
    else
        echo "ERROR: Unexpected BepInEx archive structure"
        echo "BepInEx installation skipped - server will start without mods"
        rm -rf "${BEPINEX_DL_DIR}"
        exit 0
    fi
    
    chmod +x "${BEPINEX_INSTALL_PATH}/start_server_bepinex.sh" 2>/dev/null || true
    find "${BEPINEX_INSTALL_PATH}/doorstop_libs" -type f -name "*.so" -exec chmod +x {} \; 2>/dev/null || true
    echo "$LATEST_VERSION" > "$INSTALLED_VERSION_FILE"
    rm -rf "${BEPINEX_DL_DIR}"
    
    echo "✓ BepInEx ${LATEST_VERSION} installed"
else
    echo "✓ BepInEx ${LATEST_VERSION} up to date"
fi

echo "======================================"
