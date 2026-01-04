#!/bin/bash
# Install BepInEx
# Don't exit on error for this script - we want to show clear messages
set +e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

if [ "${MOD_LOADER:-Vanilla}" != "BepInEx" ]; then
    log "BepInEx: Disabled (MOD_LOADER=${MOD_LOADER:-Vanilla})"
    # Keep process running
    while true; do sleep 3600; done
fi

log "======================================"
log "BepInEx Installation"
log "======================================"

# Wait for Valheim to be installed
log "Waiting for Valheim server installation..."
while [ ! -f /opt/valheim/valheim_server.x86_64 ]; do
    sleep 5
done
log "✓ Valheim server found"

VALHEIM_DIR="/opt/valheim"
BEPINEX_INSTALL_PATH="${VALHEIM_DIR}"
BEPINEX_DL_DIR="/tmp/bepinex"
INSTALLED_VERSION_FILE="${VALHEIM_DIR}/.bepinex_version"

mkdir -p "${BEPINEX_DL_DIR}"

# Fetch latest version from Thunderstore API
log "Fetching BepInEx version info..."
API_RESPONSE=$(curl -sfSL -H "accept: application/json" "https://thunderstore.io/api/experimental/package/denikson/BepInExPack_Valheim/" 2>/dev/null)

if [ -z "$API_RESPONSE" ]; then
    log "ERROR: Could not connect to Thunderstore API"
    log "BepInEx installation skipped - server will start without mods"
    log "Check network: docker exec valheim-server curl -I https://thunderstore.io"
    # Keep process running
    while true; do sleep 3600; done
fi

LATEST_VERSION=$(echo "$API_RESPONSE" | grep -o '"version_number":"[^"]*"' | head -1 | cut -d'"' -f4)
DOWNLOAD_URL=$(echo "$API_RESPONSE" | grep -o '"download_url":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$DOWNLOAD_URL" ] || [ -z "$LATEST_VERSION" ]; then
    log "ERROR: Could not parse BepInEx version info"
    log "BepInEx installation skipped - server will start without mods"
    # Keep process running
    while true; do sleep 3600; done
fi

log "Latest version: ${LATEST_VERSION}"
log "Download URL: ${DOWNLOAD_URL}"

# Check if update needed
NEEDS_INSTALL=false
if [ ! -f "${VALHEIM_DIR}/BepInEx/core/BepInEx.Preloader.dll" ]; then
    log "BepInEx not found, installing..."
    NEEDS_INSTALL=true
elif [ -f "$INSTALLED_VERSION_FILE" ]; then
    INSTALLED_VERSION=$(cat "$INSTALLED_VERSION_FILE")
    if [ "$INSTALLED_VERSION" != "$LATEST_VERSION" ]; then
        log "Update available: ${INSTALLED_VERSION} -> ${LATEST_VERSION}"
        NEEDS_INSTALL=true
    else
        log "✓ BepInEx ${LATEST_VERSION} up to date"
    fi
else
    log "Version file missing, reinstalling..."
    NEEDS_INSTALL=true
fi

if [ "$NEEDS_INSTALL" = true ]; then
    log "Installing BepInEx ${LATEST_VERSION}..."
    cd "${BEPINEX_DL_DIR}"
    
    if ! curl -sL -o "BepInEx.zip" "${DOWNLOAD_URL}"; then
        log "ERROR: Failed to download BepInEx"
        log "BepInEx installation skipped - server will start without mods"
        rm -rf "${BEPINEX_DL_DIR}"
        # Keep process running
        while true; do sleep 3600; done
    fi
    
    log "Download complete ($(stat -c%s BepInEx.zip 2>/dev/null || stat -f%z BepInEx.zip 2>/dev/null) bytes)"
    
    if ! unzip -q "BepInEx.zip" -d extracted; then
        log "ERROR: Failed to extract BepInEx"
        log "BepInEx installation skipped - server will start without mods"
        rm -rf "${BEPINEX_DL_DIR}"
        # Keep process running
        while true; do sleep 3600; done
    fi
    
    log "Extraction complete, finding BepInEx files..."
    
    # Find BepInEx directory
    BEPINEX_SOURCE=""
    if [ -d "extracted/BepInExPack_Valheim" ]; then
        BEPINEX_SOURCE="extracted/BepInExPack_Valheim"
    elif [ -d "extracted/BepInExPack" ]; then
        BEPINEX_SOURCE="extracted/BepInExPack"
    else
        BEPINEX_SOURCE=$(find extracted -type d -name "*BepInEx*" | head -1)
    fi
    
    if [ -z "$BEPINEX_SOURCE" ] || [ ! -d "$BEPINEX_SOURCE" ]; then
        log "ERROR: Unexpected BepInEx archive structure"
        log "Contents:"
        find extracted -maxdepth 2 -type d
        log "BepInEx installation skipped - server will start without mods"
        rm -rf "${BEPINEX_DL_DIR}"
        # Keep process running
        while true; do sleep 3600; done
    fi
    
    log "Found BepInEx at: ${BEPINEX_SOURCE}"
    log "Installing to ${BEPINEX_INSTALL_PATH}..."
    
    # Remove any existing symlinks in BepInEx directory before copying
    rm -f "${BEPINEX_INSTALL_PATH}/BepInEx/plugins"
    rm -f "${BEPINEX_INSTALL_PATH}/BepInEx/patchers"
    rm -f "${BEPINEX_INSTALL_PATH}/BepInEx/config"
    
    cp -rf "${BEPINEX_SOURCE}"/* "${BEPINEX_INSTALL_PATH}/"
    
    chmod +x "${BEPINEX_INSTALL_PATH}/start_server_bepinex.sh" 2>/dev/null || true
    find "${BEPINEX_INSTALL_PATH}/doorstop_libs" -type f -name "*.so" -exec chmod +x {} \; 2>/dev/null || true
    echo "$LATEST_VERSION" > "$INSTALLED_VERSION_FILE"
    rm -rf "${BEPINEX_DL_DIR}"
    
    log "✓ BepInEx ${LATEST_VERSION} installed"
fi

# Setup symlinks for persistence
log "======================================"
log "Setting up BepInEx persistence"
log "======================================"

BEPINEX_DIR="${VALHEIM_DIR}/BepInEx"
USERFILES_BEPINEX="/userfiles/bepinex"

if [ ! -d "$BEPINEX_DIR" ]; then
    log "ERROR: BepInEx directory not found at ${BEPINEX_DIR}"
    log "Cannot setup symlinks"
    # Keep process running
    while true; do sleep 3600; done
fi

# Ensure userfiles directories exist
log "Creating persistent storage directories..."
mkdir -p "${USERFILES_BEPINEX}"
# Don't create subdirectories yet - they might be symlinks

# Remove any existing symlinks first
rm -f "${USERFILES_BEPINEX}/plugins"
rm -f "${USERFILES_BEPINEX}/patchers"  
rm -f "${USERFILES_BEPINEX}/config"

# Now create the actual directories
mkdir -p "${USERFILES_BEPINEX}/plugins"
mkdir -p "${USERFILES_BEPINEX}/patchers"
mkdir -p "${USERFILES_BEPINEX}/config"

# Function to setup a symlink
setup_symlink() {
    local dir_name="$1"
    local source_dir="${BEPINEX_DIR}/${dir_name}"
    local target_dir="${USERFILES_BEPINEX}/${dir_name}"
    
    log "Setting up ${dir_name}..."
    
    if [ -d "$source_dir" ] && [ ! -L "$source_dir" ]; then
        log "  Backing up existing ${dir_name}..."
        if [ "$(ls -A ${source_dir} 2>/dev/null)" ]; then
            cp -a "${source_dir}"/* "${target_dir}/" 2>/dev/null || true
        fi
        rm -rf "$source_dir"
    fi
    
    if [ ! -e "$source_dir" ]; then
        ln -sf "$target_dir" "$source_dir"
        log "  ✓ Created ${dir_name} symlink"
    else
        log "  ✓ ${dir_name} symlink exists"
    fi
}

setup_symlink "plugins"
setup_symlink "patchers"
setup_symlink "config"

log "Verifying symlinks..."
ls -la "${BEPINEX_DIR}/" | grep -E "plugins|patchers|config"

log "✓ BepInEx persistence configured"
log "======================================"

# Keep the process running and check for updates periodically
log "BepInEx installer entering monitoring mode"
while true; do
    sleep 3600
    
    # Check for updates every hour
    if [ "${MOD_LOADER:-Vanilla}" = "BepInEx" ]; then
        log "Checking for BepInEx updates..."
        # Re-run installation logic (will skip if up to date)
        exec "$0"
    fi
done