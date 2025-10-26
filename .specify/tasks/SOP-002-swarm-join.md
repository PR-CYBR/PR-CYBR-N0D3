# SOP-002: Swarm Join Process

## Objective

Join a PR-CYBR-N0D3 node to the Docker Swarm cluster managed by PR-CYBR-MGMT-N0D3.

## Prerequisites

- Running Docker daemon
- Network connectivity to manager node
- Valid swarm join token

## Automated Join Process

The `scripts/swarm-join.sh` script automates the swarm join process.

### Usage

```bash
# Set environment variables
export SWARM_JOIN_TOKEN="SWMTKN-1-xxxxx"
export SWARM_MANAGER_IP="10.147.x.x"

# Run join script
sudo ./scripts/swarm-join.sh
```

### Script Flow

1. Verify Docker is running
2. Check if already in a swarm
3. Discover manager nodes via DNS or configuration
4. Attempt join with provided token
5. Verify successful join
6. Configure overlay networks
7. Report status to management node

## Manual Join Process

If automated script fails, join manually:

### As Worker Node

```bash
docker swarm join \
  --token SWMTKN-1-xxxxx \
  10.147.x.x:2377
```

### As Manager Node

```bash
docker swarm join \
  --token SWMTKN-1-xxxxx \
  10.147.x.x:2377
```

(Note: Manager token is different from worker token)

## Verification

```bash
# Check swarm status
docker info | grep Swarm

# List all nodes (if you have manager access)
docker node ls

# Check node role
docker node inspect self --format '{{ .Spec.Role }}'

# Verify overlay networks
docker network ls --filter driver=overlay
```

## Network Configuration

After joining, configure overlay networks:

```bash
# Join existing overlay networks
docker network ls --filter driver=overlay

# Verify connectivity
docker run --rm --network=<overlay-network> alpine ping -c 3 <peer-node>
```

## Health Checks

```bash
# Check node availability
docker node inspect self --format '{{ .Status.State }}'

# Check node reachability
docker node inspect self --format '{{ .Status.Addr }}'

# View node labels
docker node inspect self --format '{{ .Spec.Labels }}'
```

## Troubleshooting

### Issue: Connection refused to manager

**Cause**: Firewall blocking port 2377

**Solution**: Open required ports
```bash
# Allow swarm management traffic
sudo ufw allow 2377/tcp

# Allow overlay network traffic
sudo ufw allow 7946/tcp
sudo ufw allow 7946/udp
sudo ufw allow 4789/udp
```

### Issue: Token rejected

**Cause**: Invalid or expired token

**Solution**: Request new token from manager
```bash
# On manager node, generate worker token
docker swarm join-token worker

# Generate manager token
docker swarm join-token manager
```

### Issue: Already part of a swarm

**Cause**: Node is already in a swarm

**Solution**: Leave current swarm first
```bash
# Leave swarm (will lose data)
docker swarm leave --force

# Then rejoin new swarm
./scripts/swarm-join.sh
```

## Rejoin After Failure

If a node loses connection to the swarm:

```bash
# Check swarm status
docker info | grep Swarm

# If status is "inactive", rejoin
./scripts/swarm-join.sh

# If status is "pending", wait or force leave and rejoin
docker swarm leave --force
./scripts/swarm-join.sh
```

## Advanced Configuration

### Node Labels

Apply labels for scheduling constraints:

```bash
# On manager node, label the worker
docker node update --label-add region=us-east worker-node-1
docker node update --label-add environment=production worker-node-1
```

### Resource Reservations

Set resource limits:

```bash
# On manager node
docker node update --generic-resource "gpu=2" worker-node-1
```

### Availability

Control node availability:

```bash
# Drain node (stop scheduling new tasks)
docker node update --availability drain worker-node-1

# Make node active
docker node update --availability active worker-node-1
```

## Security Considerations

- Store join tokens securely (use secrets management)
- Rotate tokens periodically
- Use manager tokens only for manager nodes
- Implement network segmentation
- Monitor for unauthorized join attempts

## Status

Status: Active
Version: 1.0
Last Updated: 2025-10-26
