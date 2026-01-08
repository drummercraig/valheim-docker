FROM ubuntu:24.04

# Set environment variables with defaults
# These will be overridden by values from .env file
ENV DEBIAN_FRONTEND=noninteractive \
    SERVER_NAME="My Valheim Server" \
    SERVER_PORT=2456 \
    WORLD_NAME="Dedicated" \
    SERVER_PASS="secret" \
    SERVER_PUBLIC=true \
    CROSSPLAY=false \
    WORLD_SEED="" \
    WORLD_SIZE="" \
    UPDATE_INTERVAL=900 \
    BACKUPS_ENABLED=true \
    BACKUPS_INTERVAL=3600 \
    BACKUPS_DIRECTORY=/userfiles/backups \
    BACKUPS_MAX_AGE=3 \
    TZ=Etc/UTC \
    PRESET="" \
    MODIFIER_COMBAT="" \
    MODIFIER_DEATHPENALTY="" \
    MODIFIER_RESOURCES="" \
    MODIFIER_RAIDS="" \
    MODIFIER_PORTALS="" \
    SETKEY_NOBUILDCOST=false \
    SETKEY_PLAYEREVENTS=false \
    SETKEY_PASSIVEMOBS=false \
    SETKEY_NOMAP=false \
    NOPORTALS=false \
    SERVER_ARGS="" \
    BEPINEX_ENABLED=false \
    MOD_LOADER="BepInEx"

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dumb-init \
    lib32gcc-s1 \
    libsdl2-2.0-0 \
    rsync \
    supervisor \
    tzdata \
    zip \
    unzip && \
    rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /opt/valheim \
    /opt/steamcmd \
    /userfiles/worlds_local \
    /userfiles/backups \
    /userfiles/bepinex/plugins \
    /userfiles/bepinex/patchers \
    /userfiles/bepinex/config \
    /var/log/supervisor

# Download and install SteamCMD
RUN cd /opt/steamcmd && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# Copy scripts
COPY valheim-server.sh /usr/local/bin/valheim-server
COPY valheim-updater.sh /usr/local/bin/valheim-updater
COPY valheim-backup.sh /usr/local/bin/valheim-backup
COPY valheim-sync.sh /usr/local/bin/valheim-sync
COPY bepinex-installer.sh /usr/local/bin/bepinex-installer
COPY debug-worlds.sh /usr/local/bin/debug-worlds
COPY bepinex-installer.sh /usr/local/bin/debug-worlds
COPY force-save.sh /usr/local/bin/force-save
COPY pre-stop-hook.sh /usr/local/bin/pre-stop-hook
COPY check-world-status.sh /usr/local/bin/check-world-status
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make scripts executable
RUN chmod +x /usr/local/bin/valheim-server \
    /usr/local/bin/valheim-updater \
    /usr/local/bin/valheim-backup \
    /usr/local/bin/valheim-sync \
    /usr/local/bin/bepinex-installer \
    /usr/local/bin/debug-worlds \
    /usr/local/bin/force-save \
    /usr/local/bin/pre-stop-hook \
    /usr/local/bin/check-world-status

# Expose ports
# Game port (UDP)
EXPOSE 2456/udp
# Query port (UDP)
EXPOSE 2457/udp
# Crossplay port (UDP, if enabled)
EXPOSE 2458/udp

# Volumes
VOLUME ["/userfiles", "/opt/valheim"]

# Use init to properly handle signals
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]