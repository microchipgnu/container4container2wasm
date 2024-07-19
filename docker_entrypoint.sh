#!/bin/sh
set -euo pipefail

DEST=./out/
WASI_MAX_CHUNK=50MB
C2W=c2w
C2W_EXTRA_FLAGS_V=${C2W_EXTRA_FLAGS:-}
LOG_FILE="/var/log/startup.log"
CONTAINERS_FILE="/usr/local/bin/config.yaml"

# Attempt to load overlay module
if ! modprobe overlay; then
    echo "Warning: overlay module could not be loaded, continuing with fuse-overlayfs"
fi

# Start Docker daemon in the background
dockerd --storage-driver=fuse-overlayfs &

# Wait for Docker to start
while (! docker info > /dev/null 2>&1); do
    echo "Waiting for Docker to start..."
    sleep 1
done

exec > >(tee -i $LOG_FILE)
exec 2>&1

echo "Docker daemon is running."

# Read from the YAML file and process each container
echo "Reading containers from $CONTAINERS_FILE"
containers=$(yq eval -j $CONTAINERS_FILE)

if [ -z "$containers" ]; then
    echo "Error: No containers found in $CONTAINERS_FILE"
    exit 1
fi

echo "Parsed containers:"
echo "$containers"

echo "$containers" | jq -c '.containers[]' | while read -r container; do
    echo "Processing container: $container"

    I=$(echo $container | jq -r '.name')
    TARGETARCH=$(echo $container | jq -r '.arch')
    TARGET=$(echo $container | jq -r '.target')
    IMAGE=$(echo $container | jq -r '.image // empty')
    DOCKERFILE=$(echo $container | jq -r '.dockerfile // empty')

    OUTPUT_NAME="${I}-container"

    echo "Name: $I, Arch: $TARGETARCH, Target: $TARGET"
    echo "Image: $IMAGE"
    echo "Dockerfile: $DOCKERFILE"

    if [ "$TARGET" = "emscripten" ]; then
        if [ -n "$IMAGE" ]; then
            echo "Pulling Docker image $IMAGE..."
            docker pull $IMAGE && echo "Docker image $IMAGE pulled successfully." || { echo "Failed to pull Docker image $IMAGE."; exit 1; }
            ${C2W} --to-js --target-arch="${TARGETARCH}" ${C2W_EXTRA_FLAGS_V} --build-arg JS_OUTPUT_NAME=${OUTPUT_NAME} "$IMAGE" "${DEST}"
        elif [ -n "$DOCKERFILE" ]; then
            echo "$DOCKERFILE" | docker buildx build --progress=plain -t ${I} --platform="linux/${TARGETARCH}" -
            ${C2W} --to-js --target-arch="${TARGETARCH}" ${C2W_EXTRA_FLAGS_V} --build-arg JS_OUTPUT_NAME=${OUTPUT_NAME} "${I}" "${DEST}"
        else
            echo "No image or Dockerfile source found for ${I}"
            exit 1
        fi
    else
        if [ -n "$IMAGE" ]; then
            echo "Pulling Docker image $IMAGE..."
            docker pull $IMAGE && echo "Docker image $IMAGE pulled successfully." || { echo "Failed to pull Docker image $IMAGE."; exit 1; }
            ${C2W} --target-arch="${TARGETARCH}" ${C2W_EXTRA_FLAGS_V} "$IMAGE" "${DEST}/${OUTPUT_NAME}.wasm"
        elif [ -n "$DOCKERFILE" ]; then
            echo "$DOCKERFILE" | docker buildx build --progress=plain -t ${I} --platform="linux/${TARGETARCH}" -
            ${C2W} --target-arch="${TARGETARCH}" ${C2W_EXTRA_FLAGS_V} "${I}" "${DEST}/${OUTPUT_NAME}.wasm"
        else
            echo "No image or Dockerfile source found for ${I}"
            exit 1
        fi
        split -b "${WASI_MAX_CHUNK}" "${DEST}/${OUTPUT_NAME}.wasm" "${DEST}/${OUTPUT_NAME}-part-"
        rm "${DEST}/${OUTPUT_NAME}.wasm"
    fi
done

echo "Conversion complete. Keeping container alive..."
tail -f /dev/null
