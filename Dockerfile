FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /opt

# Install dependencies including rsync
RUN apt-get update && apt-get install -y \
    curl wget unzip cron systemd tzdata \
    lib32gcc-s1 lib32stdc++6 rsync \
    && rm -rf /var/lib/apt/lists/*

# Create directories for Valheim and SteamCMD
RUN mkdir -p /opt/valheim /opt/steamcmd /valheim-data

# Copy all scripts and settings.env into /opt
COPY entrypoint.sh install_valheim.sh install_bepinex.sh install_valheimplus.sh backup.sh restart.sh build_start_cmd.sh settings.env ./

# Make all scripts executable
RUN chmod +x *.sh

ENTRYPOINT ["./entrypoint.sh"]
