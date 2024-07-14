#!/bin/bash
set -e

IMAGE_NAME="my-conversion-container"
CONTAINER_NAME="conversion-container"
SOURCE_DIR="./src"
DEST_DIR="./out"

# Build the Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME .

# Run the Docker container
echo "Running Docker container..."
docker run --privileged -d --name $CONTAINER_NAME -v /lib/modules:/lib/modules:ro $IMAGE_NAME

# Wait for the container to complete the conversion
echo "Waiting for conversion to complete..."
# Assuming conversion takes time and logs will indicate completion, you might want to wait and check logs
# You can add a more sophisticated check or a timeout if needed
sleep 5  # Sleep for 5 seconds

# Check container logs for completion message (optional)
if docker logs $CONTAINER_NAME 2>&1 | grep -q "Conversion complete. Keeping container alive..."; then
    echo "Conversion completed successfully."
else
    echo "Conversion did not complete as expected. Check logs for details."
    docker logs $CONTAINER_NAME
    exit 1
fi

# Copy the output files to the local machine
echo "Copying output files to local machine..."
docker cp $CONTAINER_NAME:/usr/local/bin/out $DEST_DIR

echo "Files copied to $DEST_DIR"

# Optionally stop and remove the container
echo "Stopping and removing the Docker container..."
docker stop $CONTAINER_NAME
docker rm $CONTAINER_NAME

echo "Done."
