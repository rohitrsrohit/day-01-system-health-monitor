# 🖥️ Day 01 — System Health Monitor

> **30 Days of DevOps** | Day 1/30 — Linux & Shell Scripting

A production-grade Bash script that monitors **CPU, RAM, and Disk usage** in real time, sends alerts when thresholds are breached, checks service health, logs all metrics, and auto-rotates old logs via cron.

---

## 📸 Sample Output

```
╔══════════════════════════════════════════════════════╗
║          SYSTEM HEALTH MONITOR REPORT                ║
╚══════════════════════════════════════════════════════╝
  Host     : my-server
  Date     : 2026-06-08 10:30:00
  Uptime   : up 3 days, 2 hours, 15 minutes

── Resource Usage ──────────────────────────────────────
  CPU Usage   : 23%   (green)
  RAM Usage   : 61%   (yellow)
  Disk Usage  : 45%   (green)
  Load Avg    : 0.45 0.38 0.31 (1m 5m 15m)

── Top CPU Processes ───────────────────────────────────
  /usr/bin/python3           12.3%
  /usr/sbin/mysqld            4.1%

── Top RAM Processes ───────────────────────────────────
  /usr/sbin/mysqld           18.2%
  /usr/bin/python3            6.4%

── Service Status ──────────────────────────────────────
  ✔ nginx — running
  ✔ docker — running
```

---

## 📁 Project Structure

```
day-01-system-health-monitor/
├── scripts/
│   └── health_monitor.sh     # Main monitoring script
├── config/
│   └── monitor.conf          # Thresholds and settings
├── tests/
│   └── test_monitor.sh       # Automated test suite
├── logs/                     # Auto-created, gitignored
├── docs/
│   └── architecture.md       # Design notes
├── setup_cron.sh             # One-command cron installer
├── .gitignore
└── README.md
```

---

## ⚙️ Features

| Feature | Description |
|---|---|
| CPU Monitoring | Reads `/proc/stat` with 1s delta for accuracy |
| RAM Monitoring | Uses `/proc/meminfo` MemAvailable for real free RAM |
| Disk Monitoring | Configurable mount point via `monitor.conf` |
| Threshold Alerts | Separate warn/critical levels for each metric |
| Email Alerts | Optional via `mailutils` (toggle in config) |
| Service Checks | Monitor any systemd service for up/down status |
| Log Rotation | Auto-deletes logs older than N days |
| Cron Ready | One-command setup via `setup_cron.sh` |
| Test Suite | 8 automated tests to validate the environment |

---

## 🚀 Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/day-01-system-health-monitor.git
cd day-01-system-health-monitor
```

### 2. Configure thresholds

```bash
nano config/monitor.conf
```

Key settings:
```bash
CPU_WARN_THRESHOLD=70        # Alert at 70% CPU
CPU_CRIT_THRESHOLD=90        # Critical at 90%
DISK_MOUNT="/"               # Disk partition to monitor
MONITORED_SERVICES=("nginx" "docker")   # Services to check
ENABLE_EMAIL=false           # Set true + add email if needed
```

### 3. Run manually

```bash
chmod +x scripts/health_monitor.sh
bash scripts/health_monitor.sh
```

### 4. Set up cron (runs every 30 min)

```bash
bash setup_cron.sh
```

To change frequency, edit the crontab after setup:
```bash
crontab -e
# Every 5 minutes:  */5 * * * *
# Every hour:        0 * * * *
# Daily at 8am:      0 8 * * *
```

### 5. Run tests

```bash
bash tests/test_monitor.sh
```

---

## 📧 Email Alerts Setup

```bash
# Install mailutils (Debian/Ubuntu)
sudo apt install mailutils -y

# Edit config
ENABLE_EMAIL=true
ALERT_EMAIL="you@example.com"
```

> For Gmail SMTP, configure `/etc/ssmtp/ssmtp.conf` or use `msmtp`.

---

## 📊 Understanding the Metrics

### CPU Usage
Calculated from `/proc/stat` using a 1-second sampling window:
```
CPU% = 100 × (delta_active / delta_total)
```
This is more accurate than `top` snapshots since it avoids single-tick spikes.

### RAM Usage
```
RAM% = ((MemTotal - MemAvailable) / MemTotal) × 100
```
Uses `MemAvailable` (not `MemFree`) — accounts for cache that the kernel can reclaim.

### Load Average
Three numbers from `/proc/loadavg` — 1-minute, 5-minute, 15-minute averages. On a 4-core system, a load of 4.0 means fully utilized.

---

## 🛠️ Requirements

| Requirement | Notes |
|---|---|
| OS | Linux (reads `/proc` filesystem) |
| Shell | Bash 4.0+ |
| Commands | `ps`, `df`, `grep`, `awk`, `date` (all standard) |
| Optional | `systemctl` for service checks, `mail` for email alerts |

---

## 📝 Log Files

Logs are saved to `logs/` with daily rotation:
```
logs/
├── health_2026-06-08.log          # Timestamped events
├── report_2026-06-08_10-30-00.txt # Plain text snapshot
└── cron.log                       # Cron job output
```

---

## 🔧 Customization Ideas

- Add **Slack webhook** alert support
- Monitor **network I/O** (`/proc/net/dev`)
- Add **temperature** monitoring (`sensors` command)
- Export metrics to **Prometheus** format
- Build a simple **HTML dashboard** from the logs

---

## 🤝 Part of 30 Days of DevOps

This is **Day 1** of a 30-day DevOps project series. Each day builds progressively on the previous:

| Day | Topic |
|---|---|
| Day 1 | ✅ System Health Monitor (this project) |
| Day 2 | Log Analyzer & Report Generator |
| Day 3 | Automated Backup with Rotation |
| ... | Docker, CI/CD, Kubernetes, Terraform |

Follow along: [github.com/YOUR_USERNAME](https://github.com/YOUR_USERNAME)

---

## 📄 License

MIT License — free to use, modify, and distribute.
