
FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y wget unzip curl lib32gcc-s1 && rm -rf /var/lib/apt/lists/*

# Create valheim user and directories
RUN useradd -m valheim && mkdir -p /opt/valheim && chown valheim:valheim /opt/valheim
USER valheim
WORKDIR /opt/valheim

# Copy installation scripts and entrypoint
COPY install_steamcmd.sh /tmp/install_steamcmd.sh
COPY install_valheim.sh /tmp/install_valheim.sh
COPY entrypoint.sh /opt/valheim/entrypoint.sh

# Make scripts executable
RUN chmod +x /tmp/install_steamcmd.sh /tmp/install_valheim.sh /opt/valheim/entrypoint.sh

# Run SteamCMD installation
RUN /tmp/install_steamcmd.sh

# Run Valheim installation with retry logic
RUN /tmp/install_valheim.sh

# Expose Valheim ports
EXPOSE 2456-2458/udp

# Environment variables
ENV SERVER_NAME="MyValheimServer" \
    WORLD_NAME="Dedicated" \
    SERVER_PASS="secret" \
    SERVER_PUBLIC="1"

# Use entrypoint to fix permissions and start server
ENTRYPOINT ["/opt/valheim/entrypoint.sh"]
