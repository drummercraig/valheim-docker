#!/bin/bash
set -e
source /settings.env

echo "======================================"
echo "Mod Loader Installation"
echo "======================================"

case "$MOD_LOADER" in
    BepInEx)
     #   echo "Installing BepInEx..."
     #   wget -q $BEPINEX_URL -O /tmp/bepinex.zip
     #   unzip -o /tmp/bepinex.zip -d ${VALHEIM_DIR}
         /install_bepinex.sh
        ;;
    ValheimPlus)
        echo "Installing ValheimPlus..."
        wget -q $VALHEIMPLUS_URL -O /tmp/valheimplus.zip
        unzip -o /tmp/valheimplus.zip -d ${VALHEIM_DIR}
        ;;
    None)
        echo "No mod loader selected."
        ;;
    *)
        echo "Invalid MOD_LOADER option: $MOD_LOADER"
        ;;
esac

echo "======================================"
``
