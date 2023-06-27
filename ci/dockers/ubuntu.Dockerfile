ARG OS_VERSION
FROM ubuntu:${OS_VERSION}

RUN apt-get update && \
    apt-get -qq install -y \
        automake \
        dkms \
        libtool \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
