#!/bin/bash

set -e

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

log() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

# Update system
log "Updating package lists..."
sudo apt update && sudo apt upgrade -y

# Install dependencies
log "Installing required packages..."
sudo apt install -y git jq ca-certificates curl

# Add Docker GPG key
log "Adding Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
if sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; then
    log "Docker GPG key downloaded successfully."
else
    error "Failed to download Docker GPG key!"
    exit 1
fi
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
log "Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists after adding Docker repository
log "Updating package lists again..."
sudo apt-get update

# Install Docker
log "Installing Docker..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable Docker service
log "Enabling Docker service to start on boot..."
sudo systemctl enable docker

log "Docker installation completed successfully!"
