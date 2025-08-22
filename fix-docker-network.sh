#!/bin/bash
# Fix Docker networking issues - requires sudo
# This script should be run by an administrator when Docker networking is broken

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log "ERROR" "This script must be run as root (use sudo)"
   exit 1
fi

log "INFO" "🔧 Fixing Docker networking issues..."

# Stop Docker service
log "INFO" "Stopping Docker service..."
systemctl stop docker || true

# Stop all containers (if Docker is still partially working)
docker stop $(docker ps -aq) 2>/dev/null || true

# Clean up Docker networks
docker network prune -f >/dev/null 2>&1 || true

# Clean up any broken Docker iptables rules
log "INFO" "Cleaning up iptables rules..."
iptables -t nat -F DOCKER 2>/dev/null || true
iptables -t nat -X DOCKER 2>/dev/null || true
iptables -t filter -F DOCKER 2>/dev/null || true
iptables -t filter -X DOCKER 2>/dev/null || true
iptables -t filter -F DOCKER-FORWARD 2>/dev/null || true
iptables -t filter -X DOCKER-FORWARD 2>/dev/null || true
iptables -t filter -F DOCKER-ISOLATION-STAGE-1 2>/dev/null || true
iptables -t filter -X DOCKER-ISOLATION-STAGE-1 2>/dev/null || true
iptables -t filter -F DOCKER-ISOLATION-STAGE-2 2>/dev/null || true
iptables -t filter -X DOCKER-ISOLATION-STAGE-2 2>/dev/null || true
iptables -t filter -F DOCKER-USER 2>/dev/null || true
iptables -t filter -X DOCKER-USER 2>/dev/null || true

# Clean up Docker network state
log "INFO" "Cleaning up Docker network state..."
rm -rf /var/lib/docker/network/files/* 2>/dev/null || true

# Restart Docker to recreate chains
log "INFO" "Restarting Docker service..."
systemctl restart docker

# Wait for Docker to be ready
log "INFO" "Waiting for Docker to be ready..."
for i in {1..30}; do
    if docker info >/dev/null 2>&1; then
        log "INFO" "✅ Docker daemon is ready"
        break
    fi
    sleep 1
done

if ! docker info >/dev/null 2>&1; then
    log "ERROR" "❌ Docker failed to restart properly"
    exit 1
fi

# Test Docker networking
log "INFO" "Testing Docker networking..."
if docker network create --driver bridge test-network-$$$ >/dev/null 2>&1; then
    docker network rm test-network-$$$ >/dev/null 2>&1
    log "INFO" "✅ Docker networking fixed successfully!"
else
    log "ERROR" "❌ Docker networking still appears to be broken"
    exit 1
fi

log "INFO" "✅ Docker is now ready for use"
log "INFO" "You can now run the start.sh script as a regular user"
