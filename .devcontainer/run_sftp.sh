#!/bin/bash
# 1. Restore R packages
Rscript -e 'renv::restore()'

# 2. Set up environment to map
# "upload": Chroot jail
# create `upload` folder on host and mount it to container, 
# so that we can test file uploads
mkdir -p /workspaces/sftpR/upload
chmod -R 755 /workspaces/sftpR/upload

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
docker run --name sftp_test \
    -p 2222:22 \
    -v /workspaces/sftpR/upload:/upload \
    -d atmoz/sftp tester:password123:::upload
