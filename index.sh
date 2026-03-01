#!/bin/bash
# System Monitor - Health Check Tool

set -e

# Default values
CHECK_CPU=false
CHECK_MEMORY=false
CHECK_DISK=false
CHECK_PROCESS=""
VERBOSE=false
JSON_OUTPUT=false
CUSTOM_PROCESS=""

# Thresholds
CPU_WARN=80
CPU_CRIT=95
MEM_WARN=80
MEM_CRIT=95
DISK_WARN=80
DISK_CRIT=95

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cpu) CHECK_CPU=true; shift ;;
        --memory) CHECK_MEMORY=true; shift ;;
        --disk) CHECK_DISK=true; shift ;;
        --process) CUSTOM_PROCESS="$2"; shift 2 ;;
        --verbose) VERBOSE=true; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        -h|--help)
            echo "Usage: system-monitor [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --cpu            Check CPU only"
            echo "  --memory         Check memory only"
            echo "  --disk           Check disk only"
            echo "  --process NAME   Check specific process"
            echo "  --verbose        Show detailed output"
            echo "  --json           Output in JSON format"
            echo "  -h, --help       Show help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# If no specific check, do all
if [ "$CHECK_CPU" = false ] && [ "$CHECK_MEMORY" = false ] && [ "$CHECK_DISK" = false ] && [ -z "$CUSTOM_PROCESS" ]; then
    CHECK_CPU=true
    CHECK_MEMORY=true
    CHECK_DISK=true
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
STATUS="ok"
WARNINGS=0
CRITICAL=0

# Get CPU usage
get_cpu_usage() {
    local cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1 2>/dev/null || echo "0")
    local cpu_usage=$(echo "100 - ${cpu_idle%.*}" | bc 2>/dev/null || echo "0")
    echo "${cpu_usage:-0}"
}

# Get load average
get_loadavg() {
    cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}' || echo "0 0 0"
}

# Get CPU cores
get_cpu_cores() {
    nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "1"
}

# Get memory info
get_memory_info() {
    free -b 2>/dev/null | awk 'NR==2 {printf "%.0f %.0f %.0f", $2, $3, $4}' || echo "0 0 0"
}

# Get swap info
get_swap_info() {
    free -b 2>/dev/null | awk 'NR==3 {printf "%.0f %.0f", $2, $3}' || echo "0 0"
}

# Get disk usage
get_disk_usage() {
    df -BG 2>/dev/null | grep -E '^/dev/' | awk '{gsub(/G/,""); print $1, $2, $3, $4, $5, $6}' || echo ""
}

# Check if process is running
check_process() {
    local name="$1"
    if pgrep -x "$name" > /dev/null 2>&1; then
        local pid=$(pgrep -x "$name" | head -1)
        echo "running:$pid"
    elif pgrep -f "$name" > /dev/null 2>&1; then
        local pid=$(pgrep -f "$name" | head -1)
        echo "running:$pid"
    else
        echo "stopped"
    fi
}

# Default processes to monitor
DEFAULT_PROCESSES="nginx mysql mariadb postgresql redis docker sshd"

# JSON output
output_json() {
    local cpu_usage=$(get_cpu_usage)
    local loadavg=$(get_loadavg)
    local cores=$(get_cpu_cores)
    local mem_info=($(get_memory_info))
    local swap_info=($(get_swap_info))
    
    local mem_total_gb=$(echo "scale=1; ${mem_info[0]:-0} / 1073741824" | bc 2>/dev/null || echo "0")
    local mem_used_gb=$(echo "scale=1; ${mem_info[1]:-0} / 1073741824" | bc 2>/dev/null || echo "0")
    local mem_pct=$(echo "scale=0; ${mem_info[1]:-0} * 100 / ${mem_info[0]:-1}" | bc 2>/dev/null || echo "0")
    
    cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "status": "$STATUS",
  "metrics": {
    "cpu": {
      "usage_percent": $cpu_usage,
      "cores": $cores,
      "load_average": "$(echo $loadavg | tr ' ' ',')"
    },
    "memory": {
      "total_gb": $mem_total_gb,
      "used_gb": $mem_used_gb,
      "usage_percent": $mem_pct
    },
    "disk": $(get_disk_usage | head -1 | awk '{printf "{\"mount\": \"%s\", \"total_gb\": %s, \"used_gb\": %s, \"usage_percent\": %s}", $6, $2, $3, $5}' || echo '{}')
  },
  "warnings": $WARNINGS,
  "critical": $CRITICAL
}
EOF
}

# Text output
output_text() {
    echo -e "${BLUE}🖥️ 系统监控 - $TIMESTAMP${NC}"
    echo ""
    
    # CPU Check
    if [ "$CHECK_CPU" = true ]; then
        echo -e "${GREEN}✅ CPU${NC}"
        local cpu_usage=$(get_cpu_usage)
        local loadavg=$(get_loadavg)
        local cores=$(get_cpu_cores)
        
        local cpu_status="${GREEN}正常${NC}"
        if [ "$cpu_usage" -gt "$CPU_CRIT" ] 2>/dev/null; then
            cpu_status="${RED}严重${NC}"
            CRITICAL=$((CRITICAL + 1))
            STATUS="critical"
        elif [ "$cpu_usage" -gt "$CPU_WARN" ] 2>/dev/null; then
            cpu_status="${YELLOW}警告${NC}"
            WARNINGS=$((WARNINGS + 1))
            [ "$STATUS" = "ok" ] && STATUS="warning"
        fi
        
        echo "  - 使用率：${cpu_usage}% (${cores} cores)"
        echo "  - 负载：$(echo $loadavg | awk '{print $1, $2, $3}')"
        echo "  - 状态：$cpu_status"
        echo ""
    fi
    
    # Memory Check
    if [ "$CHECK_MEMORY" = true ]; then
        echo -e "${GREEN}✅ 内存${NC}"
        local mem_info=($(get_memory_info))
        local swap_info=($(get_swap_info))
        
        local mem_total_gb=$(echo "scale=1; ${mem_info[0]:-0} / 1073741824" | bc 2>/dev/null || echo "0")
        local mem_used_gb=$(echo "scale=1; ${mem_info[1]:-0} / 1073741824" | bc 2>/dev/null || echo "0")
        local mem_pct=$(echo "scale=0; ${mem_info[1]:-0} * 100 / ${mem_info[0]:-1}" | bc 2>/dev/null || echo "0")
        
        local mem_status="${GREEN}正常${NC}"
        if [ "$mem_pct" -gt "$MEM_CRIT" ] 2>/dev/null; then
            mem_status="${RED}严重${NC}"
            CRITICAL=$((CRITICAL + 1))
            STATUS="critical"
        elif [ "$mem_pct" -gt "$MEM_WARN" ] 2>/dev/null; then
            mem_status="${YELLOW}警告${NC}"
            WARNINGS=$((WARNINGS + 1))
            [ "$STATUS" = "ok" ] && STATUS="warning"
        fi
        
        echo "  - 已用：${mem_used_gb}GB / ${mem_total_gb}GB (${mem_pct}%)"
        echo "  - 状态：$mem_status"
        echo ""
    fi
    
    # Disk Check
    if [ "$CHECK_DISK" = true ]; then
        echo -e "${YELLOW}📀 磁盘${NC}"
        local disk_output=$(df -h 2>/dev/null | grep -E '^/dev/' | awk '{print $6, $2, $3, $4, $5}')
        
        if [ -n "$disk_output" ]; then
            echo "$disk_output" | while read mount total used avail pct; do
                local pct_num=${pct%\%}
                local disk_status="${GREEN}正常${NC}"
                if [ "$pct_num" -gt "$DISK_CRIT" ] 2>/dev/null; then
                    disk_status="${RED}严重${NC}"
                elif [ "$pct_num" -gt "$DISK_WARN" ] 2>/dev/null; then
                    disk_status="${YELLOW}警告${NC}"
                fi
                echo "  - $mount: $used / $total ($pct) $disk_status"
            done
        else
            echo "  - 无磁盘数据"
        fi
        echo ""
    fi
    
    # Process Check
    if [ -n "$CUSTOM_PROCESS" ]; then
        echo -e "${BLUE}🔄 进程${NC}"
        local result=$(check_process "$CUSTOM_PROCESS")
        if [[ "$result" == running:* ]]; then
            local pid=${result#*:}
            echo "  - $CUSTOM_PROCESS: ${GREEN}运行中${NC} (PID $pid)"
        else
            echo "  - $CUSTOM_PROCESS: ${RED}未运行${NC}"
        fi
        echo ""
    fi
    
    # Summary
    echo -e "${BLUE}📊 总结${NC}"
    echo "  - 状态：$STATUS"
    echo "  - 警告：$WARNINGS"
    echo "  - 严重：$CRITICAL"
}

# Main
if [ "$JSON_OUTPUT" = true ]; then
    output_json
else
    output_text
fi
