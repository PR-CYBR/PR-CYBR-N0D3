# PR-CYBR-N0D3

[![Spec-Kit Validation](https://github.com/PR-CYBR/PR-CYBR-N0D3/actions/workflows/spec-kit.yml/badge.svg)](https://github.com/PR-CYBR/PR-CYBR-N0D3/actions/workflows/spec-kit.yml)

Dynamic client node for PR-CYBR distributed architecture. Automates swarm join, resource profiling, telemetry, and edge operations under PR-CYBR-MGMT-N0D3. Includes SOP bootstrap, multi-arch build pipelines, Terraform Cloud bridge, and secure networking (ZeroTier, Tailscale, Traefik). Designed for autonomous deployment and adaptive orchestration.

## Features

- **Autonomous Swarm Participation**: Automatic Docker Swarm join with minimal configuration
- **Multi-Architecture Support**: Native builds for AMD64, ARM64, and ARMv7
- **Secure Networking**: Integrated ZeroTier and Tailscale overlay networks
- **Intelligent Routing**: Traefik reverse proxy with automatic SSL/TLS
- **Comprehensive Telemetry**: Real-time metrics and monitoring
- **Infrastructure as Code**: Terraform Cloud integration
- **Spec-Driven Development**: Complete specification and planning framework

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              PR-CYBR-MGMT-N0D3                      │
│          (Management & Coordination)                │
└────────────────────┬────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
     ┌────▼─────┐        ┌─────▼────┐
     │ZeroTier  │        │Tailscale │
     │ Overlay  │        │   Mesh   │
     └────┬─────┘        └─────┬────┘
          │                    │
     ┌────▼────────────────────▼────┐
     │    PR-CYBR-N0D3 Clients      │
     │  (Distributed Worker Nodes)  │
     └──────────────────────────────┘
```

## Quick Start

### Prerequisites

- Host system with Docker support
- Network connectivity to management node
- Required credentials:
  - Swarm join token
  - ZeroTier network ID
  - Tailscale auth key

### Installation

**Simple 2-Step Process:**

1. **Clone the repository**

```bash
git clone https://github.com/PR-CYBR/PR-CYBR-N0D3.git
cd PR-CYBR-N0D3
```

2. **Run the setup script**

```bash
sudo ./setup.sh
```

The setup script will:
- Check system compatibility
- Guide you through configuration (interactive or manual)
- Detect your system architecture
- Install Docker and dependencies
- Set up network overlays (ZeroTier, Tailscale)
- Join the Docker Swarm
- Start telemetry service
- Register with management node

**Advanced Installation Options:**

For manual configuration or scripted deployments:

```bash
# Copy and edit environment file
cp .env.example .env
nano .env

# Run individual installation script
sudo ./scripts/install.sh
```

### Verification

```bash
# Check Docker Swarm status
docker info | grep Swarm

# Verify network overlays
docker network ls | grep overlay

# Check telemetry service
sudo systemctl status pr-cybr-telemetry

# View logs
sudo journalctl -u pr-cybr-telemetry -f
```

## Directory Structure

```
PR-CYBR-N0D3/
├── .github/
│   └── workflows/          # CI/CD workflows
├── .specify/
│   ├── constitution.md     # Project principles
│   ├── spec.md            # Technical specifications
│   ├── plan.md            # Implementation plan
│   └── tasks/             # SOPs and procedures
├── configs/
│   ├── zerotier/          # ZeroTier configuration
│   ├── tailscale/         # Tailscale configuration
│   └── traefik/           # Traefik configuration
├── scripts/
│   ├── install.sh         # Node installation
│   ├── swarm-join.sh      # Swarm orchestration
│   ├── telemetry.sh       # Telemetry collection
│   ├── build-arm.sh       # ARM builds
│   └── build-amd.sh       # AMD builds
├── setup.sh               # Main setup script (start here!)
├── codex.yaml             # Codex registry entry
├── BRANCHING.md           # Branching strategy
├── LICENSE                # MIT License
└── README.md              # This file
```

## Documentation

### Standard Operating Procedures

- [SOP-001: Node Deployment](.specify/tasks/SOP-001-node-deployment.md)
- [SOP-002: Swarm Join Process](.specify/tasks/SOP-002-swarm-join.md)
- [SOP-003: Network Configuration](.specify/tasks/SOP-003-network-configuration.md)
- [SOP-004: Telemetry Setup](.specify/tasks/SOP-004-telemetry-setup.md)
- [SOP-005: Troubleshooting Guide](.specify/tasks/SOP-005-troubleshooting.md)

### Specifications

- [Constitution](.specify/constitution.md) - Project principles and governance
- [Specification](.specify/spec.md) - Technical specifications
- [Implementation Plan](.specify/plan.md) - Development roadmap
- [Branching Strategy](BRANCHING.md) - Git workflow

## Configuration

### Environment Variables

Create a `.env` file with the following variables:

```bash
# Docker Swarm
SWARM_JOIN_TOKEN=SWMTKN-1-xxxxx
SWARM_MANAGER_IP=10.147.x.x

# ZeroTier
ZEROTIER_NETWORK_ID=your_network_id
ZEROTIER_API_TOKEN=your_api_token

# Tailscale
TAILSCALE_AUTH_KEY=tskey-auth-xxxxx

# Management Node
MGMT_NODE_URL=https://mgmt.pr-cybr.local
API_TOKEN=your_api_token

# Node Identity
NODE_NAME=node-$(hostname)

# Telemetry
TELEMETRY_INTERVAL=60
```

## Multi-Architecture Builds

Build for specific architectures:

```bash
# Build for ARM
./scripts/build-arm.sh

# Build for AMD64
./scripts/build-amd.sh
```

## Integration

### PR-CYBR-MGMT-N0D3

This client node coordinates with [PR-CYBR-MGMT-N0D3](https://github.com/PR-CYBR/PR-CYBR-MGMT-N0D3) for:
- Node registration and discovery
- Configuration distribution
- Orchestration commands
- Telemetry aggregation

### Terraform Cloud

Infrastructure state is synchronized with Terraform Cloud:
- Workspace: `pr-cybr-n0d3`
- Remote state for coordination
- Automated provisioning workflows

## Development

### Branching Strategy

This repository implements a comprehensive branching scheme:

- `spec` → `plan` → `impl` → `dev` → `main` → `stage` → `prod`
- See [BRANCHING.md](BRANCHING.md) for complete documentation

### Workflows

- **Lint**: Code and documentation linting
- **Test**: Unit and integration tests
- **Build**: Docker image builds
- **Build Multi-Arch**: Cross-platform builds
- **TFC Sync**: Terraform Cloud synchronization

## Security

- All secrets managed via environment variables or secret stores
- Encrypted overlay networks (ZeroTier, Tailscale)
- TLS/SSL for all external services
- Regular security updates via automated workflows

## Contributing

1. Review the [Constitution](.specify/constitution.md)
2. Check the [Specification](.specify/spec.md)
3. Follow the branching strategy in [BRANCHING.md](BRANCHING.md)
4. Ensure all tests pass
5. Submit pull request

## Troubleshooting

See [SOP-005: Troubleshooting Guide](.specify/tasks/SOP-005-troubleshooting.md) for common issues and solutions.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- Issues: [GitHub Issues](https://github.com/PR-CYBR/PR-CYBR-N0D3/issues)
- Documentation: [GitHub Pages](https://pr-cybr.github.io/PR-CYBR-N0D3)
- Contact: team@pr-cybr.com
