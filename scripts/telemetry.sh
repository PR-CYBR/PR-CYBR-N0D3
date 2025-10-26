#!/bin/bash
set -euo pipefail

# PR-CYBR-N0D3 Telemetry Collection Script
# Collects and reports node metrics to management node

# Configuration
MGMT_NODE_URL="${MGMT_NODE_URL:-https://mgmt.pr-cybr.local}"
TELEMETRY_INTERVAL="${TELEMETRY_INTERVAL:-60}"
NODE_ID="${NODE_ID:-node-$(hostname)}"
API_TOKEN="${API_TOKEN:-}"

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

# Collect CPU metrics
collect_cpu_metrics() {
    # Get CPU usage percentage (average over 1 second)
    CPU_IDLE=$(top -bn2 -d 1 | grep "Cpu(s)" | tail -1 | sed "s/.*, *\([0-9.]*\)%* id.*/\1/")
    CPU_USAGE=$(awk "BEGIN {print 100 - $CPU_IDLE}")
    
    # Get load average
    LOAD_AVG=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{print $1}' | tr -d ',')
    
    echo "{\"cpu_percent\": $CPU_USAGE, \"load_avg_1m\": $LOAD_AVG}"
}

# Collect memory metrics
collect_memory_metrics() {
    MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
    MEM_USED=$(free | grep Mem | awk '{print $3}')
    MEM_PERCENT=$(awk "BEGIN {print ($MEM_USED / $MEM_TOTAL) * 100}")
    
    echo "{\"memory_total_kb\": $MEM_TOTAL, \"memory_used_kb\": $MEM_USED, \"memory_percent\": $MEM_PERCENT}"
}

# Collect disk metrics
collect_disk_metrics() {
    DISK_TOTAL=$(df -k / | tail -1 | awk '{print $2}')
    DISK_USED=$(df -k / | tail -1 | awk '{print $3}')
    DISK_PERCENT=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
    
    echo "{\"disk_total_kb\": $DISK_TOTAL, \"disk_used_kb\": $DISK_USED, \"disk_percent\": $DISK_PERCENT}"
}

# Collect network metrics
collect_network_metrics() {
    # Get primary interface
    PRIMARY_IF=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [ -z "$PRIMARY_IF" ]; then
        echo "{\"network_rx_bytes\": 0, \"network_tx_bytes\": 0}"
        return
    fi
    
    RX_BYTES=$(cat /sys/class/net/$PRIMARY_IF/statistics/rx_bytes)
    TX_BYTES=$(cat /sys/class/net/$PRIMARY_IF/statistics/tx_bytes)
    
    echo "{\"network_rx_bytes\": $RX_BYTES, \"network_tx_bytes\": $TX_BYTES, \"interface\": \"$PRIMARY_IF\"}"
}

# Collect Docker metrics
collect_docker_metrics() {
    if ! command -v docker &> /dev/null; then
        echo "{\"docker_available\": false}"
        return
    fi
    
    CONTAINER_COUNT=$(docker ps -q | wc -l)
    RUNNING_COUNT=$(docker ps --filter "status=running" -q | wc -l)
    
    # Check if in swarm
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        SWARM_STATUS="active"
        NODE_STATE=$(docker info 2>/dev/null | grep "NodeAddress:" | awk '{print $2}' || echo "unknown")
    else
        SWARM_STATUS="inactive"
        NODE_STATE="n/a"
    fi
    
    echo "{\"docker_available\": true, \"container_count\": $CONTAINER_COUNT, \"running_count\": $RUNNING_COUNT, \"swarm_status\": \"$SWARM_STATUS\", \"node_state\": \"$NODE_STATE\"}"
}

# Collect all metrics
collect_all_metrics() {
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    CPU_METRICS=$(collect_cpu_metrics)
    MEM_METRICS=$(collect_memory_metrics)
    DISK_METRICS=$(collect_disk_metrics)
    NET_METRICS=$(collect_network_metrics)
    DOCKER_METRICS=$(collect_docker_metrics)
    
    # Combine all metrics into JSON
    cat <<EOF
{
  "node_id": "$NODE_ID",
  "timestamp": "$TIMESTAMP",
  "hostname": "$(hostname)",
  "architecture": "$(uname -m)",
  "metrics": {
    "cpu": $CPU_METRICS,
    "memory": $MEM_METRICS,
    "disk": $DISK_METRICS,
    "network": $NET_METRICS,
    "docker": $DOCKER_METRICS
  }
}
EOF
}

# Send metrics to management node
send_metrics() {
    local metrics_data=$1
    
    if [ -z "$API_TOKEN" ]; then
        log_warn "API_TOKEN not set. Skipping metrics upload."
        return 1
    fi
    
    local response
    local http_code
    
    response=$(curl -s -w "\n%{http_code}" -X POST "$MGMT_NODE_URL/api/telemetry" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$metrics_data" 2>&1) || {
        log_error "Failed to send metrics: connection error"
        return 1
    }
    
    http_code=$(echo "$response" | tail -1)
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        log_info "Metrics sent successfully (HTTP $http_code)"
        return 0
    else
        log_error "Failed to send metrics (HTTP $http_code)"
        return 1
    fi
}

# Test mode - collect and display metrics without sending
test_mode() {
    log_info "Running in test mode..."
    metrics=$(collect_all_metrics)
    echo "$metrics" | jq '.' 2>/dev/null || echo "$metrics"
    exit 0
}

# Main telemetry loop
main() {
    # Check for test flag
    if [ "${1:-}" = "--test" ] || [ "${1:-}" = "-t" ]; then
        test_mode
    fi

    log_info "Starting telemetry collection for node: $NODE_ID"
    log_info "Management node: $MGMT_NODE_URL"
    log_info "Collection interval: ${TELEMETRY_INTERVAL}s"

    while true; do
        log_info "Collecting metrics..."
        
        metrics=$(collect_all_metrics)
        
        if send_metrics "$metrics"; then
            log_info "Telemetry cycle complete"
        else
            log_warn "Telemetry upload failed, will retry next cycle"
        fi
        
        sleep "$TELEMETRY_INTERVAL"
    done
}

main "$@"
