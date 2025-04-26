# syntax=docker/dockerfile:1

from rust:alpine as builder

RUN \
    apk --no-cache add \
        musl-dev \
        git && \
    git clone https://github.com/sevenrats/fastip-rs  && \
    cd fastip-rs && \
    cargo build --release --no-default-features --target x86_64-unknown-linux-musl && \
    mv target/x86_64-unknown-linux-musl/release/fastip /fastip

FROM alpine:3.17
ARG BUILD_DATE
LABEL	maintainer="sevenrats" \
		build-date=$BUILD_DATE \
		name="Docker Wireguard Client" \
		description="Docker Wireguard Client" \
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
    ln -s /data/vpn /etc/wireguard && \
    echo "**** install runtime packages ****" && \
    apk add --no-cache \
        alpine-release \
        bash \
        ca-certificates \
        catatonit \
        coreutils \
        curl \
        jq \
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
        drill \
        tinyproxy \
        wireguard-tools && \
    touch /run/tinyproxy/tinyproxy.pid && \
    echo "**** patching wg-quick for alpine ****" && \
    sed -i '/\[\[ $proto == -4 \]\] && cmd sysctl -q net\.ipv4\.conf\.all\.src_valid_mark=1/d' /usr/bin/wg-quick && \
    # add signalproxy
    git clone --depth 1 https://github.com/sevenrats/bash-signal-proxy.git && \
    mv bash-signal-proxy/signalproxy.sh / && \
    echo "**** cleanup ****" && \
    apk del .build-deps && \
    rm -rf \
        fastip-c \
        bash-signal-proxy \
        /tmp/* \
        /root/.cache

ENV VPN_BUCKET_PATH "/data/vpn/wg0.bkt"
ENV TINYPROXY_CONF "tinyproxy/tinyproxy.conf"
ENV CONFS $TINYPROXY_CONF

# add local files
COPY --from=builder /fastip /usr/bin/fastip
COPY root/ /

EXPOSE 8888/udp

ENTRYPOINT ["catatonit", "/entrypoint.sh"]
