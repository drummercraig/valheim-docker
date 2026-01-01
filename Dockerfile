FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV STEAMCMD_DIR=/opt/steamcmd
ENV VALHEIM_DIR=/opt/valheim

RUN apt-get update && apt-get install -y \
    curl wget unzip cron tzdata lib32gcc-s1 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${STEAMCMD_DIR} ${VALHEIM_DIR} /valheim-data
RUN useradd -m -d /home/valheim -s /bin/bash valheim && \
    chown -R valheim:valheim ${STEAMCMD_DIR} ${VALHEIM_DIR} /valheim-data

COPY install_steamcmd.sh /install_steamcmd.sh
COPY install_valheim.sh /install_valheim.sh
COPY install_modloader.sh /install_modloader.sh
COPY install_bepinex.sh /install_bepinex.sh
COPY entrypoint.sh /entrypoint.sh
COPY idle_check.sh /idle_check.sh
COPY crontab.txt /crontab.txt
COPY settings.env /settings.env

RUN chmod +x /*.sh
RUN crontab /crontab.txt

USER valheim
WORKDIR ${VALHEIM_DIR}

HEALTHCHECK --interval=60s --timeout=10s --start-period=120s \
    CMD pgrep -f valheim_server.x86_64 || exit 1

ENTRYPOINT ["/entrypoint.sh"]
