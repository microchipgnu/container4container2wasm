FROM alpine:latest

# Install necessary packages
RUN apk update && apk add --no-cache \
    docker \
    openrc \
    bash \
    curl \
    iptables \
    e2fsprogs \
    fuse-overlayfs \
    linux-headers \
    util-linux \
    shadow \
    git \
    tar \
    wget \
    jq

# Install c2w binaries
ENV C2W_VERSION="v0.6.4"
RUN wget https://github.com/ktock/container2wasm/releases/download/${C2W_VERSION}/container2wasm-${C2W_VERSION}-linux-amd64.tar.gz && \
    echo "Downloaded container2wasm-${C2W_VERSION}-linux-amd64.tar.gz" && \
    tar -xzvf container2wasm-${C2W_VERSION}-linux-amd64.tar.gz && \
    echo "Extracted container2wasm-${C2W_VERSION}-linux-amd64.tar.gz" && \
    mv c2w /usr/local/bin/c2w && \
    echo "Moved c2w to /usr/local/bin/" && \
    mv c2w-net /usr/local/bin/c2w-net && \
    echo "Moved c2w-net to /usr/local/bin/" && \
    rm -rf container2wasm-${C2W_VERSION}-linux-amd64.tar.gz && \
    echo "Cleaned up downloaded tar.gz file"

# Install yq
RUN wget https://github.com/mikefarah/yq/releases/download/v4.6.1/yq_linux_amd64 -O /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Add docker_entrypoint.sh script
RUN mkdir -p /usr/local/bin/
COPY docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
RUN chmod +x /usr/local/bin/docker_entrypoint.sh

# Copy the config.yaml file
COPY config.yaml /usr/local/bin/config.yaml

# Expose port 8080
EXPOSE 8080

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/docker_entrypoint.sh"]
CMD ["sh"]
