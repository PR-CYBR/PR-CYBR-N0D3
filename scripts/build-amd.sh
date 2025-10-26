#!/bin/bash
set -euo pipefail

# PR-CYBR-N0D3 AMD Build Script
# Builds Docker images for AMD64 architecture

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
AMD_PLATFORM="linux/amd64"

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

# Build AMD64 images
build_amd() {
    log_info "Building AMD64 images..."
    log_info "Platform: $AMD_PLATFORM"
    log_info "Image: $REGISTRY/$IMAGE_NAME:$VERSION-amd64"

    cd "$PROJECT_ROOT"

    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        log_warn "No Dockerfile found, creating basic Dockerfile..."
        create_dockerfile
    fi

    # Build AMD64 image
    docker buildx build \
        --platform "$AMD_PLATFORM" \
        --tag "$REGISTRY/$IMAGE_NAME:$VERSION-amd64" \
        --tag "$REGISTRY/$IMAGE_NAME:$VERSION" \
        --push \
        .

    log_info "AMD64 build complete!"
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

# Test AMD64 image
test_amd() {
    log_info "Testing AMD64 image..."

    docker run --rm "$REGISTRY/$IMAGE_NAME:$VERSION-amd64" \
        /usr/local/bin/telemetry.sh --test || {
        log_error "AMD64 image test failed"
        exit 1
    }
    
    log_info "AMD64 image test passed"
}

# Main execution
main() {
    log_info "Starting AMD64 build process..."

    check_prerequisites
    setup_builder
    build_amd

    # Test if on AMD64 platform
    if [ "$(uname -m)" = "x86_64" ]; then
        test_amd
    fi

    log_info "AMD64 build process complete!"
    log_info ""
    log_info "Built images:"
    log_info "  - $REGISTRY/$IMAGE_NAME:$VERSION-amd64"
    log_info "  - $REGISTRY/$IMAGE_NAME:$VERSION (latest)"
}

main "$@"
