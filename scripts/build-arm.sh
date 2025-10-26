#!/bin/bash
set -euo pipefail

# PR-CYBR-N0D3 ARM Build Script
# Builds Docker images for ARM architectures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Configuration
REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_NAME="${IMAGE_NAME:-pr-cybr/pr-cybr-n0d3}"
VERSION="${VERSION:-latest}"
ARM_PLATFORMS="linux/arm64,linux/arm/v7"

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    # Check if buildx is available
    if ! docker buildx version &> /dev/null; then
        log_error "Docker buildx is not available"
        log_error "Install with: docker buildx install"
        exit 1
    fi

    log_info "Prerequisites satisfied"
}

# Setup buildx builder
setup_builder() {
    log_info "Setting up buildx builder..."

    # Create or use existing builder
    if ! docker buildx inspect pr-cybr-builder &> /dev/null; then
        log_info "Creating new builder: pr-cybr-builder"
        docker buildx create --name pr-cybr-builder --use
    else
        log_info "Using existing builder: pr-cybr-builder"
        docker buildx use pr-cybr-builder
    fi

    # Bootstrap the builder
    log_info "Bootstrapping builder..."
    docker buildx inspect --bootstrap

    log_info "Builder ready"
}

# Build ARM images
build_arm() {
    log_info "Building ARM images..."
    log_info "Platforms: $ARM_PLATFORMS"
    log_info "Image: $REGISTRY/$IMAGE_NAME:$VERSION-arm"

    cd "$PROJECT_ROOT"

    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        log_warn "No Dockerfile found, creating basic Dockerfile..."
        create_dockerfile
    fi

    # Build multi-platform ARM images
    docker buildx build \
        --platform "$ARM_PLATFORMS" \
        --tag "$REGISTRY/$IMAGE_NAME:$VERSION-arm" \
        --tag "$REGISTRY/$IMAGE_NAME:$VERSION-arm64" \
        --push \
        .

    log_info "ARM build complete!"
}

# Create a basic Dockerfile if none exists
create_dockerfile() {
    cat > Dockerfile <<'EOF'
FROM alpine:latest

# Install basic utilities
RUN apk add --no-cache \
    bash \
    curl \
    docker-cli \
    jq \
    netcat-openbsd

# Copy scripts
COPY scripts/ /usr/local/bin/

# Make scripts executable
RUN chmod +x /usr/local/bin/*.sh

# Set working directory
WORKDIR /opt/pr-cybr

CMD ["/bin/bash"]
EOF
    log_info "Created basic Dockerfile"
}

# Test ARM images (if running on ARM)
test_arm() {
    log_info "Testing ARM image..."

    CURRENT_ARCH=$(uname -m)
    
    if [[ "$CURRENT_ARCH" =~ ^(aarch64|arm64|armv7l)$ ]]; then
        log_info "Running on ARM architecture, testing locally..."
        
        docker run --rm "$REGISTRY/$IMAGE_NAME:$VERSION-arm" \
            /usr/local/bin/telemetry.sh --test || {
            log_error "ARM image test failed"
            exit 1
        }
        
        log_info "ARM image test passed"
    else
        log_warn "Not running on ARM architecture, skipping local test"
        log_info "ARM images can be tested on ARM hardware"
    fi
}

# Main execution
main() {
    log_info "Starting ARM build process..."

    check_prerequisites
    setup_builder
    build_arm

    # Test if on ARM platform
    if [[ "$(uname -m)" =~ ^(aarch64|arm64|armv7l)$ ]]; then
        test_arm
    fi

    log_info "ARM build process complete!"
    log_info ""
    log_info "Built images:"
    log_info "  - $REGISTRY/$IMAGE_NAME:$VERSION-arm"
    log_info "  - $REGISTRY/$IMAGE_NAME:$VERSION-arm64"
}

main "$@"
