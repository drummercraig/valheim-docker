#!/bin/bash
source ./settings.env
echo "Installing ValheimPlus..."
wget -q $VALHEIMPLUS_URL -O valheimplus.zip
unzip -o valheimplus.zip -d $VALHEIM_DIR
