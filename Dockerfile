
FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y wget unzip curl rsync lib32gcc-s1 supervisor && rm -rf /var/lib/apt/lists/*

# Create valheim user and directories
RUN useradd -m valheim && mkdir -p /opt/valheim && mkdir -p /opt/cache && mkdir -p /opt/config && mkdir -p /opt/backups

# Copy scripts and bootstrap
COPY install_steamcmd.sh /tmp/install_steamcmd.sh
COPY install_valheim.sh /tmp/install_valheim.sh
COPY bootstrap.sh /bootstrap.sh

# Make scripts executable
RUN chmod +x /tmp/install_steamcmd.sh /tmp/install_valheim.sh /bootstrap.sh

# Install SteamCMD and Valheim as root during build
RUN /tmp/install_steamcmd.sh && /tmp/install_valheim.sh

# Expose Valheim ports
EXPOSE 2456-2458/udp

# Environment variables
ENV SERVER_NAME="MyValheimServer" \
    WORLD_NAME="Dedicated" \
    SERVER_PASS="secret" \
    SERVER_PUBLIC="1"

# Use bootstrap script as entrypoint
ENTRYPOINT ["/bootstrap.sh"]
