#!/bin/bash
# BepInEx installer for Valheim via Thunderstore API
# Handles installation and configuration of BepInEx mod loader

# Don't exit on error - we want to show clear messages
set +e

VALHEIM_DIR="/opt/valheim"
BEPINEX_DL_DIR="/tmp/bepinex"
INSTALLED_VERSION_FILE="${VALHEIM_DIR}/.bepinex_version"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

install_bepinex() {
    log "======================================"
    log "BepInEx Installation"
    log "======================================"
    
    mkdir -p "${BEPINEX_DL_DIR}"
    
    # Fetch latest version from Thunderstore API
    log "Fetching BepInEx version info from Thunderstore..."
    API_RESPONSE=$(curl -sfSL -H "accept: application/json" "https://thunderstore.io/api/experimental/package/denikson/BepInExPack_Valheim/" 2>/dev/null)
    
    if [ -z "$API_RESPONSE" ]; then
        log "ERROR: Could not connect to Thunderstore API"
        log "BepInEx installation skipped - server will start without mods"
        log "Check network connectivity: docker exec valheim-server curl -I https://thunderstore.io"
        return 1
    fi
    
    LATEST_VERSION=$(echo "$API_RESPONSE" | grep -o '"version_number":"[^"]*"' | head -1 | cut -d'"' -f4)
    DOWNLOAD_URL=$(echo "$API_RESPONSE" | grep -o '"download_url":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$DOWNLOAD_URL" ] || [ -z "$LATEST_VERSION" ]; then
        log "ERROR: Could not parse BepInEx version info from API response"
        log "API Response preview: ${API_RESPONSE:0:200}"
        log "BepInEx installation skipped - server will start without mods"
        return 1
    fi
    
    log "Latest BepInEx version: ${LATEST_VERSION}"
    log "Download URL: ${DOWNLOAD_URL}"
    
    # Check if update needed
    NEEDS_INSTALL=false
    if [ ! -f "${VALHEIM_DIR}/BepInEx/core/BepInEx.Preloader.dll" ]; then
        log "BepInEx not found, installing..."
        NEEDS_INSTALL=true
    elif [ -f "$INSTALLED_VERSION_FILE" ]; then
        INSTALLED_VERSION=$(cat "$INSTALLED_VERSION_FILE")
        if [ "$INSTALLED_VERSION" != "$LATEST_VERSION" ]; then
            log "BepInEx update available: ${INSTALLED_VERSION} -> ${LATEST_VERSION}"
            NEEDS_INSTALL=true
        else
            log "BepInEx ${LATEST_VERSION} already installed"
        fi
    else
        log "Version file missing, reinstalling..."
        NEEDS_INSTALL=true
    fi
    
    if [ "$NEEDS_INSTALL" = true ]; then
        log "Installing BepInEx ${LATEST_VERSION}..."
        cd "${BEPINEX_DL_DIR}"
        
        if ! curl -sL -o "BepInEx.zip" "${DOWNLOAD_URL}"; then
            log "ERROR: Failed to download BepInEx from ${DOWNLOAD_URL}"
            log "BepInEx installation skipped - server will start without mods"
            rm -rf "${BEPINEX_DL_DIR}"
            return 1
        fi
        
        log "Download complete, extracting..."
        if ! unzip -q "BepInEx.zip" -d extracted; then
            log "ERROR: Failed to extract BepInEx archive"
            log "BepInEx installation skipped - server will start without mods"
            rm -rf "${BEPINEX_DL_DIR}"
            return 1
        fi
        
        log "Extraction complete, checking structure..."
        log "Extracted contents:"
        ls -la extracted/
        
        # Find the BepInEx pack directory
        BEPINEX_SOURCE=""
        if [ -d "extracted/BepInExPack_Valheim" ]; then
            BEPINEX_SOURCE="extracted/BepInExPack_Valheim"
            log "Found BepInExPack_Valheim directory"
        elif [ -d "extracted/BepInExPack" ]; then
            BEPINEX_SOURCE="extracted/BepInExPack"
            log "Found BepInExPack directory"
        else
            # Search for any directory containing BepInEx
            BEPINEX_SOURCE=$(find extracted -type d -name "*BepInEx*" | head -1)
            if [ -n "$BEPINEX_SOURCE" ]; then
                log "Found BepInEx directory at: ${BEPINEX_SOURCE}"
            fi
        fi
        
        if [ -z "$BEPINEX_SOURCE" ] || [ ! -d "$BEPINEX_SOURCE" ]; then
            log "ERROR: Could not find BepInEx files in archive"
            log "Archive structure:"
            find extracted -maxdepth 2 -type d
            log "BepInEx installation skipped - server will start without mods"
            rm -rf "${BEPINEX_DL_DIR}"
            return 1
        fi
        
        log "Copying BepInEx files from ${BEPINEX_SOURCE} to ${BEPINEX_INSTALL_PATH}..."
        log "Source directory contents:"
        ls -la "${BEPINEX_SOURCE}/"
        
        cp -rf "${BEPINEX_SOURCE}"/* "${BEPINEX_INSTALL_PATH}/"
        
        # Set executable permissions
        log "Setting permissions..."
        chmod +x "${BEPINEX_INSTALL_PATH}/start_server_bepinex.sh" 2>/dev/null || true
        chmod +x "${BEPINEX_INSTALL_PATH}/start_game_bepinex.sh" 2>/dev/null || true
        find "${BEPINEX_INSTALL_PATH}/doorstop_libs" -type f -name "*.so" -exec chmod +x {} \; 2>/dev/null || true
        
        # Save installed version
        echo "$LATEST_VERSION" > "$INSTALLED_VERSION_FILE"
        
        # Cleanup
        rm -rf "${BEPINEX_DL_DIR}"
        
        log "✓ BepInEx ${LATEST_VERSION} installed successfully"
        log "Installed files:"
        ls -la "${VALHEIM_DIR}/BepInEx/" 2>/dev/null || log "  WARNING: BepInEx directory not found!"
    else
        log "✓ BepInEx ${LATEST_VERSION} up to date"
    fi
    
    log "======================================"
    return 0
}

setup_bepinex_symlinks() {
    log "=========================================="
    log "Setting up BepInEx persistence"
    log "=========================================="
    
    BEPINEX_DIR="${VALHEIM_DIR}/BepInEx"
    USERFILES_BEPINEX="/userfiles/bepinex"
    
    if [ ! -d "$BEPINEX_DIR" ]; then
        log "ERROR: BepInEx directory not found at ${BEPINEX_DIR}"
        log "Cannot setup symlinks without BepInEx installed"
        return 1
    fi
    
    # Ensure userfiles directories exist
    log "Creating persistent storage directories..."
    mkdir -p "${USERFILES_BEPINEX}/plugins"
    mkdir -p "${USERFILES_BEPINEX}/patchers"
    mkdir -p "${USERFILES_BEPINEX}/config"
    
    # Handle plugins directory
    log "Setting up plugins directory..."
    if [ -d "${BEPINEX_DIR}/plugins" ] && [ ! -L "${BEPINEX_DIR}/plugins" ]; then
        log "Backing up existing plugins..."
        if [ "$(ls -A ${BEPINEX_DIR}/plugins 2>/dev/null)" ]; then
            cp -av "${BEPINEX_DIR}/plugins"/* "${USERFILES_BEPINEX}/plugins/" 2>/dev/null || true
        fi
        rm -rf "${BEPINEX_DIR}/plugins"
    elif [ -L "${BEPINEX_DIR}/plugins" ]; then
        log "Plugins symlink already exists"
    fi
    
    if [ ! -e "${BEPINEX_DIR}/plugins" ]; then
        ln -sf "${USERFILES_BEPINEX}/plugins" "${BEPINEX_DIR}/plugins"
        log "✓ Created plugins symlink"
    fi
    
    # Handle patchers directory
    log "Setting up patchers directory..."
    if [ -d "${BEPINEX_DIR}/patchers" ] && [ ! -L "${BEPINEX_DIR}/patchers" ]; then
        log "Backing up existing patchers..."
        if [ "$(ls -A ${BEPINEX_DIR}/patchers 2>/dev/null)" ]; then
            cp -av "${BEPINEX_DIR}/patchers"/* "${USERFILES_BEPINEX}/patchers/" 2>/dev/null || true
        fi
        rm -rf "${BEPINEX_DIR}/patchers"
    elif [ -L "${BEPINEX_DIR}/patchers" ]; then
        log "Patchers symlink already exists"
    fi
    
    if [ ! -e "${BEPINEX_DIR}/patchers" ]; then
        ln -sf "${USERFILES_BEPINEX}/patchers" "${BEPINEX_DIR}/patchers"
        log "✓ Created patchers symlink"
    fi
    
    # Handle config directory
    log "Setting up config directory..."
    if [ -d "${BEPINEX_DIR}/config" ] && [ ! -L "${BEPINEX_DIR}/config" ]; then
        log "Backing up existing config..."
        if [ "$(ls -A ${BEPINEX_DIR}/config 2>/dev/null)" ]; then
            cp -av "${BEPINEX_DIR}/config"/* "${USERFILES_BEPINEX}/config/" 2>/dev/null || true
        fi
        rm -rf "${BEPINEX_DIR}/config"
    elif [ -L "${BEPINEX_DIR}/config" ]; then
        log "Config symlink already exists"
    fi
    
    if [ ! -e "${BEPINEX_DIR}/config" ]; then
        ln -sf "${USERFILES_BEPINEX}/config" "${BEPINEX_DIR}/config"
        log "✓ Created config symlink"
    fi
    
    # Verify symlinks
    log "Verifying BepInEx symlinks:"
    ls -la "${BEPINEX_DIR}/" | grep -E "plugins|patchers|config" || log "WARNING: No symlinks found!"
    
    log "Symlink targets:"
    log "  plugins:  $(readlink -f ${BEPINEX_DIR}/plugins 2>/dev/null || echo 'NOT A SYMLINK')"
    log "  patchers: $(readlink -f ${BEPINEX_DIR}/patchers 2>/dev/null || echo 'NOT A SYMLINK')"
    log "  config:   $(readlink -f ${BEPINEX_DIR}/config 2>/dev/null || echo 'NOT A SYMLINK')"
    
    log "Persistent storage verification:"
    log "Plugins ($(ls -A ${USERFILES_BEPINEX}/plugins/ 2>/dev/null | wc -l) files)"
    log "Patchers ($(ls -A ${USERFILES_BEPINEX}/patchers/ 2>/dev/null | wc -l) files)"
    log "Config ($(ls -A ${USERFILES_BEPINEX}/config/ 2>/dev/null | wc -l) files)"
    
    log "✓ BepInEx persistence setup complete"
    log "=========================================="
    return 0
}

remove_bepinex() {
    log "=========================================="
    log "Removing BepInEx installation"
    log "=========================================="
    
    BEPINEX_DIR="${VALHEIM_DIR}/BepInEx"
    
    # Remove symlinks
    if [ -L "${BEPINEX_DIR}/plugins" ]; then
        rm -f "${BEPINEX_DIR}/plugins"
        log "Removed plugins symlink"
    fi
    if [ -L "${BEPINEX_DIR}/patchers" ]; then
        rm -f "${BEPINEX_DIR}/patchers"
        log "Removed patchers symlink"
    fi
    if [ -L "${BEPINEX_DIR}/config" ]; then
        rm -f "${BEPINEX_DIR}/config"
        log "Removed config symlink"
    fi
    
    # Remove BepInEx directory and files
    rm -rf "${BEPINEX_DIR}"
    rm -rf "${VALHEIM_DIR}/doorstop_libs"
    rm -f "${VALHEIM_DIR}/doorstop_config.ini"
    rm -f "${VALHEIM_DIR}/start_game_bepinex.sh"
    rm -f "${VALHEIM_DIR}/start_server_bepinex.sh"
    rm -f "${VALHEIM_DIR}/.doorstop_version"
    rm -f "${INSTALLED_VERSION_FILE}"
    
    log "✓ BepInEx removed"
    log "Note: Mod files in /userfiles/bepinex/ are preserved"
    log "=========================================="
}

# Main logic
log "=========================================="
log "BepInEx Installer Starting"
log "MOD_LOADER: ${MOD_LOADER:-Vanilla}"
log "=========================================="

case "${MOD_LOADER:-Vanilla}" in
    BepInEx)
        log "BepInEx mode enabled"
        
        # Wait for Valheim server to be installed
        log "Waiting for Valheim server installation..."
        WAIT_COUNT=0
        while [ ! -f /opt/valheim/valheim_server.x86_64 ]; do
            sleep 5
            WAIT_COUNT=$((WAIT_COUNT + 5))
            if [ $WAIT_COUNT -ge 300 ]; then
                log "ERROR: Timeout waiting for Valheim server installation"
                exit 1
            fi
        done
        log "✓ Valheim server detected"
        
        # Install or update BepInEx
        if install_bepinex; then
            log "BepInEx installation completed successfully"
            
            # Setup symlinks for persistence
            if setup_bepinex_symlinks; then
                log "✓ BepInEx fully configured and ready"
            else
                log "WARNING: Symlink setup encountered issues"
            fi
        else
            log "WARNING: BepInEx installation failed"
            log "Server will start in vanilla mode"
        fi
        ;;
    ValheimPlus)
        log "ValheimPlus support not yet implemented"
        log "Server will start in vanilla mode"
        # TODO: Implement ValheimPlus installation
        ;;
    Vanilla)
        log "Running vanilla Valheim server (no mods)"
        # Check if BepInEx exists and remove it
        if [ -d "${VALHEIM_DIR}/BepInEx" ]; then
            remove_bepinex
        fi
        ;;
    *)
        log "WARNING: Unknown MOD_LOADER value: ${MOD_LOADER}"
        log "Valid values: BepInEx, ValheimPlus, Vanilla"
        log "Defaulting to Vanilla"
        ;;
esac

log "BepInEx installer entering monitoring mode"
log "This process will check for updates periodically"

# Keep the process running and check for updates every hour
while true; do
    sleep 3600
    
    # Re-check if BepInEx needs updating (only if MOD_LOADER is still BepInEx)
    if [ "${MOD_LOADER:-Vanilla}" = "BepInEx" ] && [ -f "${VALHEIM_DIR}/valheim_server.x86_64" ]; then
        log "Checking for BepInEx updates..."
        install_bepinex
    fi
done