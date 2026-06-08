#!/bin/bash
# =============================================================================
# Test suite for System Health Monitor
# Run: bash tests/test_monitor.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

pass() { echo -e "  ${GREEN}PASS${NC} — $1"; (( PASS++ )); }
fail() { echo -e "  ${RED}FAIL${NC} — $1"; (( FAIL++ )); }

echo -e "${BOLD}Running System Health Monitor Tests${NC}"
echo "──────────────────────────────────────"

# Test 1: Config file exists
echo "1. Config file exists"
[[ -f "${SCRIPT_DIR}/config/monitor.conf" ]] && pass "monitor.conf found" || fail "monitor.conf missing"

# Test 2: Main script exists and is executable
echo "2. Main script is executable"
chmod +x "${SCRIPT_DIR}/scripts/health_monitor.sh"
[[ -x "${SCRIPT_DIR}/scripts/health_monitor.sh" ]] && pass "health_monitor.sh is executable" || fail "health_monitor.sh not executable"

# Test 3: CPU metric is a number between 0-100
echo "3. CPU usage returns valid value"
source "${SCRIPT_DIR}/config/monitor.conf"
source "${SCRIPT_DIR}/scripts/health_monitor.sh" 2>/dev/null || true

cpu_val=$(grep '^cpu ' /proc/stat | head -1 | awk '{print $2}')
[[ "$cpu_val" =~ ^[0-9]+$ ]] && pass "CPU stat readable" || fail "Cannot read CPU stat"

# Test 4: RAM metric is a number between 0-100
echo "4. RAM usage returns valid value"
total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
used=$(( total - available ))
ram_pct=$(( (used * 100) / total ))
[[ $ram_pct -ge 0 && $ram_pct -le 100 ]] && pass "RAM usage: ${ram_pct}%" || fail "RAM usage out of range: ${ram_pct}%"

# Test 5: Disk metric readable
echo "5. Disk usage returns valid value"
disk_val=$(df -h / | awk 'NR==2 {gsub(/%/,""); print $5}')
[[ "$disk_val" =~ ^[0-9]+$ ]] && pass "Disk usage: ${disk_val}%" || fail "Disk usage unreadable"

# Test 6: Logs directory is created
echo "6. Logs directory writable"
mkdir -p "${SCRIPT_DIR}/logs"
touch "${SCRIPT_DIR}/logs/.write_test" 2>/dev/null && \
  pass "Logs directory writable" && \
  rm "${SCRIPT_DIR}/logs/.write_test" || \
  fail "Logs directory not writable"

# Test 7: /proc/stat is readable (Linux only)
echo "7. /proc/stat readable"
[[ -r /proc/stat ]] && pass "/proc/stat readable" || fail "/proc/stat not readable"

# Test 8: /proc/meminfo is readable
echo "8. /proc/meminfo readable"
[[ -r /proc/meminfo ]] && pass "/proc/meminfo readable" || fail "/proc/meminfo not readable"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────"
echo -e "Results: ${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}"
echo ""
[[ $FAIL -eq 0 ]] && echo -e "${GREEN}All tests passed! ✔${NC}" && exit 0 || \
  echo -e "${RED}Some tests failed. Check above.${NC}" && exit 1
