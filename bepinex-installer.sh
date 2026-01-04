#!/bin/bash
set -e

# BepInEx installer for Valheim via Thunderstore API
# Handles installation and configuration of BepInEx mod loader

VALHEIM_DIR="/opt/valheim"
BEPINEX_ZIP="/tmp/bepinex.zip"
THUNDERSTORE_API="https://thunderstore.io/api/v1/package"

get_latest_bepinex() {
    echo "Fetching latest BepInEx version from Thunderstore..."
    
    # Get BepInEx package info from Thunderstore
    local package_data=$(curl -s "${THUNDERSTORE_API}/denikson/BepInExPack_Valheim/")
    
    # Extract latest version download URL
    local download_url=$(echo "$package_data" | grep -o '"download_url":"[^"]*"' | head -1 | cut -d'"' -f4)
    local version=$(echo "$package_data" | grep -o '"version_number":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$download_url" ]; then
        echo "ERROR: Could not fetch BepInEx download URL from Thunderstore"
        exit 1
    fi
    
    echo "Found BepInEx version: ${version}"
    echo "Download URL: ${download_url}"
    
    echo "$download_url"
}

install_bepinex() {
    echo "=========================================="
    echo "Installing BepInEx from Thunderstore"
    echo "=========================================="
    
    # Get download URL
    local download_url=$(get_latest_bepinex)
    
    # Download BepInEx
    echo "Downloading BepInEx..."
    wget -q --show-progress -O "$BEPINEX_ZIP" "$download_url"
    
    # Extract to temporary directory first
    local temp_dir="/tmp/bepinex_extract"
    mkdir -p "$temp_dir"
    echo "Extracting BepInEx..."
    unzip -o "$BEPINEX_ZIP" -d "$temp_dir"
    
    # Thunderstore packages are nested - find the actual BepInEx files
    # Structure is usually: BepInExPack_Valheim/BepInExPack/...
    local bepinex_pack_dir=$(find "$temp_dir" -type d -name "BepInExPack" | head -1)
    
    if [ -z "$bepinex_pack_dir" ]; then
        echo "ERROR: Could not find BepInExPack directory in download"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    echo "Found BepInEx files at: ${bepinex_pack_dir}"
    
    # Copy BepInEx files to Valheim directory
    echo "Installing BepInEx to ${VALHEIM_DIR}..."
    
    # Copy BepInEx directory
    if [ -d "${bepinex_pack_dir}/BepInEx" ]; then
        cp -r "${bepinex_pack_dir}/BepInEx" "$VALHEIM_DIR/"
    fi
    
    # Copy doorstop files
    if [ -d "${bepinex_pack_dir}/doorstop_libs" ]; then
        cp -r "${bepinex_pack_dir}/doorstop_libs" "$VALHEIM_DIR/"
    fi
    
    # Copy start script
    if [ -f "${bepinex_pack_dir}/start_game_bepinex.sh" ]; then
        cp "${bepinex_pack_dir}/start_game_bepinex.sh" "${VALHEIM_DIR}/"
        chmod +x "${VALHEIM_DIR}/start_game_bepinex.sh"
    fi
    
    # Copy start server script (this is what we'll use)
    if [ -f "${bepinex_pack_dir}/start_server_bepinex.sh" ]; then
        cp "${bepinex_pack_dir}/start_server_bepinex.sh" "${VALHEIM_DIR}/"
        chmod +x "${VALHEIM_DIR}/start_server_bepinex.sh"
    fi
    
    # Copy doorstop config
    if [ -f "${bepinex_pack_dir}/doorstop_config.ini" ]; then
        cp "${bepinex_pack_dir}/doorstop_config.ini" "${VALHEIM_DIR}/"
    fi
    
    # Set permissions for doorstop
    if [ -f "${VALHEIM_DIR}/doorstop_libs/libdoorstop_x64.so" ]; then
        chmod +x "${VALHEIM_DIR}/doorstop_libs/libdoorstop_x64.so"
    fi
    
    # Clean up
    rm -rf "$temp_dir" "$BEPINEX_ZIP"
    
    echo "BepInEx installation complete"
}

setup_bepinex_symlinks() {
    echo "=========================================="
    echo "Setting up BepInEx persistence"
    echo "=========================================="
    
    BEPINEX_DIR="${VALHEIM_DIR}/BepInEx"
    USERFILES_BEPINEX="/userfiles/bepinex"
    
    # Ensure userfiles directories exist
    mkdir -p "${USERFILES_BEPINEX}/plugins"
    mkdir -p "${USERFILES_BEPINEX}/patchers"
    mkdir -p "${USERFILES_BEPINEX}/config"
    
    # Handle plugins directory
    if [ -d "${BEPINEX_DIR}/plugins" ] && [ ! -L "${BEPINEX_DIR}/plugins" ]; then
        echo "Backing up existing plugins..."
        if [ "$(ls -A ${BEPINEX_DIR}/plugins 2>/dev/null)" ]; then
            cp -av "${BEPINEX_DIR}/plugins"/* "${USERFILES_BEPINEX}/plugins/" 2>/dev/null || true
        fi
        rm -rf "${BEPINEX_DIR}/plugins"
    fi
    
    # Handle patchers directory
    if [ -d "${BEPINEX_DIR}/patchers" ] && [ ! -L "${BEPINEX_DIR}/patchers" ]; then
        echo "Backing up existing patchers..."
        if [ "$(ls -A ${BEPINEX_DIR}/patchers 2>/dev/null)" ]; then
            cp -av "${BEPINEX_DIR}/patchers"/* "${USERFILES_BEPINEX}/patchers/" 2>/dev/null || true
        fi
        rm -rf "${BEPINEX_DIR}/patchers"
    fi
    
    # Handle config directory
    if [ -d "${BEPINEX_DIR}/config" ] && [ ! -L "${BEPINEX_DIR}/config" ]; then
        echo "Backing up existing config..."
        if [ "$(ls -A ${BEPINEX_DIR}/config 2>/dev/null)" ]; then
            cp -av "${BEPINEX_DIR}/config"/* "${USERFILES_BEPINEX}/config/" 2>/dev/null || true
        fi
        rm -rf "${BEPINEX_DIR}/config"
    fi
    
    # Create symlinks
    echo "Creating symlinks..."
    ln -sf "${USERFILES_BEPINEX}/plugins" "${BEPINEX_DIR}/plugins"
    ln -sf "${USERFILES_BEPINEX}/patchers" "${BEPINEX_DIR}/patchers"
    ln -sf "${USERFILES_BEPINEX}/config" "${BEPINEX_DIR}/config"
    
    # Verify symlinks
    echo "Verifying BepInEx symlinks:"
    ls -la "${BEPINEX_DIR}/" | grep -E "plugins|patchers|config"
    
    echo "Symlink targets:"
    echo "  plugins:  $(readlink -f ${BEPINEX_DIR}/plugins)"
    echo "  patchers: $(readlink -f ${BEPINEX_DIR}/patchers)"
    echo "  config:   $(readlink -f ${BEPINEX_DIR}/config)"
    
    echo "Contents of persistent storage:"
    echo "Plugins:"
    ls -la "${USERFILES_BEPINEX}/plugins/" 2>/dev/null || echo "  (empty)"
    echo "Patchers:"
    ls -la "${USERFILES_BEPINEX}/patchers/" 2>/dev/null || echo "  (empty)"
    echo "Config:"
    ls -la "${USERFILES_BEPINEX}/config/" 2>/dev/null || echo "  (empty)"
    
    echo "BepInEx persistence setup complete"
}

remove_bepinex() {
    echo "=========================================="
    echo "Removing BepInEx installation"
    echo "=========================================="
    
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
    
    echo "BepInEx removed"
}

# Main logic
case "${MOD_LOADER:-Vanilla}" in
    BepInEx)
        # Wait for Valheim server to be installed
        while [ ! -f /opt/valheim/valheim_server.x86_64 ]; do
            echo "Waiting for Valheim server installation..."
            sleep 5
        done
        
        # Check if BepInEx is already installed
        if [ ! -d "${VALHEIM_DIR}/BepInEx" ]; then
            install_bepinex
        else
            echo "BepInEx already installed"
        fi
        
        # Always setup symlinks (in case they were removed)
        setup_bepinex_symlinks
        
        echo "BepInEx is ready"
        ;;
    ValheimPlus)
        echo "ValheimPlus support not yet implemented"
        # TODO: Implement ValheimPlus installation
        ;;
    Vanilla)
        echo "Running vanilla Valheim server (no mods)"
        # Check if BepInEx exists and remove it
        if [ -d "${VALHEIM_DIR}/BepInEx" ]; then
            remove_bepinex
        fi
        ;;
    *)
        echo "WARNING: Unknown MOD_LOADER value: ${MOD_LOADER}"
        echo "Valid values: BepInEx, ValheimPlus, Vanilla"
        echo "Defaulting to Vanilla"
        ;;
esac

# Keep the process running
while true; do
    sleep 3600
done