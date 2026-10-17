FROM postgres:18.6-trixie

# Install packages (trixie is Debian-based, so use apt-get)
RUN apt-get update \
    && apt-get install -y --no-install-recommends mc \
    && rm -rf /var/lib/apt/lists/*
