#!/bin/bash
# 1. Restore R packages
Rscript -e 'renv::restore()'

# 2. Set up environment to map
# "upload": Chroot jail
# create `upload` folder on host and mount it to container, 
# so that we can test file uploads.
# Explicitly ensure the rstudio user owns the new upload folder.
mkdir -p "$(pwd)/upload"
sudo chown -R rstudio:rstudio "$(pwd)/upload"
chmod -R 755 "$(pwd)/upload"

# 3. Start the SFTP server in the background
# Function to wait for docker daemon to be ready
wait_for_docker() {
    echo "Waiting for Docker daemon to be ready..."
    while ! docker info > /dev/null 2>&1; do
        sleep 1
    done
    echo "Docker daemon is ready."
}

wait_for_docker

echo "Cleaning up old sftp_test container..."
docker rm -f sftp_test || true

echo "Starting sftp_test container..."
# Note: The 'atmoz/sftp' container internally maps 'tester' to UID 1001
# by default. Because you are mounting a local volume, the 'chown' above ensures 
# the host side is ready for the mount.
docker run --name sftp_test \
    -p 2222:22 \
    -v "$(pwd)/upload:/home/tester/upload" \
    -d atmoz/sftp tester:password123:::upload
