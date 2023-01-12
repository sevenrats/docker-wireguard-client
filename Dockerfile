# syntax=docker/dockerfile:1

FROM alpine:3.17
ARG BUILD_DATE
LABEL	maintainer="sevenrats" \
		build-date=$BUILD_DATE \
		name="Electrum-NMC" \
		description="Electrum-NMC with JSON-RPC enabled" \
		version=$VERSION \
		license="GPLv3"

ENV \
    PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
    HOME="/root" \
    TERM="xterm"

RUN \
    apk --no-cache add --virtual .build-deps\
        curl-dev \
        gcc \
        git \
        make \
        musl-dev \
        tzdata \
        xz && \
    mkdir -p \
        /app \
        /config \
        /defaults \
        /data/wireguard/ \
        /run/tinyproxy/ && \
    ln -s /data/wireguard /etc/wireguard && \
    echo "**** install runtime packages ****" && \
    apk add --no-cache \
        alpine-release \
        bash \
        ca-certificates \
        catatonit \
        coreutils \
        curl \
        procps \
        shadow \
        tzdata \
        ifupdown \
        iproute2 \
        iptables \
        iputils \
        net-tools \
        openresolv \
        ldns-tools \
        tinyproxy \
        wireguard-tools && \
    touch /run/tinyproxy/tinyproxy.pid && \
    echo "**** patching wg-quick for alpine ****" && \
    sed -i '/\[\[ $proto == -4 \]\] && cmd sysctl -q net\.ipv4\.conf\.all\.src_valid_mark=1/d' /usr/bin/wg-quick && \
    # add signalproxy
    git clone --depth 1 https://github.com/sevenrats/bash-signal-proxy.git && \
    mv bash-signal-proxy/signalproxy.sh / && \
    # build ip checker
    git clone https://github.com/sevenrats/fastip-c.git && \
    gcc -Wall -o fastip-c/fastip fastip-c/main.c fastip-c/util.c -l curl && \
    mv fastip-c/fastip /usr/bin && \
    echo "**** cleanup ****" && \
    apk del .build-deps && \
    rm -rf \
        fastip-c \
        bash-signal-proxy \
        /tmp/* \
        /root/.cache

ENV TINYPROXY_CONF "tinyproxy/tinyproxy.conf"
ENV CONFS $TINYPROXY_CONF

# add local files
COPY root/ /

EXPOSE 8888/udp

ENTRYPOINT ["catatonit", "/entrypoint.sh"]
