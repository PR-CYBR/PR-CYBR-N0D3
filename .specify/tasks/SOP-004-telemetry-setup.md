# SOP-004: Telemetry Setup

## Objective

Configure telemetry collection and reporting for PR-CYBR-N0D3 nodes.

## Telemetry Components

### Metrics Collected

- **System Metrics**: CPU, memory, disk, network
- **Container Metrics**: Resource usage per container
- **Application Metrics**: Custom application metrics
- **Network Metrics**: Latency, throughput, packet loss

### Collection Script

Location: `scripts/telemetry.sh`

The telemetry script runs periodically to collect and report metrics.

## Installation

```bash
# Make telemetry script executable
chmod +x scripts/telemetry.sh

# Install as systemd service
sudo cp configs/systemd/pr-cybr-telemetry.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pr-cybr-telemetry
sudo systemctl start pr-cybr-telemetry
```

## Configuration

Environment variables in `/etc/pr-cybr/telemetry.conf`:

```bash
MGMT_NODE_URL="https://mgmt.pr-cybr.local"
TELEMETRY_INTERVAL=60  # seconds
NODE_ID="node-$(hostname)"
API_TOKEN="<token>"
```

## Verification

```bash
# Check service status
sudo systemctl status pr-cybr-telemetry

# View recent logs
sudo journalctl -u pr-cybr-telemetry -n 50

# Test manual collection
sudo ./scripts/telemetry.sh --test
```

## Metrics Format

Telemetry data is sent as JSON:

```json
{
  "node_id": "node-xyz",
  "timestamp": "2025-10-26T20:00:00Z",
  "metrics": {
    "cpu_percent": 15.3,
    "memory_percent": 42.1,
    "disk_percent": 60.5,
    "network_rx_bytes": 1234567,
    "network_tx_bytes": 7654321
  }
}
```

## Troubleshooting

**Issue**: Metrics not reaching management node

**Solution**: Check connectivity and credentials
```bash
# Test connection
curl -H "Authorization: Bearer $API_TOKEN" $MGMT_NODE_URL/api/telemetry

# Check logs for errors
sudo journalctl -u pr-cybr-telemetry --since "10 minutes ago"
```

## Status

Status: Active
Version: 1.0
Last Updated: 2025-10-26
