#!/bin/sh
set -euo pipefail

SOURCE=/usr/local/bin/src/
DEST=./out/
WASI_MAX_CHUNK=50MB
C2W=c2w
C2W_EXTRA_FLAGS_V=${C2W_EXTRA_FLAGS:-}
LOG_FILE="/var/log/startup.log"

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

for I in $(ls -1 ${SOURCE}); do
    OUTPUT_NAME="${I}-container"
    TARGETARCH=$(cat "${SOURCE}/${I}/arch" || true)
    if [ "${TARGETARCH}" == "" ]; then
        TARGETARCH="amd64"
    fi

    if [ $(cat "${SOURCE}/${I}/target" || true) == "emscripten" ]; then
        if [ -f "${SOURCE}/${I}/image" ]; then
            IMAGE=$(cat ${SOURCE}/${I}/image)
            echo "Pulling Docker image $IMAGE..."
            docker pull $IMAGE && echo "Docker image $IMAGE pulled successfully." || { echo "Failed to pull Docker image $IMAGE."; exit 1; }
            ${C2W} --to-js --target-arch="${TARGETARCH}" ${C2W_EXTRA_FLAGS_V} --build-arg JS_OUTPUT_NAME=${OUTPUT_NAME} "$IMAGE" "${DEST}"
        elif [ -f "${SOURCE}/${I}/Dockerfile" ]; then
            cat ${SOURCE}/${I}/Dockerfile | docker buildx build --progress=plain -t ${I} --platform="linux/${TARGETARCH}" --load -
            ${C2W} --to-js --target-arch="${TARGETARCH}" ${C2W_EXTRA_FLAGS_V} --build-arg JS_OUTPUT_NAME=${OUTPUT_NAME} "${I}" "${DEST}"
        else
            echo "No image source found for ${I}"
            exit 1
        fi
    else
        if [ -f "${SOURCE}/${I}/image" ]; then
            IMAGE=$(cat ${SOURCE}/${I}/image)
            echo "Pulling Docker image $IMAGE..."
            docker pull $IMAGE && echo "Docker image $IMAGE pulled successfully." || { echo "Failed to pull Docker image $IMAGE."; exit 1; }
            ${C2W} --target-arch="${TARGETARCH}" ${C2W_EXTRA_FLAGS_V} "$IMAGE" "${DEST}/${OUTPUT_NAME}.wasm"
        elif [ -f "${SOURCE}/${I}/Dockerfile" ]; then
            cat ${SOURCE}/${I}/Dockerfile | docker buildx build --progress=plain -t ${I} --platform="linux/${TARGETARCH}" --load -
            ${C2W} --target-arch="${TARGETARCH}" ${C2W_EXTRA_FLAGS_V} "${I}" "${DEST}/${OUTPUT_NAME}.wasm"
        else
            echo "No image source found for ${I}"
            exit 1
        fi
        split -b "${WASI_MAX_CHUNK}" "${DEST}/${OUTPUT_NAME}.wasm" "${DEST}/${OUTPUT_NAME}-part-"
        rm "${DEST}/${OUTPUT_NAME}.wasm"
    fi
done

echo "Conversion complete. Keeping container alive..."
tail -f /dev/null
