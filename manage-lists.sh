#!/bin/bash
# Helper script for managing admin, ban, and permitted lists
# Run from host: ./manage-lists.sh

set -e

USERFILES_DIR="./userfiles"

show_usage() {
    cat << EOF
Valheim Server List Management

Usage: $0 <command> [options]

Commands:
    show <list>              Show contents of a list
    add <list> <steamid>     Add Steam ID to a list
    remove <list> <steamid>  Remove Steam ID from a list
    clear <list>             Clear all entries from a list
    
Lists:
    admin       - Server administrators
    banned      - Banned players
    permitted   - Permitted players (whitelist)

Examples:
    $0 show admin
    $0 add admin 76561198012345678
    $0 remove banned 76561198087654321
    $0 clear permitted

Note: Changes take effect immediately. Server does not need restart.
EOF
}

# Ensure userfiles directory exists
if [ ! -d "$USERFILES_DIR" ]; then
    echo "ERROR: userfiles directory not found at $USERFILES_DIR"
    exit 1
fi

# Function to get list file path
get_list_file() {
    local list="$1"
    case "$list" in
        admin)
            echo "${USERFILES_DIR}/adminlist.txt"
            ;;
        banned)
            echo "${USERFILES_DIR}/bannedlist.txt"
            ;;
        permitted)
            echo "${USERFILES_DIR}/permittedlist.txt"
            ;;
        *)
            echo "ERROR: Invalid list name: $list"
            echo "Valid lists: admin, banned, permitted"
            exit 1
            ;;
    esac
}

# Function to show list
show_list() {
    local list="$1"
    local file=$(get_list_file "$list")
    
    if [ ! -f "$file" ]; then
        touch "$file"
    fi
    
    echo "=========================================="
    echo "$(echo $list | tr '[:lower:]' '[:upper:]') LIST"
    echo "=========================================="
    
    if [ -s "$file" ]; then
        cat "$file" | grep -v '^$' | nl
        echo ""
        echo "Total: $(grep -c '[0-9]' $file 2>/dev/null || echo 0) entries"
    else
        echo "(empty)"
    fi
    
    echo "=========================================="
}

# Function to add to list
add_to_list() {
    local list="$1"
    local steamid="$2"
    local file=$(get_list_file "$list")
    
    if [ -z "$steamid" ]; then
        echo "ERROR: Steam ID required"
        exit 1
    fi
    
    # Validate Steam ID format (should be numeric and 17 digits)
    if ! [[ "$steamid" =~ ^[0-9]{17}$ ]]; then
        echo "WARNING: Steam ID should be 17 digits"
        echo "Provided: $steamid"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Create file if it doesn't exist
    if [ ! -f "$file" ]; then
        touch "$file"
    fi
    
    # Check if already exists
    if grep -q "^${steamid}$" "$file" 2>/dev/null; then
        echo "Steam ID already in $(echo $list | tr '[:lower:]' '[:upper:]') list"
        exit 0
    fi
    
    # Add to list
    echo "$steamid" >> "$file"
    echo "✓ Added $steamid to $(echo $list | tr '[:lower:]' '[:upper:]') list"
    
    # Show updated list
    echo ""
    show_list "$list"
}

# Function to remove from list
remove_from_list() {
    local list="$1"
    local steamid="$2"
    local file=$(get_list_file "$list")
    
    if [ -z "$steamid" ]; then
        echo "ERROR: Steam ID required"
        exit 1
    fi
    
    if [ ! -f "$file" ]; then
        echo "List file doesn't exist (nothing to remove)"
        exit 0
    fi
    
    # Check if exists
    if ! grep -q "^${steamid}$" "$file" 2>/dev/null; then
        echo "Steam ID not found in $(echo $list | tr '[:lower:]' '[:upper:]') list"
        exit 0
    fi
    
    # Remove from list (create temp file to avoid issues)
    grep -v "^${steamid}$" "$file" > "${file}.tmp" || true
    mv "${file}.tmp" "$file"
    
    echo "✓ Removed $steamid from $(echo $list | tr '[:lower:]' '[:upper:]') list"
    
    # Show updated list
    echo ""
    show_list "$list"
}

# Function to clear list
clear_list() {
    local list="$1"
    local file=$(get_list_file "$list")
    
    if [ ! -f "$file" ] || [ ! -s "$file" ]; then
        echo "List is already empty"
        exit 0
    fi
    
    local count=$(grep -c '[0-9]' "$file" 2>/dev/null || echo 0)
    
    read -p "Clear all $count entries from $(echo $list | tr '[:lower:]' '[:upper:]') list? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
    
    # Clear the file
    > "$file"
    echo "✓ Cleared $(echo $list | tr '[:lower:]' '[:upper:]') list"
}

# Main logic
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

COMMAND="$1"
LIST="$2"
STEAMID="$3"

case "$COMMAND" in
    show)
        if [ -z "$LIST" ]; then
            echo "ERROR: List name required"
            echo "Usage: $0 show <list>"
            exit 1
        fi
        show_list "$LIST"
        ;;
    add)
        if [ -z "$LIST" ]; then
            echo "ERROR: List name required"
            echo "Usage: $0 add <list> <steamid>"
            exit 1
        fi
        add_to_list "$LIST" "$STEAMID"
        ;;
    remove)
        if [ -z "$LIST" ]; then
            echo "ERROR: List name required"
            echo "Usage: $0 remove <list> <steamid>"
            exit 1
        fi
        remove_from_list "$LIST" "$STEAMID"
        ;;
    clear)
        if [ -z "$LIST" ]; then
            echo "ERROR: List name required"
            echo "Usage: $0 clear <list>"
            exit 1
        fi
        clear_list "$LIST"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "ERROR: Unknown command: $COMMAND"
        echo ""
        show_usage
        exit 1
        ;;
esac