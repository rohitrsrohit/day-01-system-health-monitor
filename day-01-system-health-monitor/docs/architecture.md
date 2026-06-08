# Architecture — System Health Monitor

## How It Works

```
/proc/stat      ──► get_cpu_usage()   ──►┐
/proc/meminfo   ──► get_ram_usage()   ──►├──► generate_report() ──► terminal output
df (disk)       ──► get_disk_usage()  ──►│                      ──► logs/report_*.txt
ps aux          ──► top processes     ──►│
systemctl       ──► check_services()  ──►┘
                                              │
                                              ▼
                                     threshold check
                                              │
                                    ┌─────────┴────────┐
                                  OK │                 BREACH │
                                    ▼                         ▼
                                 log INFO              send_alert()
                                                            │
                                                   ┌────────┴────────┐
                                               email OFF          email ON
                                                   │                  │
                                               stderr             mail cmd
```

## Key Design Decisions

- **`/proc` filesystem** used directly — no external tools like `vmstat` needed
- **1-second CPU delta** — more accurate than a single snapshot
- **`MemAvailable` not `MemFree`** — correctly accounts for reclaimable cache
- **`set -euo pipefail`** — fail fast on errors, unbound variables, and pipe failures
- **Config sourced externally** — no hardcoded values in script
- **Log rotation built-in** — no need for `logrotate` config
