#!/bin/bash
# Host script for safely stopping the Valheim server
# Usage: ./safe-stop.sh [--force-save]

set -e

CONTAINER_NAME="valheim-server"
FORCE_SAVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force-save|-f)
            FORCE_SAVE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Safely stop the Valheim server with world save verification."
            echo ""
            echo "Options:"
            echo "  -f, --force-save    Force a save before stopping"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                  # Check status and stop"
            echo "  $0 --force-save     # Force save then stop"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "VALHEIM SERVER SAFE STOP"
echo "=========================================="
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container '$CONTAINER_NAME' is not running"
    exit 1
fi

# If force save requested, do it
if [ "$FORCE_SAVE" = true ]; then
    echo "Forcing world save..."
    echo ""
    docker exec "$CONTAINER_NAME" /usr/local/bin/force-save
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -ne 0 ]; then
        echo ""
        echo "❌ Force save failed or could not verify"
        echo "   Check the output above for details"
        echo ""
        read -p "Continue with stop anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Stop cancelled"
            exit 1
        fi
    fi
else
    # Check status first
    echo "Checking world save status..."
    echo ""
    docker exec "$CONTAINER_NAME" /usr/local/bin/check-world-status
    STATUS=$?
    
    echo ""
    
    if [ $STATUS -eq 0 ]; then
        echo "✓ World is recently saved - safe to stop"
    elif [ $STATUS -eq 2 ]; then
        echo ""
        read -p "Run force-save before stopping? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo ""
            echo "Forcing world save..."
            echo ""
            docker exec "$CONTAINER_NAME" /usr/local/bin/force-save
            
            if [ $? -ne 0 ]; then
                echo ""
                echo "❌ Force save failed"
                read -p "Continue with stop anyway? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "Stop cancelled"
                    exit 1
                fi
            fi
        fi
    else
        echo "⚠ World has never been saved!"
        echo ""
        read -p "Stop anyway and lose the world? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Stop cancelled"
            exit 1
        fi
    fi
fi

echo ""
echo "=========================================="
echo "Stopping container..."
echo "=========================================="
echo ""

# Stop the container
docker compose stop

echo ""
echo "✓ Container stopped"
echo ""
echo "To view shutdown logs:"
echo "  docker compose logs valheim-server | tail -50"
echo ""