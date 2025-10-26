# SOP-001: Node Deployment

## Objective

Deploy a new PR-CYBR-N0D3 client node to join the distributed infrastructure.

## Prerequisites

- Host system with Docker support
- Network connectivity to management node
- Required credentials and tokens:
  - Swarm join token
  - ZeroTier network ID and API token
  - Tailscale auth key
  - Registry credentials

## Deployment Steps

### 1. Prepare Host System

```bash
# Update system packages
sudo apt-get update && sudo apt-get upgrade -y

# Install required dependencies
sudo apt-get install -y curl git docker.io

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker
```

### 2. Clone Repository

```bash
git clone https://github.com/PR-CYBR/PR-CYBR-N0D3.git
cd PR-CYBR-N0D3
```

### 3. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env with required credentials
nano .env
```

Required environment variables:
- `SWARM_JOIN_TOKEN`: Docker Swarm join token
- `SWARM_MANAGER_IP`: Manager node IP address
- `ZEROTIER_NETWORK_ID`: ZeroTier network ID
- `ZEROTIER_API_TOKEN`: ZeroTier API token
- `TAILSCALE_AUTH_KEY`: Tailscale authentication key
- `MGMT_NODE_URL`: Management node URL
- `NODE_NAME`: Unique identifier for this node

### 4. Run Installation Script

```bash
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

The installation script will:
- Detect host architecture
- Install additional dependencies
- Configure network overlays
- Set up system services
- Register with management node

### 5. Verify Installation

```bash
# Check Docker status
docker info

# Verify swarm membership
docker node ls

# Check network overlays
docker network ls | grep overlay

# Verify services
docker service ls
```

### 6. Enable Telemetry

```bash
# Start telemetry service
sudo systemctl start pr-cybr-telemetry
sudo systemctl enable pr-cybr-telemetry

# Check telemetry status
sudo systemctl status pr-cybr-telemetry
```

## Verification Checklist

- [ ] Docker is installed and running
- [ ] Node has joined Docker Swarm
- [ ] ZeroTier network is active
- [ ] Tailscale is connected
- [ ] Traefik is routing traffic
- [ ] Telemetry is reporting to management node
- [ ] Node appears in codex registry

## Troubleshooting

### Issue: Installation script fails

**Solution**: Check system logs
```bash
sudo journalctl -xe
```

### Issue: Cannot join swarm

**Solution**: Verify manager node connectivity and token
```bash
# Test connectivity
ping <SWARM_MANAGER_IP>

# Verify token is correct
echo $SWARM_JOIN_TOKEN
```

### Issue: Network overlay not working

**Solution**: Check ZeroTier/Tailscale status
```bash
# ZeroTier
sudo zerotier-cli status
sudo zerotier-cli listnetworks

# Tailscale
sudo tailscale status
```

## Rollback Procedure

If deployment fails:

```bash
# Leave swarm
docker swarm leave --force

# Stop services
sudo systemctl stop pr-cybr-*

# Remove configurations
sudo rm -rf /etc/pr-cybr
```

## Post-Deployment Tasks

- [ ] Document node in inventory
- [ ] Update monitoring dashboards
- [ ] Configure backup schedules
- [ ] Set up alerting rules

## References

- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [ZeroTier Documentation](https://docs.zerotier.com/)
- [Tailscale Documentation](https://tailscale.com/kb/)

## Status

Status: Active
Version: 1.0
Last Updated: 2025-10-26
