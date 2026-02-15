# Index - thepopebot Process Audit & systemd Setup Kit

**Job ID:** 3b8ea412-1973-42a8-bd63-a6a97150af91  
**Created:** 2026-02-15T18:25:05Z  
**Agent:** thepopebot Docker Agent

---

## 📁 File Manifest

| File | Type | Lines | Size | Purpose |
|------|------|-------|------|---------|
| **INDEX.md** | Documentation | — | — | This file - quick navigation |
| **README.md** | Documentation | 179 | 5.8 KB | Start here - quick start guide |
| **SUMMARY.md** | Documentation | 299 | 8.9 KB | Job summary and workflow |
| **PROCESS_AUDIT_REPORT.md** | Documentation | 746 | 18 KB | Comprehensive reference guide |
| **quick-check.sh** | Script (executable) | 150 | 4.3 KB | Diagnostic tool |
| **stop-processes.sh** | Script (executable) | 227 | 6.9 KB | Safe shutdown tool |
| **thepopebot.service.template** | Config | 107 | 3.2 KB | systemd service file |

**Total deliverables:** 7 files, 1,708 lines, ~47 KB

---

## 🚀 Getting Started

### For First-Time Users

**Start here → [README.md](README.md)**

Quick 3-step process:
1. Run `./quick-check.sh` to see current state
2. Run `./stop-processes.sh` to cleanup
3. Follow systemd setup in README.md

### For Detailed Information

**Read this → [PROCESS_AUDIT_REPORT.md](PROCESS_AUDIT_REPORT.md)**

Comprehensive 18KB guide with:
- All diagnostic commands
- Multiple shutdown methods
- Step-by-step systemd setup
- Troubleshooting guide
- Daily operations
- Migration checklist

### For Context & Overview

**Check this → [SUMMARY.md](SUMMARY.md)**

High-level overview with:
- What was discovered
- What was delivered
- Recommended workflow with time estimates
- Key insights about architecture
- Success criteria

---

## 🔧 Tools

### quick-check.sh

**Purpose:** Fast system diagnostic

**What it checks:**
- Node.js processes (details + PIDs)
- Port 3000 usage
- Screen sessions
- PM2 processes
- systemd service status

**Output:** Color-coded (green/yellow/red) with summary

**Runtime:** ~1 second

**Usage:**
```bash
./quick-check.sh
```

**When to use:**
- Before migration (see current state)
- After stopping processes (verify clean)
- After systemd setup (verify service running)
- Anytime you want quick status

---

### stop-processes.sh

**Purpose:** Safe interactive shutdown

**What it does:**
- Stops PM2 processes (asks first)
- Terminates screen sessions (asks first)
- Stops systemd service (asks first)
- Kills Node.js processes (graceful → force)
- Frees port 3000 if blocked

**Output:** Color-coded with progress indicators

**Runtime:** 30 seconds - 2 minutes (depends on processes)

**Usage:**
```bash
./stop-processes.sh
```

**When to use:**
- Before systemd migration
- When switching from PM2/screen
- To completely reset
- When port 3000 is blocked

**Safety:** Asks before every destructive action

---

### thepopebot.service.template

**Purpose:** Production systemd service

**Features:**
- Security hardening (NoNewPrivileges, ProtectSystem, etc.)
- Resource limits (Memory, CPU)
- Auto-restart on failure
- Logging (journald + files)
- Environment variable loading

**Requires customization:**
- [ ] `User=YOUR_USERNAME`
- [ ] `WorkingDirectory=/FULL/PATH/TO/event_handler`
- [ ] `ExecStart=/FULL/PATH/TO/node server.js`
- [ ] `EnvironmentFile=/FULL/PATH/TO/.env`
- [ ] `ReadWritePaths=/FULL/PATH/TO/thepopebot`

**Installation:**
```bash
# After customizing
sudo cp thepopebot.service.template /etc/systemd/system/thepopebot.service
sudo systemctl daemon-reload
sudo systemctl start thepopebot
```

---

## 📖 Documentation Structure

```
┌─────────────────────────────────────────────────────────────┐
│                        INDEX.md                              │
│                    (You are here)                            │
│                  Quick navigation hub                        │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┬─────────────────┐
                │             │             │                 │
                ▼             ▼             ▼                 ▼
        ┌───────────┐ ┌──────────┐  ┌──────────┐    ┌────────────┐
        │ README.md │ │SUMMARY.md│  │ PROCESS_ │    │   Tools    │
        │           │ │          │  │ AUDIT_   │    │            │
        │ • Quick   │ │• Context │  │ REPORT   │    │ • quick-   │
        │   start   │ │• What    │  │          │    │   check.sh │
        │ • 3 steps │ │  we did  │  │• Complete│    │            │
        │ • Simple  │ │• Workflow│  │  guide   │    │ • stop-    │
        │           │ │• Time    │  │• All     │    │   processes│
        │           │ │  est.    │  │  commands│    │   .sh      │
        └───────────┘ └──────────┘  │• Trouble-│    │            │
                                     │  shoot   │    │ • service  │
                                     │• FAQ     │    │   template │
                                     └──────────┘    └────────────┘
```

### Reading Order by User Type

**New User (Never set up systemd):**
1. INDEX.md ← You are here
2. README.md (Quick start)
3. Run `./quick-check.sh`
4. Run `./stop-processes.sh` if needed
5. Follow systemd setup in README.md
6. Refer to PROCESS_AUDIT_REPORT.md for troubleshooting

**Experienced (Just need commands):**
1. INDEX.md ← You are here
2. Run `./quick-check.sh`
3. Customize `thepopebot.service.template`
4. Install and start service
5. Use PROCESS_AUDIT_REPORT.md as reference

**Troubleshooting:**
1. PROCESS_AUDIT_REPORT.md → "Common Issues & Solutions" section
2. PROCESS_AUDIT_REPORT.md → "Troubleshooting" under systemd setup
3. Run `./quick-check.sh` to see current state
4. Check logs: `sudo journalctl -u thepopebot -n 50`

---

## 🎯 Quick Command Reference

### Check Status
```bash
./quick-check.sh                           # Fast diagnostic
systemctl status thepopebot                 # If systemd installed
ps aux | grep node                          # Manual check
lsof -i :3000                               # Check port
```

### Stop Processes
```bash
./stop-processes.sh                         # Interactive safe stop
sudo systemctl stop thepopebot              # If systemd service
pm2 stop thepopebot                         # If using PM2
screen -X -S SESSION_NAME quit              # If using screen
```

### Start Service
```bash
sudo systemctl start thepopebot             # Start
systemctl status thepopebot                 # Check status
sudo journalctl -u thepopebot -f            # Watch logs
```

### Daily Operations
```bash
sudo systemctl restart thepopebot           # After code updates
systemctl status thepopebot                 # Quick status
sudo journalctl -u thepopebot --since "1h"  # Recent logs
```

---

## 🗺️ File Relationships

```
thepopebot.service.template
            │
            ├─→ Installed to: /etc/systemd/system/thepopebot.service
            └─→ References: event_handler/.env (environment vars)
                           event_handler/server.js (main process)
                           /var/log/thepopebot/*.log (logs)

quick-check.sh
            │
            └─→ Shows: Current process state
                      Readiness for systemd migration

stop-processes.sh
            │
            └─→ Stops: PM2, screen, systemd, Node.js processes
                      Makes system ready for fresh systemd install

README.md → Entry point → Links to all other docs
SUMMARY.md → Overview → Job results and workflow
PROCESS_AUDIT_REPORT.md → Reference → Complete guide
INDEX.md → Navigation → This file
```

---

## 📋 Migration Checklist

Quick reference from PROCESS_AUDIT_REPORT.md:

### Pre-Migration
- [ ] Run `./quick-check.sh` - document current state
- [ ] Backup `.env` and any custom configs
- [ ] Note current `screen`/PM2 settings

### Cleanup
- [ ] Run `./stop-processes.sh`
- [ ] Verify port 3000 free: `lsof -i :3000`
- [ ] Confirm no node processes: `ps aux | grep node`

### Setup
- [ ] Customize `thepopebot.service.template`
- [ ] Create log directory: `/var/log/thepopebot`
- [ ] Copy to systemd: `/etc/systemd/system/`
- [ ] `sudo systemctl daemon-reload`

### Testing
- [ ] `sudo systemctl start thepopebot`
- [ ] Check status: `systemctl status thepopebot`
- [ ] Test webhook endpoint
- [ ] Test Telegram bot
- [ ] Watch logs: `sudo journalctl -u thepopebot -f`

### Production
- [ ] `sudo systemctl enable thepopebot`
- [ ] Test reboot (optional)
- [ ] Monitor for 24 hours
- [ ] Remove old backups (after stable)

---

## ⏱️ Time Estimates

| Task | Fast Path | Typical | Complex |
|------|-----------|---------|---------|
| Assessment (`./quick-check.sh`) | 1 min | 2 min | 5 min |
| Cleanup (`./stop-processes.sh`) | 0 min* | 5 min | 20 min |
| Configuration (edit template) | 5 min | 10 min | 15 min |
| Installation (systemd) | 5 min | 5 min | 10 min |
| Testing (verify working) | 5 min | 10 min | 30 min |
| **Total** | **16 min** | **32 min** | **80 min** |

*Fast path = no processes running (system already clean)

---

## 🆘 Emergency Commands

### System Unresponsive
```bash
sudo systemctl stop thepopebot
sudo pkill -9 -f "node.*server.js"
lsof -ti :3000 | xargs kill -9
```

### Port 3000 Blocked
```bash
lsof -ti :3000                    # Find PID
lsof -ti :3000 | xargs kill -15   # Graceful
lsof -ti :3000 | xargs kill -9    # Force
```

### Service Won't Start
```bash
sudo journalctl -u thepopebot -n 50 --no-pager   # Check errors
cd /path/to/event_handler && node server.js     # Test manual
sudo systemctl daemon-reload                     # Reload config
```

### View Errors
```bash
sudo journalctl -u thepopebot -p err              # Only errors
sudo journalctl -u thepopebot --since "10m"       # Last 10 min
tail -f /var/log/thepopebot/error.log             # Error log
```

---

## 📊 System Requirements

### Host System
- Linux with systemd (most modern distros)
- sudo/root access for service installation
- Node.js 18+ installed
- Port 3000 available (or configure different port)
- Disk space: ~500MB for logs (with rotation)

### For Scripts
- bash shell (standard on Linux)
- Basic commands: `ps`, `grep`, `awk`, `kill`
- Optional: `lsof`, `netstat`, `ss`, `screen`, `pm2`, `systemctl`

### Minimum Specs
- RAM: 256MB for event handler (512MB recommended)
- CPU: 1 core minimum
- Disk: 1GB (logs grow over time)

---

## 🔐 Security Notes

The systemd service template includes:

| Feature | Purpose |
|---------|---------|
| `NoNewPrivileges=true` | Prevents privilege escalation |
| `PrivateTmp=true` | Isolated /tmp (can't see other processes' temp files) |
| `ProtectSystem=strict` | Read-only access to /usr, /boot, /efi |
| `ProtectHome=true` | No access to other users' home directories |
| `ReadWritePaths=` | Explicit list of writable locations |
| `MemoryMax=1G` | Prevents memory exhaustion |
| `CPUQuota=50%` | Prevents CPU hogging |

All secrets remain in `.env` file, loaded via `EnvironmentFile=`.

---

## 🔄 Next Steps After Setup

### Immediate (First 24 Hours)
1. Monitor logs: `sudo journalctl -u thepopebot -f`
2. Test all functionality (Telegram, webhooks, cron jobs)
3. Verify auto-restart on failure (kill process, watch it restart)
4. Check resource usage: `systemctl status thepopebot`

### First Week
1. Set up log rotation (`/etc/logrotate.d/thepopebot`)
2. Monitor memory usage trends
3. Verify all scheduled jobs (cron) work correctly
4. Test reboot recovery

### Ongoing Maintenance
1. Check logs weekly for errors
2. Update dependencies monthly: `npm update`
3. Review and clean old job logs
4. Keep host system updated
5. Backup `.env` and custom configurations

---

## 📞 Getting Help

### Built-in Help
```bash
./quick-check.sh --help          # (or read the script)
./stop-processes.sh --help       # (or read the script)
man systemd.service              # systemd documentation
man systemctl                    # systemctl commands
```

### Documentation Files
- Quick problems → README.md troubleshooting section
- Detailed problems → PROCESS_AUDIT_REPORT.md "Common Issues"
- Understanding → SUMMARY.md "Key Insights"
- Reference → PROCESS_AUDIT_REPORT.md

### System Logs
```bash
sudo journalctl -u thepopebot -n 100      # Last 100 lines
sudo journalctl -u thepopebot --since "1h" # Last hour
sudo journalctl -u thepopebot -f          # Follow live
```

---

## 📝 Notes

- **Scripts are safe** - They ask before doing anything destructive
- **Color output** - Green = good, Yellow = attention, Red = error
- **Idempotent** - Safe to run scripts multiple times
- **Self-contained** - Everything you need is in this directory
- **Host system only** - All commands must run on HOST, not in Docker

---

## ✅ Verification

After setup, you should see:

```bash
$ systemctl status thepopebot
● thepopebot.service - thepopebot Event Handler
     Loaded: loaded (/etc/systemd/system/thepopebot.service; enabled)
     Active: active (running) since ...
```

```bash
$ ./quick-check.sh
...
✓ thepopebot is running via systemd
```

```bash
$ sudo journalctl -u thepopebot --since "1m"
...
[No errors]
```

---

**Generated by:** thepopebot Docker Agent  
**Job ID:** 3b8ea412-1973-42a8-bd63-a6a97150af91  
**Date:** 2026-02-15T18:25:05Z

**All deliverables ready.** Start with [README.md](README.md) for quick setup!
