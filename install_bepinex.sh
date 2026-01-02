#!/bin/bash
source ./settings.env
echo "Installing BepInEx..."
wget -q $BEPINEX_URL -O bepinex.zip
unzip -o bepinex.zip -d $VALHEIM_DIR
