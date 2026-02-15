# thepopebot systemd Deployment Package

**Complete automated deployment system for migrating thepopebot to systemd**

---

## 🚀 Quick Start

```bash
./01-backup.sh           # Create backup (2 min)
./02-diagnostic.sh       # Check system (1 min)
./03-stop-processes.sh   # Stop processes (3 min)
./04-deploy.sh           # Deploy service (5 min)
./05-verify.sh           # Verify deployment (2 min)
```

**Total time**: ~15 minutes

---

## 📦 What's Included

### Scripts

| Script | Purpose | Time |
|--------|---------|------|
| `01-backup.sh` | Create complete backup before deployment | 2 min |
| `02-diagnostic.sh` | Comprehensive system readiness check | 1 min |
| `03-stop-processes.sh` | Safely stop existing thepopebot instances | 3 min |
| `04-deploy.sh` | Automated systemd service installation | 5 min |
| `05-verify.sh` | 25+ tests to validate deployment | 2 min |
| `06-rollback.sh` | Complete rollback and restore | 3 min |

### Documentation

| File | Description |
|------|-------------|
| `DEPLOYMENT_GUIDE.md` | **START HERE** - Complete deployment manual |
| `README.md` | This file - Quick navigation |
| `PROCESS_OVERVIEW.md` | Technical details and architecture |

### Generated Files

These are created during deployment:

- `thepopebot.service` - systemd service configuration
- `/var/log/thepopebot/` - Log directory
- Backups in `../../backups/pre-systemd-TIMESTAMP/`

---

## 📖 Documentation

### For First-Time Users

**Read**: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

This comprehensive guide covers:
- Prerequisites and system requirements
- Step-by-step instructions with examples
- Troubleshooting common issues
- Rollback procedures
- Daily maintenance

### For Quick Reference

**Use**: This README

Jump directly to the script you need and run it.

### For Technical Details

**See**: [PROCESS_OVERVIEW.md](PROCESS_OVERVIEW.md)

Explains how everything works under the hood.

---

## ⚡ Usage Scenarios

### Scenario 1: Clean Installation

**System**: No thepopebot running

```bash
./01-backup.sh          # Quick backup
./02-diagnostic.sh      # Should pass with no warnings
./04-deploy.sh          # Skip stop-processes
./05-verify.sh          # Validate
```

### Scenario 2: Migration from Manual

**System**: Running `node server.js` manually

```bash
./01-backup.sh          # Backup current state
./02-diagnostic.sh      # Will show warnings
./03-stop-processes.sh  # Kill manual process
./04-deploy.sh          # Install service
./05-verify.sh          # Validate
```

### Scenario 3: Migration from PM2

**System**: Running via PM2

```bash
./01-backup.sh          # Backup
./02-diagnostic.sh      # Will detect PM2
./03-stop-processes.sh  # Stop PM2 process
./04-deploy.sh          # Install service
./05-verify.sh          # Validate
```

### Scenario 4: Migration from screen

**System**: Running in screen session

```bash
./01-backup.sh          # Backup
./02-diagnostic.sh      # Will detect screen
./03-stop-processes.sh  # Close screen session
./04-deploy.sh          # Install service
./05-verify.sh          # Validate
```

### Scenario 5: Rollback

**Problem**: Deployment didn't work

```bash
./06-rollback.sh        # Remove service
# Choose to restore from backup
# Start manually if needed
```

---

## ✅ Pre-Flight Checklist

Before running any scripts, verify:

- [ ] Linux system with systemd
- [ ] Node.js 14+ installed (`node --version`)
- [ ] sudo/root access (`sudo echo "test"`)
- [ ] thepopebot repository cloned
- [ ] `.env` file configured in `event_handler/`
- [ ] 10-15 minutes available
- [ ] Can tolerate brief downtime

---

## 🔍 What Each Script Does

### 01-backup.sh

**What**: Creates comprehensive backup

**Creates**:
- Timestamped backup directory
- Copy of all configuration files
- Copy of event handler code
- Copy of operating system config
- Current process state snapshot
- Restore script for rollback

**Output**: `../../backups/pre-systemd-TIMESTAMP/`

**Safety**: Non-destructive, can run multiple times

---

### 02-diagnostic.sh

**What**: Verifies system readiness

**Checks** (8 sections, 20+ checks):
1. System requirements (Node.js, npm, systemd, git)
2. Repository structure (directories, files, dependencies)
3. Running processes (Node.js, port 3000)
4. Process managers (PM2, screen)
5. Existing systemd service
6. File permissions
7. Environment configuration
8. Overall readiness

**Output**: PASS (green), WARN (yellow), or ERROR (red)

**Safe**: Read-only, doesn't change anything

---

### 03-stop-processes.sh

**What**: Safely stops existing instances

**Stops** (in order):
1. systemd service (if running)
2. PM2 processes
3. screen sessions
4. Node.js processes
5. Processes on port 3000

**Features**:
- Interactive - asks before each action
- Graceful shutdown (SIGTERM) first
- Force kill (SIGKILL) if needed
- Verifies everything stopped

**Safe**: Prompts before destructive actions

---

### 04-deploy.sh

**What**: Installs and starts systemd service

**Does**:
1. Auto-detects configuration (user, paths, Node.js)
2. Installs dependencies (if needed)
3. Creates log directory (`/var/log/thepopebot`)
4. Generates service file (customized for your system)
5. Installs service to `/etc/systemd/system/`
6. Reloads systemd
7. Starts service
8. Optionally enables auto-start

**Interactive**: Confirms configuration before installing

**Backup**: Backs up existing service file if present

---

### 05-verify.sh

**What**: Comprehensive deployment testing

**Tests** (7 sections, 25+ tests):
1. Service Status (4 tests)
2. Process Tests (3 tests)
3. Log Tests (5 tests)
4. Configuration (5 tests)
5. Network (2 tests)
6. Resources (3 tests)
7. Security (3 tests)

**Output**: PASS/FAIL/SKIP/WARN for each test

**Result**: Overall success or failure with troubleshooting

**Safe**: Read-only checks

---

### 06-rollback.sh

**What**: Complete deployment rollback

**Does**:
1. Stops systemd service
2. Disables auto-start
3. Removes service file
4. Optionally restores from backup
5. Optionally cleans up logs
6. Verifies clean state

**Interactive**: Confirms each major action

**Safe**: Creates final backup before removing service file

---

## 🎯 Success Criteria

After deployment, you should see:

```bash
# Service is running
$ systemctl is-active thepopebot
active

# Auto-start enabled
$ systemctl is-enabled thepopebot
enabled

# Process running
$ ps aux | grep server.js
youruser  12345  0.5  1.2  ...  node server.js

# Port listening
$ lsof -i :3000
COMMAND   PID     USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
node    12345 youruser   22u  IPv6  ...      0t0  TCP *:3000 (LISTEN)

# Logs flowing
$ sudo journalctl -u thepopebot -n 5
-- Logs begin at ...
Feb 15 18:45:00 host thepopebot[12345]: Server listening on port 3000
```

---

## 🛠️ Quick Commands

### After Deployment

```bash
# Check status
systemctl status thepopebot

# View logs
sudo journalctl -u thepopebot -f

# Restart
sudo systemctl restart thepopebot

# Stop
sudo systemctl stop thepopebot

# Start
sudo systemctl start thepopebot
```

### Troubleshooting

```bash
# Why won't it start?
sudo journalctl -u thepopebot -n 50

# Is port free?
lsof -i :3000

# Test manual start
cd ../../event_handler && node server.js

# Reload service file
sudo systemctl daemon-reload
```

---

## ⚠️ Important Notes

### Running Location

**You are inside a Docker container.** These scripts must be run on your **HOST SYSTEM** where the Event Handler runs.

**To use on host**:

```bash
# On your host system:
cd /path/to/thepopebot/logs/ffdee98b-d63e-4be0-b09d-3dd2c456fa2d/deployment/
./01-backup.sh
```

### What Gets Managed

- ✅ **Event Handler** → systemd service (what these scripts deploy)
- ❌ **Docker Agent** → GitHub Actions (unchanged, still ephemeral)

### Downtime

Expect 2-5 minutes of downtime while:
- Stopping old instance
- Starting new systemd service

Plan accordingly for production systems.

### Permissions

Some commands require `sudo`:
- Installing service file
- Starting/stopping service
- Creating log directory
- Viewing journald logs

Make sure you have sudo access.

---

## 📞 Getting Help

### Problems During Deployment

1. **Read error messages** - Scripts provide detailed output
2. **Check logs** - Scripts tell you where to look
3. **Re-run diagnostic** - `./02-diagnostic.sh` shows current state
4. **Review guide** - [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) has troubleshooting section

### Problems After Deployment

1. **Run verification** - `./05-verify.sh` identifies issues
2. **Check service status** - `systemctl status thepopebot`
3. **View logs** - `sudo journalctl -u thepopebot -n 100`
4. **Rollback if needed** - `./06-rollback.sh`

### Emergency Rollback

```bash
# Quick rollback
./06-rollback.sh

# Or manual
sudo systemctl stop thepopebot
sudo systemctl disable thepopebot
sudo rm /etc/systemd/system/thepopebot.service
sudo systemctl daemon-reload

# Start manually
cd ../../event_handler
node server.js
```

---

## 📈 What's Next

After successful deployment:

1. ✅ **Monitor** - Watch logs for first 24 hours
2. ✅ **Test** - Verify all functionality (webhooks, Telegram, etc.)
3. ✅ **Document** - Note any configuration changes for your team
4. ✅ **Backup** - Keep the backup for at least a week
5. ✅ **Automate** - Set up monitoring/alerting if needed

---

## 🔒 Security Notes

The deployment includes security hardening:

- ✅ Runs as non-root user
- ✅ Protected filesystem access (`ProtectSystem=strict`)
- ✅ Private tmp directory (`PrivateTmp=true`)
- ✅ No privilege escalation (`NoNewPrivileges=true`)
- ✅ Resource limits (memory, CPU)
- ✅ Specific read/write paths only

---

## 📊 Files Created

### During Deployment

```
/etc/systemd/system/thepopebot.service          # Service definition
/var/log/thepopebot/                            # Log directory
  ├── output.log                                # Standard output
  └── error.log                                 # Standard error
../../backups/pre-systemd-TIMESTAMP/            # Backup directory
  ├── .env                                      # Config backup
  ├── event_handler/                            # Code backup
  ├── operating_system/                         # OS config backup
  ├── process-state.txt                         # Process snapshot
  ├── MANIFEST.txt                              # Backup index
  └── RESTORE.sh                                # Restore script
```

### In This Directory

```
01-backup.sh                # Backup script
02-diagnostic.sh            # Diagnostic script
03-stop-processes.sh        # Stop script
04-deploy.sh                # Deploy script
05-verify.sh                # Verify script
06-rollback.sh              # Rollback script
DEPLOYMENT_GUIDE.md         # Complete guide
README.md                   # This file
PROCESS_OVERVIEW.md         # Technical details
thepopebot.service          # Generated service file (after deploy)
```

---

## 🎓 Learning Resources

### systemd Basics

```bash
# View all services
systemctl list-units --type=service

# View failed services
systemctl --failed

# View service configuration
systemctl cat thepopebot

# Edit service (creates override)
sudo systemctl edit thepopebot

# Reload all configs
sudo systemctl daemon-reload
```

### Log Management

```bash
# journald disk usage
journalctl --disk-usage

# Vacuum old logs
sudo journalctl --vacuum-time=1w
sudo journalctl --vacuum-size=100M

# Rotate logs
sudo truncate -s 0 /var/log/thepopebot/*.log
```

---

**Ready to deploy?**

Start with: `./01-backup.sh`

For detailed instructions: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

---

**Generated by thepopebot Docker Agent**  
Job ID: `ffdee98b-d63e-4be0-b09d-3dd2c456fa2d`  
Date: 2026-02-15
