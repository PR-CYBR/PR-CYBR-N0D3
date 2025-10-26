#!/bin/bash
set -euo pipefail

# PR-CYBR-N0D3 Setup Script
# Main entry point for node installation and configuration
# Usage: sudo ./setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
print_banner() {
    echo -e "${CYAN}"
    cat <<'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                    PR-CYBR-N0D3 Setup                        ║
║                                                               ║
║          Dynamic Client Node for PR-CYBR Distributed         ║
║                      Architecture                             ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root or with sudo"
        echo ""
        echo "Usage: sudo ./setup.sh"
        exit 1
    fi
}

# Display welcome message and requirements
show_welcome() {
    print_banner
    echo ""
    log_info "Welcome to PR-CYBR-N0D3 setup!"
    echo ""
    echo "This script will:"
    echo "  1. Check system prerequisites"
    echo "  2. Configure environment variables"
    echo "  3. Install Docker and dependencies"
    echo "  4. Set up network overlays (ZeroTier, Tailscale)"
    echo "  5. Join Docker Swarm cluster"
    echo "  6. Install telemetry service"
    echo "  7. Register node with management system"
    echo ""
    log_warn "Prerequisites:"
    echo "  - Ubuntu/Debian-based Linux system"
    echo "  - Network connectivity to management node"
    echo "  - Required credentials (will be prompted)"
    echo ""
    
    read -p "Continue with setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled by user"
        exit 0
    fi
}

# Check system compatibility
check_system() {
    log_step "Checking system compatibility..."
    
    # Check OS
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot determine OS type"
        exit 1
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log_warn "This script is optimized for Ubuntu/Debian"
        log_warn "Detected OS: $ID"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    log_success "OS: $PRETTY_NAME"
    
    # Check architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            log_success "Architecture: AMD64"
            ;;
        aarch64|arm64)
            log_success "Architecture: ARM64"
            ;;
        armv7l)
            log_success "Architecture: ARMv7"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Check network connectivity
    if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        log_error "No internet connectivity detected"
        exit 1
    fi
    log_success "Internet connectivity: OK"
}

# Configure environment
configure_environment() {
    log_step "Configuring environment..."
    
    # Check if .env already exists
    if [ -f "$SCRIPT_DIR/.env" ]; then
        log_info "Found existing .env file"
        read -p "Use existing configuration? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            log_success "Using existing .env configuration"
            return 0
        fi
    fi
    
    # Copy template
    if [ ! -f "$SCRIPT_DIR/.env.example" ]; then
        log_error ".env.example template not found"
        exit 1
    fi
    
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    log_info "Created .env from template"
    
    echo ""
    log_info "Configuration options:"
    echo "  1. Interactive configuration (recommended)"
    echo "  2. Manual configuration (edit .env file)"
    echo "  3. Skip configuration (use defaults)"
    echo ""
    read -p "Select option (1-3): " -n 1 -r CONFIG_OPTION
    echo
    
    case $CONFIG_OPTION in
        1)
            configure_interactive
            ;;
        2)
            log_info "Please edit $SCRIPT_DIR/.env manually"
            log_info "Press Enter when ready to continue..."
            read
            ;;
        3)
            log_warn "Using default configuration values"
            log_warn "You may need to reconfigure later for full functionality"
            ;;
        *)
            log_warn "Invalid option. Using defaults."
            ;;
    esac
    
    log_success "Environment configuration complete"
}

# Interactive configuration
configure_interactive() {
    echo ""
    log_info "Interactive Configuration"
    echo ""
    
    # Node name
    DEFAULT_NODE_NAME="node-$(hostname)"
    read -p "Node name [$DEFAULT_NODE_NAME]: " NODE_NAME
    NODE_NAME=${NODE_NAME:-$DEFAULT_NODE_NAME}
    sed -i "s/NODE_NAME=.*/NODE_NAME=$NODE_NAME/" "$SCRIPT_DIR/.env"
    
    # Docker Swarm configuration
    echo ""
    log_info "Docker Swarm Configuration"
    read -p "Do you have Docker Swarm credentials? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Swarm join token: " SWARM_TOKEN
        read -p "Swarm manager IP: " SWARM_IP
        sed -i "s|SWARM_JOIN_TOKEN=.*|SWARM_JOIN_TOKEN=$SWARM_TOKEN|" "$SCRIPT_DIR/.env"
        sed -i "s|SWARM_MANAGER_IP=.*|SWARM_MANAGER_IP=$SWARM_IP|" "$SCRIPT_DIR/.env"
        log_success "Swarm configuration saved"
    else
        log_warn "Swarm join will be skipped. Configure later if needed."
    fi
    
    # ZeroTier configuration
    echo ""
    log_info "ZeroTier Configuration"
    read -p "Do you have ZeroTier credentials? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "ZeroTier Network ID: " ZT_NETWORK_ID
        read -p "ZeroTier API Token (optional): " ZT_API_TOKEN
        sed -i "s|ZEROTIER_NETWORK_ID=.*|ZEROTIER_NETWORK_ID=$ZT_NETWORK_ID|" "$SCRIPT_DIR/.env"
        if [ -n "$ZT_API_TOKEN" ]; then
            sed -i "s|ZEROTIER_API_TOKEN=.*|ZEROTIER_API_TOKEN=$ZT_API_TOKEN|" "$SCRIPT_DIR/.env"
        fi
        log_success "ZeroTier configuration saved"
    else
        log_warn "ZeroTier setup will be skipped. Configure later if needed."
    fi
    
    # Tailscale configuration
    echo ""
    log_info "Tailscale Configuration"
    read -p "Do you have a Tailscale auth key? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Tailscale Auth Key: " TS_AUTH_KEY
        sed -i "s|TAILSCALE_AUTH_KEY=.*|TAILSCALE_AUTH_KEY=$TS_AUTH_KEY|" "$SCRIPT_DIR/.env"
        log_success "Tailscale configuration saved"
    else
        log_warn "Tailscale setup will be skipped. Configure later if needed."
    fi
    
    # Management node configuration
    echo ""
    log_info "Management Node Configuration"
    read -p "Do you have management node credentials? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Management Node URL: " MGMT_URL
        read -p "API Token: " API_TOKEN
        sed -i "s|MGMT_NODE_URL=.*|MGMT_NODE_URL=$MGMT_URL|" "$SCRIPT_DIR/.env"
        sed -i "s|API_TOKEN=.*|API_TOKEN=$API_TOKEN|" "$SCRIPT_DIR/.env"
        log_success "Management node configuration saved"
    else
        log_warn "Management node registration will be skipped."
    fi
    
    echo ""
    log_success "Interactive configuration complete"
}

# Make scripts executable
prepare_scripts() {
    log_step "Preparing scripts..."
    
    chmod +x "$SCRIPT_DIR/scripts/"*.sh
    
    log_success "Scripts are executable"
}

# Run installation
run_installation() {
    log_step "Starting installation..."
    echo ""
    
    if [ ! -f "$SCRIPT_DIR/scripts/install.sh" ]; then
        log_error "Installation script not found: scripts/install.sh"
        exit 1
    fi
    
    # Run the main installation script
    "$SCRIPT_DIR/scripts/install.sh"
}

# Post-installation summary
show_summary() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Installation Complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    log_info "Node Information:"
    echo "  - Node Name: $(grep NODE_NAME "$SCRIPT_DIR/.env" | cut -d= -f2 || echo 'Not configured')"
    echo "  - Architecture: $(uname -m)"
    echo "  - Hostname: $(hostname)"
    echo ""
    
    log_info "Services Status:"
    
    # Check Docker
    if systemctl is-active --quiet docker; then
        echo -e "  ${GREEN}✓${NC} Docker: Running"
    else
        echo -e "  ${RED}✗${NC} Docker: Not running"
    fi
    
    # Check ZeroTier
    if command -v zerotier-cli &> /dev/null; then
        if systemctl is-active --quiet zerotier-one; then
            echo -e "  ${GREEN}✓${NC} ZeroTier: Installed and running"
        else
            echo -e "  ${YELLOW}!${NC} ZeroTier: Installed but not running"
        fi
    else
        echo -e "  ${YELLOW}!${NC} ZeroTier: Not installed"
    fi
    
    # Check Tailscale
    if command -v tailscale &> /dev/null; then
        if systemctl is-active --quiet tailscaled; then
            echo -e "  ${GREEN}✓${NC} Tailscale: Installed and running"
        else
            echo -e "  ${YELLOW}!${NC} Tailscale: Installed but not running"
        fi
    else
        echo -e "  ${YELLOW}!${NC} Tailscale: Not installed"
    fi
    
    # Check Telemetry
    if systemctl is-active --quiet pr-cybr-telemetry; then
        echo -e "  ${GREEN}✓${NC} Telemetry: Running"
    else
        echo -e "  ${YELLOW}!${NC} Telemetry: Not running"
    fi
    
    # Check Swarm status
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        echo -e "  ${GREEN}✓${NC} Docker Swarm: Active"
    else
        echo -e "  ${YELLOW}!${NC} Docker Swarm: Inactive"
    fi
    
    echo ""
    log_info "Next Steps:"
    echo ""
    echo "  1. Verify Services:"
    echo "     docker info | grep Swarm"
    echo "     systemctl status pr-cybr-telemetry"
    echo ""
    echo "  2. Authorize Node (if using ZeroTier):"
    echo "     Visit https://my.zerotier.com and authorize this node"
    echo ""
    echo "  3. Check Telemetry:"
    echo "     journalctl -u pr-cybr-telemetry -f"
    echo ""
    echo "  4. Deploy Services (if in swarm):"
    echo "     docker service ls"
    echo ""
    echo "  5. Review Documentation:"
    echo "     See .specify/tasks/ for Standard Operating Procedures"
    echo ""
    
    log_info "Configuration file: $SCRIPT_DIR/.env"
    log_info "Logs directory: /var/log/pr-cybr/"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Main execution flow
main() {
    # Check root
    check_root
    
    # Show welcome
    show_welcome
    
    # Check system
    check_system
    
    # Configure environment
    configure_environment
    
    # Prepare scripts
    prepare_scripts
    
    # Run installation
    run_installation
    
    # Show summary
    show_summary
    
    log_success "Setup complete! Your PR-CYBR-N0D3 node is ready."
}

# Error handler
trap 'log_error "Setup failed at line $LINENO. Check the output above for details."; exit 1' ERR

# Run main
main "$@"
