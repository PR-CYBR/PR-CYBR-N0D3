# SOP-005: Troubleshooting Guide

## Common Issues and Solutions

### Docker Issues

#### Issue: Docker daemon not running

```bash
# Start Docker
sudo systemctl start docker

# Check status
sudo systemctl status docker

# Enable on boot
sudo systemctl enable docker
```

#### Issue: Permission denied accessing Docker socket

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Re-login or use newgrp
newgrp docker
```

### Swarm Issues

#### Issue: Cannot join swarm

```bash
# Verify network connectivity
ping <manager-ip>
telnet <manager-ip> 2377

# Check firewall rules
sudo ufw status
```

#### Issue: Node appears as "Down"

```bash
# Restart Docker
sudo systemctl restart docker

# Rejoin swarm
docker swarm leave --force
./scripts/swarm-join.sh
```

### Network Issues

#### Issue: ZeroTier not connecting

```bash
# Restart ZeroTier
sudo systemctl restart zerotier-one

# Check authorization
sudo zerotier-cli listnetworks

# View logs
sudo journalctl -u zerotier-one -n 50
```

#### Issue: Tailscale authentication fails

```bash
# Re-authenticate
sudo tailscale down
sudo tailscale up --authkey=<NEW_KEY>
```

### Service Issues

#### Issue: Service not starting

```bash
# Check service logs
docker service logs <service-name>

# Inspect service
docker service inspect <service-name>

# Check constraints
docker service ps <service-name>
```

## Diagnostic Commands

```bash
# System information
docker info
docker version

# Network diagnostics
docker network ls
ip addr show
ss -tulpn

# Service diagnostics
docker service ls
docker stack ls
docker node ls

# Resource usage
docker stats
df -h
free -h
```

## Log Locations

- Docker logs: `journalctl -u docker`
- ZeroTier logs: `journalctl -u zerotier-one`
- Tailscale logs: `journalctl -u tailscaled`
- Telemetry logs: `journalctl -u pr-cybr-telemetry`
- System logs: `/var/log/syslog`

## Status

Status: Active
Version: 1.0
Last Updated: 2025-10-26
