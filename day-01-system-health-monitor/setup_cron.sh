#!/bin/bash
# =============================================================================
# Setup script — installs the health monitor as a cron job
# Run: bash setup_cron.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="${SCRIPT_DIR}/scripts/health_monitor.sh"

# Make main script executable
chmod +x "$MONITOR_SCRIPT"
echo "✔  Made health_monitor.sh executable"

# Check if cron entry already exists
if crontab -l 2>/dev/null | grep -q "health_monitor.sh"; then
  echo "ℹ  Cron job already exists. Skipping."
else
  # Add cron job: runs every 30 minutes
  (crontab -l 2>/dev/null; echo "*/30 * * * * /bin/bash ${MONITOR_SCRIPT} >> ${SCRIPT_DIR}/logs/cron.log 2>&1") | crontab -
  echo "✔  Cron job added — runs every 30 minutes"
fi

echo ""
echo "Current crontab:"
crontab -l
echo ""
echo "Setup complete! Run the monitor manually with:"
echo "  bash ${MONITOR_SCRIPT}"
