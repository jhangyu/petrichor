# Linux release build image for scripts/ci.py (arm64 and x64 from this one recipe).
# docker build --platform linux/<arm64|amd64> -t petrichor-linux-build:<arm64|x64> -f scripts/linux_build.Dockerfile scripts/
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates git curl unzip xz-utils zip tar \
        clang cmake ninja-build pkg-config libgtk-3-dev \
        python3 make \
    && rm -rf /var/lib/apt/lists/*

ARG FLUTTER_VERSION=3.44.6
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter

ENV PATH=/opt/flutter/bin:${PATH}
ENV FLUTTER_SUPPRESS_ANALYTICS=true

RUN git config --global --add safe.directory '*' \
    && flutter config --enable-linux-desktop --no-analytics \
    && flutter precache --linux
