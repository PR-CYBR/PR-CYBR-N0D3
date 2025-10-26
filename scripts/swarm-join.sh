#!/bin/bash
set -euo pipefail

# PR-CYBR-N0D3 Swarm Join Script
# Automates joining Docker Swarm cluster

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! systemctl is-active --quiet docker; then
        log_error "Docker service is not running"
        exit 1
    fi

    log_info "Docker is installed and running"
}

# Check if already in swarm
check_swarm_status() {
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        log_warn "Node is already part of a swarm"
        
        # Check if this is the same swarm
        CURRENT_MANAGER=$(docker info 2>/dev/null | grep "Manager Addresses" | awk '{print $3}' || echo "")
        
        if [ -n "$CURRENT_MANAGER" ]; then
            log_info "Current swarm manager: $CURRENT_MANAGER"
            read -p "Leave current swarm and rejoin? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Leaving current swarm..."
                docker swarm leave --force
            else
                log_info "Keeping current swarm membership"
                exit 0
            fi
        fi
    fi
}

# Validate required environment variables
validate_config() {
    if [ -z "${SWARM_JOIN_TOKEN:-}" ]; then
        log_error "SWARM_JOIN_TOKEN is not set"
        log_error "Set it in .env file or export it: export SWARM_JOIN_TOKEN=SWMTKN-1-xxxx"
        exit 1
    fi

    if [ -z "${SWARM_MANAGER_IP:-}" ]; then
        log_error "SWARM_MANAGER_IP is not set"
        log_error "Set it in .env file or export it: export SWARM_MANAGER_IP=10.147.x.x"
        exit 1
    fi

    log_info "Configuration validated"
}

# Test connectivity to manager
test_connectivity() {
    log_info "Testing connectivity to manager: $SWARM_MANAGER_IP:2377"
    
    if ! nc -z -w5 "$SWARM_MANAGER_IP" 2377 2>/dev/null; then
        log_error "Cannot reach swarm manager at $SWARM_MANAGER_IP:2377"
        log_error "Check network connectivity and firewall rules"
        exit 1
    fi

    log_info "Manager is reachable"
}

# Join swarm
join_swarm() {
    log_info "Joining Docker Swarm..."
    log_info "Manager: $SWARM_MANAGER_IP:2377"

    if docker swarm join \
        --token "$SWARM_JOIN_TOKEN" \
        "$SWARM_MANAGER_IP:2377"; then
        log_info "Successfully joined swarm!"
        return 0
    else
        log_error "Failed to join swarm"
        return 1
    fi
}

# Verify swarm membership
verify_membership() {
    log_info "Verifying swarm membership..."

    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        log_info "Node is active in swarm"
        
        # Get node info
        NODE_ID=$(docker info 2>/dev/null | grep "NodeID:" | awk '{print $2}')
        NODE_ROLE=$(docker info 2>/dev/null | grep "Is Manager:" | awk '{print $3}')
        
        log_info "Node ID: $NODE_ID"
        log_info "Manager: $NODE_ROLE"
        
        # List overlay networks
        log_info "Available overlay networks:"
        docker network ls --filter driver=overlay --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
        
        return 0
    else
        log_error "Node is not in swarm after join attempt"
        return 1
    fi
}

# Configure firewall rules
configure_firewall() {
    if ! command -v ufw &> /dev/null; then
        log_warn "UFW not installed, skipping firewall configuration"
        return 0
    fi

    log_info "Configuring firewall rules for Docker Swarm..."

    # Docker Swarm ports
    ufw allow 2377/tcp comment 'Docker Swarm - Cluster management'
    ufw allow 7946/tcp comment 'Docker Swarm - Node communication'
    ufw allow 7946/udp comment 'Docker Swarm - Node communication'
    ufw allow 4789/udp comment 'Docker Swarm - Overlay network'

    log_info "Firewall rules configured"
}

# Main execution
main() {
    log_info "Starting Docker Swarm join process..."

    # Load environment from .env if it exists
    if [ -f .env ]; then
        log_info "Loading configuration from .env"
        set -a
        source .env
        set +a
    fi

    check_docker
    check_swarm_status
    validate_config
    test_connectivity
    configure_firewall

    if join_swarm; then
        verify_membership
        log_info "Swarm join complete!"
        log_info ""
        log_info "Next steps:"
        log_info "1. Deploy services: docker stack deploy -c stack.yml myapp"
        log_info "2. List services: docker service ls"
        log_info "3. View nodes: docker node ls (requires manager access)"
    else
        log_error "Swarm join failed"
        exit 1
    fi
}

main "$@"
