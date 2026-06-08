#!/bin/bash
# =============================================================================
# System Health Monitor
# Author: DevOps Day 1 Project
# Description: Monitors CPU, RAM, Disk usage and sends alerts on threshold breach
# =============================================================================

set -euo pipefail

# ── Load config ───────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/monitor.conf"

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "[ERROR] Config file not found: $CONFIG_FILE"
  exit 1
fi

# ── Setup log file ─────────────────────────────────────────────────────────────
LOG_DIR="${SCRIPT_DIR}/../logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/health_$(date +%Y-%m-%d).log"
REPORT_FILE="${LOG_DIR}/report_$(date +%Y-%m-%d_%H-%M-%S).txt"

# ── Colors for terminal output ─────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Logging helper ─────────────────────────────────────────────────────────────
log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# ── Alert function (email or log) ─────────────────────────────────────────────
send_alert() {
  local subject="$1"
  local body="$2"

  log "ALERT" "$subject"

  if [[ "${ENABLE_EMAIL:-false}" == "true" ]] && command -v mail &>/dev/null; then
    echo "$body" | mail -s "[HEALTH ALERT] $subject" "$ALERT_EMAIL"
    log "INFO" "Email alert sent to $ALERT_EMAIL"
  else
    echo -e "${RED}[ALERT]${NC} $subject" >&2
    echo "$body" >&2
  fi
}

# ── Get CPU usage (%) ──────────────────────────────────────────────────────────
get_cpu_usage() {
  # Read CPU idle from /proc/stat, compute usage over 1 second interval
  local cpu_idle_1 cpu_idle_2 cpu_total_1 cpu_total_2
  local cpu_line_1 cpu_line_2

  cpu_line_1=$(grep '^cpu ' /proc/stat)
  sleep 1
  cpu_line_2=$(grep '^cpu ' /proc/stat)

  # Fields: user nice system idle iowait irq softirq steal
  read -r _ u1 n1 s1 id1 iow1 irq1 sirq1 steal1 <<< "$cpu_line_1"
  read -r _ u2 n2 s2 id2 iow2 irq2 sirq2 steal2 <<< "$cpu_line_2"

  cpu_total_1=$(( u1 + n1 + s1 + id1 + iow1 + irq1 + sirq1 + steal1 ))
  cpu_total_2=$(( u2 + n2 + s2 + id2 + iow2 + irq2 + sirq2 + steal2 ))
  cpu_idle_1=$id1
  cpu_idle_2=$id2

  local delta_total delta_idle
  delta_total=$(( cpu_total_2 - cpu_total_1 ))
  delta_idle=$(( cpu_idle_2 - cpu_idle_1 ))

  if [[ $delta_total -eq 0 ]]; then
    echo "0"
  else
    echo $(( (100 * (delta_total - delta_idle)) / delta_total ))
  fi
}

# ── Get RAM usage (%) ──────────────────────────────────────────────────────────
get_ram_usage() {
  local total used available
  total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  used=$(( total - available ))
  echo $(( (used * 100) / total ))
}

# ── Get RAM details (human-readable) ──────────────────────────────────────────
get_ram_details() {
  local total used available
  total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  used=$(( total - available ))
  printf "Used: %s MB / Total: %s MB" \
    "$(( used / 1024 ))" \
    "$(( total / 1024 ))"
}

# ── Get Disk usage for a mount point ──────────────────────────────────────────
get_disk_usage() {
  local mount="${1:-/}"
  df -h "$mount" | awk 'NR==2 {gsub(/%/,""); print $5}'
}

# ── Get Disk details ───────────────────────────────────────────────────────────
get_disk_details() {
  local mount="${1:-/}"
  df -h "$mount" | awk 'NR==2 {print "Used: " $3 " / Total: " $2 " (Available: " $4 ")"}'
}

# ── Get system load average ────────────────────────────────────────────────────
get_load_average() {
  awk '{print $1, $2, $3}' /proc/loadavg
}

# ── Get top 5 CPU-consuming processes ─────────────────────────────────────────
get_top_processes_cpu() {
  ps aux --sort=-%cpu | awk 'NR>1 && NR<=6 {printf "  %-25s %5s%%\n", $11, $3}'
}

# ── Get top 5 RAM-consuming processes ─────────────────────────────────────────
get_top_processes_ram() {
  ps aux --sort=-%mem | awk 'NR>1 && NR<=6 {printf "  %-25s %5s%%\n", $11, $4}'
}

# ── Check service status ───────────────────────────────────────────────────────
check_services() {
  local services_to_check=("${MONITORED_SERVICES[@]:-}")
  if [[ ${#services_to_check[@]} -eq 0 ]]; then
    echo "  No services configured for monitoring."
    return
  fi

  for svc in "${services_to_check[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      echo -e "  ${GREEN}✔${NC} $svc — running"
    else
      echo -e "  ${RED}✘${NC} $svc — NOT running"
      send_alert "Service Down: $svc" "The service '$svc' is not running on $(hostname) at $(date)."
    fi
  done
}

# ── Color-coded status indicator ──────────────────────────────────────────────
status_color() {
  local value="$1"
  local warn="$2"
  local crit="$3"
  if [[ $value -ge $crit ]]; then
    echo -e "${RED}${value}%${NC}"
  elif [[ $value -ge $warn ]]; then
    echo -e "${YELLOW}${value}%${NC}"
  else
    echo -e "${GREEN}${value}%${NC}"
  fi
}

# ── Generate full report ───────────────────────────────────────────────────────
generate_report() {
  local hostname
  hostname=$(hostname)
  local uptime_info
  uptime_info=$(uptime -p 2>/dev/null || uptime)

  local cpu_usage ram_usage disk_usage
  echo -e "${BLUE}${BOLD}Collecting metrics... (this takes ~1 second for CPU)${NC}"
  cpu_usage=$(get_cpu_usage)
  ram_usage=$(get_ram_usage)
  disk_usage=$(get_disk_usage "${DISK_MOUNT:-/}")

  local cpu_status ram_status disk_status
  cpu_status=$(status_color "$cpu_usage" "${CPU_WARN_THRESHOLD:-70}" "${CPU_CRIT_THRESHOLD:-90}")
  ram_status=$(status_color "$ram_usage" "${RAM_WARN_THRESHOLD:-70}" "${RAM_CRIT_THRESHOLD:-90}")
  disk_status=$(status_color "$disk_usage" "${DISK_WARN_THRESHOLD:-70}" "${DISK_CRIT_THRESHOLD:-90}")

  local load_avg
  load_avg=$(get_load_average)

  # ── Print report to terminal ─────────────────────────────────────────────────
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║          SYSTEM HEALTH MONITOR REPORT                ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e "  Host     : ${BOLD}${hostname}${NC}"
  echo -e "  Date     : $(date '+%Y-%m-%d %H:%M:%S')"
  echo -e "  Uptime   : ${uptime_info}"
  echo ""
  echo -e "${BOLD}── Resource Usage ──────────────────────────────────────${NC}"
  echo -e "  CPU Usage   : ${cpu_status}   ($(get_ram_details | sed 's/Used.*//'))"
  echo -e "  RAM Usage   : ${ram_status}   ($(get_ram_details))"
  echo -e "  Disk Usage  : ${disk_status}  ($(get_disk_details "${DISK_MOUNT:-/}"))"
  echo -e "  Load Avg    : ${load_avg} (1m 5m 15m)"
  echo ""
  echo -e "${BOLD}── Top CPU Processes ───────────────────────────────────${NC}"
  get_top_processes_cpu
  echo ""
  echo -e "${BOLD}── Top RAM Processes ───────────────────────────────────${NC}"
  get_top_processes_ram
  echo ""
  echo -e "${BOLD}── Service Status ──────────────────────────────────────${NC}"
  check_services
  echo ""
  echo -e "${BOLD}── Log saved to ────────────────────────────────────────${NC}"
  echo -e "  ${LOG_FILE}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
  echo ""

  # ── Save plain text report ───────────────────────────────────────────────────
  {
    echo "SYSTEM HEALTH REPORT — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Host: $hostname | Uptime: $uptime_info"
    echo "---"
    echo "CPU:  ${cpu_usage}%  (threshold warn:${CPU_WARN_THRESHOLD:-70}% crit:${CPU_CRIT_THRESHOLD:-90}%)"
    echo "RAM:  ${ram_usage}%  ($(get_ram_details))"
    echo "Disk: ${disk_usage}% ($(get_disk_details "${DISK_MOUNT:-/}"))"
    echo "Load: ${load_avg}"
  } > "$REPORT_FILE"

  log "INFO" "Report generated: $REPORT_FILE"

  # ── Trigger alerts if thresholds breached ────────────────────────────────────
  if [[ $cpu_usage -ge ${CPU_CRIT_THRESHOLD:-90} ]]; then
    send_alert "CRITICAL: CPU at ${cpu_usage}%" \
      "CPU usage is at ${cpu_usage}% on ${hostname}. Critical threshold: ${CPU_CRIT_THRESHOLD:-90}%."
  elif [[ $cpu_usage -ge ${CPU_WARN_THRESHOLD:-70} ]]; then
    send_alert "WARNING: CPU at ${cpu_usage}%" \
      "CPU usage is at ${cpu_usage}% on ${hostname}. Warning threshold: ${CPU_WARN_THRESHOLD:-70}%."
  fi

  if [[ $ram_usage -ge ${RAM_CRIT_THRESHOLD:-90} ]]; then
    send_alert "CRITICAL: RAM at ${ram_usage}%" \
      "RAM usage is at ${ram_usage}% on ${hostname}."
  elif [[ $ram_usage -ge ${RAM_WARN_THRESHOLD:-70} ]]; then
    send_alert "WARNING: RAM at ${ram_usage}%" \
      "RAM usage is at ${ram_usage}% on ${hostname}."
  fi

  if [[ $disk_usage -ge ${DISK_CRIT_THRESHOLD:-90} ]]; then
    send_alert "CRITICAL: Disk at ${disk_usage}%" \
      "Disk usage is at ${disk_usage}% on ${DISK_MOUNT:-/} on ${hostname}."
  elif [[ $disk_usage -ge ${DISK_WARN_THRESHOLD:-70} ]]; then
    send_alert "WARNING: Disk at ${disk_usage}%" \
      "Disk usage is at ${disk_usage}% on ${DISK_MOUNT:-/} on ${hostname}."
  fi
}

# ── Rotate old logs (keep last N days) ────────────────────────────────────────
rotate_logs() {
  local keep_days="${LOG_RETENTION_DAYS:-7}"
  find "$LOG_DIR" -name "*.log" -mtime +"$keep_days" -delete 2>/dev/null && \
    log "INFO" "Rotated logs older than ${keep_days} days."
}

# ── Entry point ────────────────────────────────────────────────────────────────
main() {
  log "INFO" "Health monitor started."
  generate_report
  rotate_logs
  log "INFO" "Health monitor completed."
}

main "$@"
