#!/bin/bash

echo "sftp_test container started successfully."

# Wait for the SFTP server to be ready for SSH connections
echo "Waiting for SFTP server to initialize..."
sleep 5

# Refresh SSH known_hosts
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keyscan -t ed25519 -p 2222 127.0.0.1 >> ~/.ssh/known_hosts
chmod 644 ~/.ssh/known_hosts
echo "SSH known_hosts updated."
