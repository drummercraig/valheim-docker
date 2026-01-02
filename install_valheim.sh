
#!/bin/bash
set -e

MAX_RETRIES=5
RETRY_DELAY=5
COUNTER=0

while [ $COUNTER -lt $MAX_RETRIES ]; do
    echo "Attempt $(($COUNTER+1)) to install Valheim server..."
    if ~/steamcmd/steamcmd.sh +force_install_dir +login anonymous /opt/valheim +app_update 896660 validate +quit; then
        echo "Valheim server installed successfully."
        break
    else
        echo "Installation failed. Retrying in $RETRY_DELAY seconds..."
        sleep $RETRY_DELAY
        COUNTER=$(($COUNTER+1))
    fi
done

if [ $COUNTER -eq $MAX_RETRIES ]; then
    echo "Valheim installation failed after $MAX_RETRIES attempts."
    exit 1
fi

# Ensure valheim user owns Valheim directory
#chown -R valheim:valheim /opt/valheim
#chmod -R 755 /opt/valheim
