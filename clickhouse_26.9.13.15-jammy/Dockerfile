FROM clickhouse:26.9.13.15-jammy

USER root

# Install packages (Ubuntu base image -> use apt-get instead of apk)
RUN apt-get update \
    && apt-get install -y --no-install-recommends mc \
    && rm -rf /var/lib/apt/lists/*

USER clickhouse
