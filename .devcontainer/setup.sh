#!/bin/bash
# 1. Restore R packages
Rscript -e 'renv::restore()'

# 2. Setup SSH trust
# 2.1. Give container some time to fully boot and generate key
sleep 10
# 2.2. Create .ssh folder in container root
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# 2.3. Scan for key
# -t ed25519: forces the modern standard key type
ssh-keyscan -t ed25519 -p 2222 127.0.0.1 >> ~/.ssh/known_hosts
# 2.4. Fix permissions (SSH is strict about this)
chmod 644 ~/.ssh/known_hosts

# 3. Start SFTP server
# "upload": Chroot jail
docker run --name sftp_test -p 2222:22 -d atmoz/sftp tester:password123:::upload