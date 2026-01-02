FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /opt

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl wget unzip cron systemd tzdata \
    lib32gcc-s1 lib32stdc++6 \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /opt/valheim /opt/steamcmd /valheim-data

# Copy scripts and env file
COPY entrypoint.sh install_valheim.sh install_bepinex.sh install_valheimplus.sh install_steamcmd.sh backup.sh restart.sh settings.env ./

# Make scripts executable
RUN chmod +x *.sh

ENTRYPOINT ["./entrypoint.sh"]
