# SOP-003: Network Configuration

## Objective

Configure secure overlay networks using ZeroTier, Tailscale, and Traefik for PR-CYBR-N0D3 nodes.

## Network Architecture

```
┌─────────────────────────────────────────────┐
│           Public Internet                    │
└─────────────────────────────────────────────┘
                    │
         ┌──────────┴──────────┐
         │                     │
    ┌────▼─────┐        ┌─────▼────┐
    │ ZeroTier │        │Tailscale │
    │ Overlay  │        │   Mesh   │
    └────┬─────┘        └─────┬────┘
         │                    │
    ┌────▼────────────────────▼────┐
    │      Docker Overlay Networks │
    └────┬────────────────────┬────┘
         │                    │
    ┌────▼────┐          ┌────▼────┐
    │ Traefik │          │Services │
    │  Proxy  │          │         │
    └─────────┘          └─────────┘
```

## ZeroTier Configuration

### Installation

```bash
# Install ZeroTier
curl -s https://install.zerotier.com | sudo bash

# Start ZeroTier service
sudo systemctl start zerotier-one
sudo systemctl enable zerotier-one
```

### Network Join

```bash
# Join ZeroTier network
sudo zerotier-cli join <NETWORK_ID>

# Authorize node (on ZeroTier Central or via API)
# The node must be authorized before it can communicate
```

### Verification

```bash
# Check ZeroTier status
sudo zerotier-cli status

# List networks
sudo zerotier-cli listnetworks

# Show peers
sudo zerotier-cli listpeers
```

### Configuration File

Location: `configs/zerotier/network.conf`

```yaml
network_id: "<NETWORK_ID>"
auto_join: true
allow_managed: true
allow_global: false
allow_default: false
```

## Tailscale Configuration

### Installation

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale
sudo systemctl start tailscaled
sudo systemctl enable tailscaled
```

### Authentication

```bash
# Authenticate with auth key (non-interactive)
sudo tailscale up --authkey=<AUTH_KEY> --accept-routes

# Or authenticate interactively
sudo tailscale up
```

### Verification

```bash
# Check Tailscale status
sudo tailscale status

# Show IP address
sudo tailscale ip

# Test connectivity to peer
ping $(tailscale ip -4 <peer-hostname>)
```

### Configuration File

Location: `configs/tailscale/tailscale.conf`

```yaml
authkey: "<AUTH_KEY>"
accept_routes: true
accept_dns: true
hostname: "pr-cybr-n0d3-{{ node_id }}"
advertise_routes: []
```

## Traefik Configuration

### Static Configuration

Location: `configs/traefik/traefik.yml`

```yaml
# Entry points
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

# Certificate resolver
certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@pr-cybr.com
      storage: /etc/traefik/acme.json
      httpChallenge:
        entryPoint: web

# Providers
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik-public
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

# API and dashboard
api:
  dashboard: true
  insecure: false

# Logging
log:
  level: INFO
  format: json

# Access logs
accessLog:
  format: json
  fields:
    headers:
      defaultMode: keep

# Metrics
metrics:
  prometheus:
    entryPoint: metrics
```

### Dynamic Configuration

Location: `configs/traefik/dynamic.yml`

```yaml
http:
  routers:
    # API router
    api:
      rule: "Host(`traefik.pr-cybr.local`)"
      service: api@internal
      middlewares:
        - auth
      tls:
        certResolver: letsencrypt

  middlewares:
    # Basic auth for dashboard
    auth:
      basicAuth:
        users:
          - "admin:$apr1$..."
    
    # Security headers
    security-headers:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        frameDeny: true
        sslRedirect: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000

  services:
    # Example service
    example:
      loadBalancer:
        servers:
          - url: "http://example-service:8080"
```

### Deployment

```bash
# Create Traefik network
docker network create traefik-public

# Deploy Traefik as stack
docker stack deploy -c traefik-stack.yml traefik
```

## Docker Overlay Networks

### Create Overlay Networks

```bash
# Create application overlay network
docker network create --driver overlay --attachable app-network

# Create management overlay network
docker network create --driver overlay --attachable mgmt-network
```

### Network Segmentation

- **app-network**: Application services
- **mgmt-network**: Management and monitoring
- **traefik-public**: Public-facing services through Traefik

## Firewall Configuration

### Required Ports

```bash
# Docker Swarm
sudo ufw allow 2377/tcp   # Cluster management
sudo ufw allow 7946/tcp   # Node communication
sudo ufw allow 7946/udp   # Node communication
sudo ufw allow 4789/udp   # Overlay network

# ZeroTier
sudo ufw allow 9993/udp   # ZeroTier

# Tailscale
sudo ufw allow 41641/udp  # Tailscale (WireGuard)

# Traefik
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS

# Enable firewall
sudo ufw enable
```

## Network Testing

### Connectivity Tests

```bash
# Test ZeroTier connectivity
ping <zerotier-peer-ip>

# Test Tailscale connectivity
ping <tailscale-peer-hostname>

# Test overlay network
docker run --rm --network=app-network alpine ping -c 3 <service-name>

# Test Traefik routing
curl -H "Host: example.pr-cybr.local" http://traefik-node/
```

### Network Diagnostics

```bash
# Show ZeroTier routes
sudo zerotier-cli listnetworks -j | jq '.[].routes'

# Show Tailscale routes
sudo tailscale status --json | jq '.Peer[].CurAddr'

# Docker network inspection
docker network inspect app-network

# Traefik health check
curl http://localhost:8080/ping
```

## Troubleshooting

### ZeroTier Issues

**Issue**: Node not authorized
```bash
# Check status
sudo zerotier-cli status

# Rejoin network
sudo zerotier-cli leave <NETWORK_ID>
sudo zerotier-cli join <NETWORK_ID>
```

### Tailscale Issues

**Issue**: Cannot connect to peers
```bash
# Check status
sudo tailscale status

# Re-authenticate
sudo tailscale down
sudo tailscale up --authkey=<NEW_KEY>
```

### Traefik Issues

**Issue**: Service not accessible
```bash
# Check Traefik logs
docker service logs traefik_traefik

# Verify service labels
docker service inspect <service-name> --format '{{.Spec.Labels}}'
```

## Security Best Practices

- Use encrypted overlay networks
- Implement network segmentation
- Regular rotate authentication keys
- Monitor network traffic
- Apply least privilege access
- Enable firewall rules
- Use TLS for all external services

## Status

Status: Active
Version: 1.0
Last Updated: 2025-10-26
