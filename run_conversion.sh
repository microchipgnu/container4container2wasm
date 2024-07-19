#!/bin/bash
set -e

IMAGE_NAME="my-conversion-container"
CONTAINER_NAME="conversion-container"
DEST_DIR="./out"
LOG_TIMEOUT=600 

# Function to check if Docker is installed
check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        echo "Docker not found. Installing Docker..."

        # Identify the package manager and install Docker accordingly
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            sudo apt-get remove -y docker docker-engine docker.io containerd runc
            sudo apt-get update
            sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io coreutils
        elif command -v yum &> /dev/null; then
            # RHEL/CentOS
            sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io coreutils
        elif command -v brew &> /dev/null; then
            # macOS
            brew install --cask docker
            brew install coreutils
            open /Applications/Docker.app
            # Wait until Docker is running
            while ! docker system info > /dev/null 2>&1; do
                echo "Waiting for Docker to start..."
                sleep 5
            done
        else
            echo "Unsupported package manager. Please install Docker manually."
            exit 1
        fi

        # Start and enable Docker if necessary
        if [[ "$(uname)" == "Linux" ]]; then
            sudo systemctl start docker
            sudo systemctl enable docker
        fi

        # Verify the installation
        docker --version
    else
        echo "Docker is already installed."
    fi
}

# Function to clean up Docker container
cleanup() {
    echo "Stopping and removing the Docker container..."
    docker stop $CONTAINER_NAME || true
    docker rm $CONTAINER_NAME || true
}

# Trap signals and call cleanup function
trap cleanup EXIT

# Check and install Docker if necessary
check_docker_installed

# Ensure timeout command is available and in PATH
if ! command -v timeout &> /dev/null; then
    echo "Installing coreutils for timeout command..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y coreutils
    elif command -v yum &> /dev/null; then
        sudo yum install -y coreutils
    elif command -v brew &> /dev/null; then
        brew install coreutils
    else
        echo "Unsupported package manager. Please install coreutils manually."
        exit 1
    fi
fi

# Add coreutils to PATH if installed by Homebrew
if command -v brew &> /dev/null; then
    export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
fi

# Remove any existing container with the same name
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "Removing existing container..."
    docker stop $CONTAINER_NAME > /dev/null 2>&1 || true
    docker rm $CONTAINER_NAME > /dev/null 2>&1 || true
fi

# Build the Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME .

# Run the Docker container
echo "Running Docker container..."
docker run --privileged -d --name $CONTAINER_NAME -v /lib/modules:/lib/modules:ro $IMAGE_NAME

# Function to check logs for completion message with timeout
listen_to_logs_for_completion() {
    timeout $LOG_TIMEOUT docker logs -f $CONTAINER_NAME | while read -r line; do
        echo "$line"
        if echo "$line" | grep -q "Conversion complete. Keeping container alive..."; then
            echo "Conversion completed successfully."
            break
        fi
    done

    if [ $? -eq 124 ]; then
        echo "Error: Conversion did not complete within the timeout period."
        exit 1
    fi
}

# Wait for the container to complete the conversion
echo "Waiting for conversion to complete..."
listen_to_logs_for_completion

# Check if the destination directory exists, create if it doesn't
if [ ! -d "$DEST_DIR" ]; then
    mkdir -p $DEST_DIR
fi

# Copy the output files to the local machine
echo "Copying output files to local machine..."
if docker cp $CONTAINER_NAME:/usr/local/bin/out $DEST_DIR; then
    echo "Files copied to $DEST_DIR"
else
    echo "Error: Could not find the file /usr/local/bin/out in container $CONTAINER_NAME"
    exit 1
fi
