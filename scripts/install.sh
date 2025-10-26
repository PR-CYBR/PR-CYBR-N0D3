#!/bin/bash
set -euo pipefail

# PR-CYBR-N0D3 Installation Script
# Automates node setup and configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect architecture
detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            log_info "Detected architecture: AMD64"
            export NODE_ARCH="amd64"
            ;;
        aarch64|arm64)
            log_info "Detected architecture: ARM64"
            export NODE_ARCH="arm64"
            ;;
        armv7l)
            log_info "Detected architecture: ARMv7"
            export NODE_ARCH="armv7"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker already installed: $(docker --version)"
        return 0
    fi

    log_info "Installing Docker..."
    
    # Update package index
    apt-get update -qq
    
    # Install prerequisites
    apt-get install -y -qq \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    log_info "Docker installed successfully"
}

# Install ZeroTier
install_zerotier() {
    if command -v zerotier-cli &> /dev/null; then
        log_info "ZeroTier already installed"
        return 0
    fi

    log_info "Installing ZeroTier..."
    curl -s https://install.zerotier.com | bash
    systemctl start zerotier-one
    systemctl enable zerotier-one
    log_info "ZeroTier installed successfully"
}

# Install Tailscale
install_tailscale() {
    if command -v tailscale &> /dev/null; then
        log_info "Tailscale already installed"
        return 0
    fi

    log_info "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    systemctl start tailscaled
    systemctl enable tailscaled
    log_info "Tailscale installed successfully"
}

# Configure system settings
configure_system() {
    log_info "Configuring system settings..."

    # Enable IP forwarding
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p

    # Set up directories
    mkdir -p /etc/pr-cybr
    mkdir -p /var/log/pr-cybr
    mkdir -p /var/lib/pr-cybr

    log_info "System configured successfully"
}

# Load environment configuration
load_config() {
    if [ -f "$PROJECT_ROOT/.env" ]; then
        log_info "Loading configuration from .env"
        set -a
        source "$PROJECT_ROOT/.env"
        set +a
    else
        log_warn "No .env file found. Using defaults."
    fi
}

# Join ZeroTier network
join_zerotier() {
    if [ -z "${ZEROTIER_NETWORK_ID:-}" ]; then
        log_warn "ZEROTIER_NETWORK_ID not set. Skipping ZeroTier join."
        return 0
    fi

    log_info "Joining ZeroTier network: $ZEROTIER_NETWORK_ID"
    zerotier-cli join "$ZEROTIER_NETWORK_ID"
    log_info "ZeroTier join command executed. Node must be authorized on ZeroTier Central."
}

# Join Tailscale
join_tailscale() {
    if [ -z "${TAILSCALE_AUTH_KEY:-}" ]; then
        log_warn "TAILSCALE_AUTH_KEY not set. Skipping Tailscale join."
        return 0
    fi

    log_info "Joining Tailscale network..."
    tailscale up --authkey="$TAILSCALE_AUTH_KEY" --accept-routes
    log_info "Tailscale configured successfully"
}

# Join Docker Swarm
join_swarm() {
    if [ -z "${SWARM_JOIN_TOKEN:-}" ] || [ -z "${SWARM_MANAGER_IP:-}" ]; then
        log_warn "SWARM_JOIN_TOKEN or SWARM_MANAGER_IP not set. Skipping swarm join."
        log_warn "Run scripts/swarm-join.sh manually after configuration."
        return 0
    fi

    log_info "Joining Docker Swarm..."
    "$SCRIPT_DIR/swarm-join.sh"
}

# Install telemetry service
install_telemetry() {
    log_info "Installing telemetry service..."

    # Make telemetry script executable
    chmod +x "$SCRIPT_DIR/telemetry.sh"

    # Create systemd service
    cat > /etc/systemd/system/pr-cybr-telemetry.service <<EOF
[Unit]
Description=PR-CYBR Node Telemetry
After=network.target docker.service

[Service]
Type=simple
ExecStart=$SCRIPT_DIR/telemetry.sh
Restart=always
RestartSec=60
EnvironmentFile=/etc/pr-cybr/telemetry.conf

[Install]
WantedBy=multi-user.target
EOF

    # Create telemetry configuration
    cat > /etc/pr-cybr/telemetry.conf <<EOF
MGMT_NODE_URL=${MGMT_NODE_URL:-https://mgmt.pr-cybr.local}
TELEMETRY_INTERVAL=${TELEMETRY_INTERVAL:-60}
NODE_ID=${NODE_NAME:-node-$(hostname)}
API_TOKEN=${API_TOKEN:-}
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable pr-cybr-telemetry
    systemctl start pr-cybr-telemetry

    log_info "Telemetry service installed and started"
}

# Register with management node
register_node() {
    if [ -z "${MGMT_NODE_URL:-}" ] || [ -z "${API_TOKEN:-}" ]; then
        log_warn "MGMT_NODE_URL or API_TOKEN not set. Skipping node registration."
        return 0
    fi

    log_info "Registering node with management node..."

    NODE_ID="${NODE_NAME:-node-$(hostname)}"
    
    curl -X POST "$MGMT_NODE_URL/api/nodes/register" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"node_id\": \"$NODE_ID\",
            \"architecture\": \"$NODE_ARCH\",
            \"hostname\": \"$(hostname)\",
            \"ip_address\": \"$(hostname -I | awk '{print $1}')\"
        }" || log_warn "Node registration failed. Will retry later."
}

# Main installation flow
main() {
    log_info "Starting PR-CYBR-N0D3 installation..."

    check_root
    detect_arch
    load_config

    install_docker
    install_zerotier
    install_tailscale

    configure_system

    join_zerotier
    join_tailscale
    join_swarm

    install_telemetry
    register_node

    log_info "Installation complete!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Authorize node on ZeroTier Central (if using ZeroTier)"
    log_info "2. Verify swarm membership: docker node ls"
    log_info "3. Check telemetry: systemctl status pr-cybr-telemetry"
    log_info "4. View logs: journalctl -u pr-cybr-telemetry -f"
}

main "$@"
