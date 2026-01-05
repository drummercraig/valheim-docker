#!/bin/bash
# =============================================================================
# Valheim Thunderstore Mod Installer
# =============================================================================
# This script reads modlinks.txt from the current directory and installs
# each mod from Thunderstore into the appropriate BepInEx directories.
#
# Usage: ./install-mods.sh
# 
# The script can run on the host (with container running) or inside container.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1"
}

# Determine if we're running on host or in container
if [ -f "/.dockerenv" ]; then
    # Inside container
    RUNNING_IN_CONTAINER=true
    BEPINEX_BASE="/userfiles/bepinex"
    MODLINKS_FILE="/host/modlinks.txt"
else
    # On host
    RUNNING_IN_CONTAINER=false
    BEPINEX_BASE="./userfiles/bepinex"
    MODLINKS_FILE="./modlinks.txt"
fi

print_info "Thunderstore Mod Installer"
echo ""

# Check if modlinks.txt exists
if [ ! -f "$MODLINKS_FILE" ]; then
    print_error "modlinks.txt not found!"
    echo ""
    echo "Please create a modlinks.txt file in the current directory with one mod URL per line."
    echo ""
    echo "Example modlinks.txt content:"
    echo "  https://thunderstore.io/package/download/JereKuusela/Server_devcommands/1.102.0/"
    echo "  https://thunderstore.io/package/download/ValheimModding/Jotunn/2.20.2/"
    echo ""
    exit 1
fi

# Check if wget or curl is available
if command -v wget &> /dev/null; then
    DOWNLOAD_CMD="wget"
    print_info "Using wget for downloads"
elif command -v curl &> /dev/null; then
    DOWNLOAD_CMD="curl"
    print_info "Using curl for downloads"
else
    print_error "Neither wget nor curl found! Please install one of them."
    exit 1
fi

# Check if unzip is available
if ! command -v unzip &> /dev/null; then
    print_error "unzip not found! Please install unzip."
    exit 1
fi

# Create BepInEx directories if they don't exist
print_info "Ensuring BepInEx directories exist..."
mkdir -p "$BEPINEX_BASE/plugins"
mkdir -p "$BEPINEX_BASE/patchers"
mkdir -p "$BEPINEX_BASE/config"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
print_info "Created temporary directory: $TEMP_DIR"

# Cleanup function
cleanup() {
    print_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Counter for installed mods
TOTAL_MODS=0
SUCCESSFUL_MODS=0
FAILED_MODS=0

echo ""
print_info "Reading modlinks.txt..."
echo ""

# Process each line in modlinks.txt
while IFS= read -r MOD_URL || [ -n "$MOD_URL" ]; do
    # Skip empty lines and comments
    if [[ -z "$MOD_URL" ]] || [[ "$MOD_URL" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Trim whitespace
    MOD_URL=$(echo "$MOD_URL" | xargs)
    
    TOTAL_MODS=$((TOTAL_MODS + 1))
    
    echo "=========================================="
    print_info "Processing mod #$TOTAL_MODS"
    echo "URL: $MOD_URL"
    echo ""
    
    # Extract mod name from URL for better logging
    MOD_NAME=$(echo "$MOD_URL" | grep -oP '(?<=package/download/)[^/]+/[^/]+/[^/]+' || echo "unknown")
    print_info "Mod identifier: $MOD_NAME"
    
    # Create extraction directory for this mod
    EXTRACT_DIR="$TEMP_DIR/mod_$TOTAL_MODS"
    mkdir -p "$EXTRACT_DIR"
    
    # Download the mod
    ZIP_FILE="$TEMP_DIR/mod_$TOTAL_MODS.zip"
    
    print_info "Downloading mod..."
    
    if [ "$DOWNLOAD_CMD" = "wget" ]; then
        if wget -q --show-progress -O "$ZIP_FILE" "$MOD_URL"; then
            print_success "Download completed"
        else
            print_error "Failed to download mod"
            FAILED_MODS=$((FAILED_MODS + 1))
            rm -rf "$EXTRACT_DIR" "$ZIP_FILE"
            echo ""
            continue
        fi
    else
        # Using curl
        if curl -L -o "$ZIP_FILE" "$MOD_URL" --progress-bar; then
            print_success "Download completed"
        else
            print_error "Failed to download mod"
            FAILED_MODS=$((FAILED_MODS + 1))
            rm -rf "$EXTRACT_DIR" "$ZIP_FILE"
            echo ""
            continue
        fi
    fi
    
    # Check if downloaded file is actually a zip
    if ! file "$ZIP_FILE" | grep -q "Zip archive"; then
        print_error "Downloaded file is not a valid ZIP archive"
        FAILED_MODS=$((FAILED_MODS + 1))
        rm -rf "$EXTRACT_DIR" "$ZIP_FILE"
        echo ""
        continue
    fi
    
    # Extract the mod
    print_info "Extracting mod..."
    if unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"; then
        print_success "Extraction completed"
    else
        print_error "Failed to extract mod"
        FAILED_MODS=$((FAILED_MODS + 1))
        rm -rf "$EXTRACT_DIR" "$ZIP_FILE"
        echo ""
        continue
    fi
    
    # Check for folder structure
    print_info "Analyzing mod structure..."
    
    HAS_PLUGINS_FOLDER=false
    HAS_PATCHERS_FOLDER=false
    HAS_CONFIG_FOLDER=false
    HAS_SUBFOLDERS=false
    
    # Check for specific BepInEx folders (case-insensitive)
    if find "$EXTRACT_DIR" -type d -iname "plugins" | grep -q .; then
        HAS_PLUGINS_FOLDER=true
        HAS_SUBFOLDERS=true
        print_info "Found 'plugins' folder"
    fi
    
    if find "$EXTRACT_DIR" -type d -iname "patchers" | grep -q .; then
        HAS_PATCHERS_FOLDER=true
        HAS_SUBFOLDERS=true
        print_info "Found 'patchers' folder"
    fi
    
    if find "$EXTRACT_DIR" -type d -iname "config" | grep -q .; then
        HAS_CONFIG_FOLDER=true
        HAS_SUBFOLDERS=true
        print_info "Found 'config' folder"
    fi
    
    # If no BepInEx folders found, check if there are any other subfolders
    if [ "$HAS_SUBFOLDERS" = false ]; then
        if find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | grep -q .; then
            # Check if subfolders contain BepInEx folders
            for SUBFOLDER in "$EXTRACT_DIR"/*/; do
                if [ -d "$SUBFOLDER/plugins" ] || [ -d "$SUBFOLDER/patchers" ] || [ -d "$SUBFOLDER/config" ]; then
                    print_info "Found BepInEx structure in subfolder: $(basename "$SUBFOLDER")"
                    # Move contents up one level
                    mv "$SUBFOLDER"/* "$EXTRACT_DIR/" 2>/dev/null || true
                    HAS_SUBFOLDERS=true
                    
                    # Re-check for folders
                    [ -d "$EXTRACT_DIR/plugins" ] && HAS_PLUGINS_FOLDER=true
                    [ -d "$EXTRACT_DIR/patchers" ] && HAS_PATCHERS_FOLDER=true
                    [ -d "$EXTRACT_DIR/config" ] && HAS_CONFIG_FOLDER=true
                    break
                fi
            done
        fi
    fi
    
    # Install files based on structure
    print_info "Installing mod files..."
    
    if [ "$HAS_PLUGINS_FOLDER" = true ]; then
        PLUGINS_DIR=$(find "$EXTRACT_DIR" -type d -iname "plugins" | head -n 1)
        if [ -n "$PLUGINS_DIR" ]; then
            FILE_COUNT=$(find "$PLUGINS_DIR" -type f | wc -l)
            if [ "$FILE_COUNT" -gt 0 ]; then
                print_info "Copying $FILE_COUNT file(s) from plugins folder..."
                cp -r "$PLUGINS_DIR"/* "$BEPINEX_BASE/plugins/" 2>/dev/null || true
                print_success "Plugins installed"
            fi
        fi
    fi
    
    if [ "$HAS_PATCHERS_FOLDER" = true ]; then
        PATCHERS_DIR=$(find "$EXTRACT_DIR" -type d -iname "patchers" | head -n 1)
        if [ -n "$PATCHERS_DIR" ]; then
            FILE_COUNT=$(find "$PATCHERS_DIR" -type f | wc -l)
            if [ "$FILE_COUNT" -gt 0 ]; then
                print_info "Copying $FILE_COUNT file(s) from patchers folder..."
                cp -r "$PATCHERS_DIR"/* "$BEPINEX_BASE/patchers/" 2>/dev/null || true
                print_success "Patchers installed"
            fi
        fi
    fi
    
    if [ "$HAS_CONFIG_FOLDER" = true ]; then
        CONFIG_DIR=$(find "$EXTRACT_DIR" -type d -iname "config" | head -n 1)
        if [ -n "$CONFIG_DIR" ]; then
            FILE_COUNT=$(find "$CONFIG_DIR" -type f | wc -l)
            if [ "$FILE_COUNT" -gt 0 ]; then
                print_info "Copying $FILE_COUNT file(s) from config folder..."
                cp -r "$CONFIG_DIR"/* "$BEPINEX_BASE/config/" 2>/dev/null || true
                print_success "Config files installed"
            fi
        fi
    fi
    
    # If no subfolders, copy all DLL files to plugins
    if [ "$HAS_SUBFOLDERS" = false ]; then
        print_info "No BepInEx folder structure found, installing DLL files to plugins..."
        DLL_COUNT=$(find "$EXTRACT_DIR" -type f -name "*.dll" | wc -l)
        
        if [ "$DLL_COUNT" -gt 0 ]; then
            print_info "Found $DLL_COUNT DLL file(s)"
            find "$EXTRACT_DIR" -type f -name "*.dll" -exec cp {} "$BEPINEX_BASE/plugins/" \;
            print_success "DLL files installed to plugins"
        else
            print_warning "No DLL files found in mod package"
        fi
    fi
    
    SUCCESSFUL_MODS=$((SUCCESSFUL_MODS + 1))
    print_success "Mod installation completed"
    
    # Clean up this mod's temporary files
    rm -rf "$EXTRACT_DIR" "$ZIP_FILE"
    echo ""
    
done < "$MODLINKS_FILE"

echo "=========================================="
echo ""
print_success "Mod installation process completed!"
echo ""
echo "Summary:"
echo "  Total mods processed: $TOTAL_MODS"
echo "  Successfully installed: $SUCCESSFUL_MODS"
echo "  Failed: $FAILED_MODS"
echo ""

if [ "$SUCCESSFUL_MODS" -gt 0 ]; then
    print_info "Installed mod files can be found in:"
    echo "  Plugins: $BEPINEX_BASE/plugins/"
    echo "  Patchers: $BEPINEX_BASE/patchers/"
    echo "  Config: $BEPINEX_BASE/config/"
    echo ""
    
    if [ "$RUNNING_IN_CONTAINER" = false ]; then
        print_warning "Remember to set BEPINEX_ENABLED=true in your .env file"
        print_warning "and restart the server for mods to take effect!"
    else
        print_warning "Restart the server for mods to take effect!"
    fi
fi

exit 0