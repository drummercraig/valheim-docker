#!/bin/bash
set -e

# BepInEx installer for Valheim via Thunderstore API
# Handles installation and configuration of BepInEx mod loader

VALHEIM_DIR="/opt/valheim"
BEPINEX_ZIP="/tmp/bepinex.zip"
THUNDERSTORE_API="https://thunderstore.io/api/v1/package"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

get_latest_bepinex() {
    log "Fetching latest BepInEx version from Thunderstore..."
    
    # Get BepInEx package info from Thunderstore
    local package_data=$(curl -s -f "${THUNDERSTORE_API}/denikson/BepInExPack_Valheim/" 2>&1)
    
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to fetch package data from Thunderstore"
        log "Response: $package_data"
        return 1
    fi
    
    # Extract latest version download URL using multiple methods
    local download_url=$(echo "$package_data" | grep -oP '"download_url"\s*:\s*"\K[^"]+' | head -1)
    
    if [ -z "$download_url" ]; then
        # Try alternative parsing
        download_url=$(echo "$package_data" | sed -n 's/.*"download_url"[^"]*"\([^"]*\)".*/\1/p' | head -1)
    fi
    
    local version=$(echo "$package_data" | grep -oP '"version_number"\s*:\s*"\K[^"]+' | head -1)
    
    if [ -z "$version" ]; then
        version=$(echo "$package_data" | sed -n 's/.*"version_number"[^"]*"\([^"]*\)".*/\1/p' | head -1)
    fi
    
    if [ -z "$download_url" ]; then
        log "ERROR: Could not parse download URL from Thunderstore API response"
        log "API Response (first 500 chars): ${package_data:0:500}"
        return 1
    fi
    
    log "Found BepInEx version: ${version}"
    log "Download URL: ${download_url}"
    
    echo "$download_url"
}

install_bepinex() {
    log "=========================================="
    log "Installing BepInEx from Thunderstore"
    log "=========================================="
    
    # Get download URL
    local download_url=$(get_latest_bepinex)
    
    if [ -z "$download_url" ]; then
        log "ERROR: Failed to get download URL"
        return 1
    fi
    
    # Download BepInEx
    log "Downloading BepInEx..."
    if ! wget --progress=bar:force -O "$BEPINEX_ZIP" "$download_url" 2>&1; then
        log "ERROR: Failed to download BepInEx"
        return 1
    fi
    
    if [ ! -f "$BEPINEX_ZIP" ]; then
        log "ERROR: Download file not found: $BEPINEX_ZIP"
        return 1
    fi
    
    local file_size=$(stat -c%s "$BEPINEX_ZIP" 2>/dev/null || stat -f%z "$BEPINEX_ZIP" 2>/dev/null)
    log "Downloaded file size: ${file_size} bytes"
    
    if [ "$file_size" -lt 1000 ]; then
        log "ERROR: Downloaded file is too small, probably not valid"
        return 1
    fi
    
    # Extract to temporary directory first
    local temp_dir="/tmp/bepinex_extract"
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    
    log "Extracting BepInEx..."
    if ! unzip -o "$BEPINEX_ZIP" -d "$temp_dir" 2>&1; then
        log "ERROR: Failed to extract BepInEx zip file"
        return 1
    fi
    
    # Debug: Show extracted structure
    log "Extracted directory structure:"
    find "$temp_dir" -maxdepth 3 -type d | head -20
    
    # Thunderstore packages are nested - find the actual BepInEx files
    # Try multiple possible locations
    local bepinex_pack_dir=""
    
    # Method 1: Look for BepInExPack directory
    bepinex_pack_dir=$(find "$temp_dir" -type d -name "BepInExPack" | head -1)
    
    # Method 2: Look for directory containing BepInEx subdirectory
    if [ -z "$bepinex_pack_dir" ]; then
        local bepinex_subdir=$(find "$temp_dir" -type d -name "BepInEx" | head -1)
        if [ -n "$bepinex_subdir" ]; then
            bepinex_pack_dir=$(dirname "$bepinex_subdir")
        fi
    fi
    
    # Method 3: Just use temp_dir root if it has the right files
    if [ -z "$bepinex_pack_dir" ] && [ -d "$temp_dir/BepInEx" ]; then
        bepinex_pack_dir="$temp_dir"
    fi
    
    if [ -z "$bepinex_pack_dir" ]; then
        log "ERROR: Could not find BepInEx files in download"
        log "Directory contents:"
        ls -la "$temp_dir"
        return 1
    fi
    
    log "Found BepInEx files at: ${bepinex_pack_dir}"
    log "Contents:"
    ls -la "$bepinex_pack_dir"
    
    # Copy BepInEx files to Valheim directory
    log "Installing BepInEx to ${VALHEIM_DIR}..."
    
    # Copy BepInEx directory
    if [ -d "${bepinex_pack_dir}/BepInEx" ]; then
        log "Copying BepInEx directory..."
        cp -r "${bepinex_pack_dir}/BepInEx" "$VALHEIM_DIR/"
    else
        log "ERROR: BepInEx directory not found in ${bepinex_pack_dir}"
        return 1
    fi
    
    # Copy doorstop files
    if [ -d "${bepinex_pack_dir}/doorstop_libs" ]; then
        log "Copying doorstop_libs..."
        cp -r "${bepinex_pack_dir}/doorstop_libs" "$VALHEIM_DIR/"
    fi
    
    # Copy start scripts - try multiple names
    for script in start_game_bepinex.sh start_server_bepinex.sh; do
        if [ -f "${bepinex_pack_dir}/${script}" ]; then
            log "Copying ${script}..."
            cp "${bepinex_pack_dir}/${script}" "${VALHEIM_DIR}/"
            chmod +x "${VALHEIM_DIR}/${script}"
        fi
    done
    
    # Copy doorstop config
    if [ -f "${bepinex_pack_dir}/doorstop_config.ini" ]; then
        log "Copying doorstop_config.ini..."
        cp "${bepinex_pack_dir}/doorstop_config.ini" "${VALHEIM_DIR}/"
    fi
    
    # Set permissions for doorstop
    if [ -f "${VALHEIM_DIR}/doorstop_libs/libdoorstop_x64.so" ]; then
        chmod +x "${VALHEIM_DIR}/doorstop_libs/libdoorstop_x64.so"
        log "Set executable permission for libdoorstop_x64.so"
    fi
    
    # Clean up
    rm -rf "$temp_dir" "$BEPINEX_ZIP"
    
    log "BepInEx installation complete"
    log "Installed files:"
    ls -la "${VALHEIM_DIR}/BepInEx" 2>/dev/null || log "BepInEx directory not found!"
    
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
        log "Created plugins symlink"
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
        log "Created patchers symlink"
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
        log "Created config symlink"
    fi
    
    # Verify symlinks
    log "Verifying BepInEx symlinks:"
    ls -la "${BEPINEX_DIR}/" | grep -E "plugins|patchers|config" || log "No symlinks found!"
    
    log "Symlink targets:"
    log "  plugins:  $(readlink -f ${BEPINEX_DIR}/plugins 2>/dev/null || echo 'NOT A SYMLINK')"
    log "  patchers: $(readlink -f ${BEPINEX_DIR}/patchers 2>/dev/null || echo 'NOT A SYMLINK')"
    log "  config:   $(readlink -f ${BEPINEX_DIR}/config 2>/dev/null || echo 'NOT A SYMLINK')"
    
    log "Contents of persistent storage:"
    log "Plugins:"
    ls -la "${USERFILES_BEPINEX}/plugins/" 2>/dev/null || log "  (empty)"
    log "Patchers:"
    ls -la "${USERFILES_BEPINEX}/patchers/" 2>/dev/null || log "  (empty)"
    log "Config:"
    ls -la "${USERFILES_BEPINEX}/config/" 2>/dev/null || log "  (empty)"
    
    log "BepInEx persistence setup complete"
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
    fi
    if [ -L "${BEPINEX_DIR}/patchers" ]; then
        rm -f "${BEPINEX_DIR}/patchers"
    fi
    if [ -L "${BEPINEX_DIR}/config" ]; then
        rm -f "${BEPINEX_DIR}/config"
    fi
    
    # Remove BepInEx directory and files
    rm -rf "${BEPINEX_DIR}"
    rm -rf "${VALHEIM_DIR}/doorstop_libs"
    rm -f "${VALHEIM_DIR}/doorstop_config.ini"
    rm -f "${VALHEIM_DIR}/start_game_bepinex.sh"
    rm -f "${VALHEIM_DIR}/start_server_bepinex.sh"
    rm -f "${VALHEIM_DIR}/.doorstop_version"
    
    log "BepInEx removed"
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
        while [ ! -f /opt/valheim/valheim_server.x86_64 ]; do
            sleep 5
        done
        log "Valheim server detected"
        
        # Check if BepInEx is already installed
        if [ ! -d "${VALHEIM_DIR}/BepInEx" ]; then
            log "BepInEx not found, installing..."
            if install_bepinex; then
                log "BepInEx installation successful"
            else
                log "ERROR: BepInEx installation failed!"
                log "Server will start without mods"
            fi
        else
            log "BepInEx already installed"
        fi
        
        # Always setup symlinks (in case they were removed)
        if [ -d "${VALHEIM_DIR}/BepInEx" ]; then
            if setup_bepinex_symlinks; then
                log "BepInEx symlinks configured"
            else
                log "WARNING: Symlink setup failed"
            fi
        fi
        
        log "BepInEx is ready"
        ;;
    ValheimPlus)
        log "ValheimPlus support not yet implemented"
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

# Keep the process running
while true; do
    sleep 3600
done