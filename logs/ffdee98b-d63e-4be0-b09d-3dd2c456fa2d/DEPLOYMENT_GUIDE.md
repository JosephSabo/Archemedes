# thepopebot systemd Deployment Guide

**Complete guide for migrating thepopebot to systemd service**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Detailed Steps](#detailed-steps)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)
7. [Rollback](#rollback)
8. [Maintenance](#maintenance)

---

## Overview

This deployment package migrates your thepopebot Event Handler from manual execution to a managed systemd service. This provides:

✅ **Automatic startup** - Starts on system boot  
✅ **Automatic restart** - Recovers from crashes  
✅ **Centralized logging** - journald + file logs  
✅ **Resource limits** - Memory and CPU caps  
✅ **Security hardening** - Protected filesystem access  
✅ **Standard management** - systemctl commands  

### What Gets Deployed?

- **Event Handler** runs as systemd service
- **Docker Agent** continues via GitHub Actions (no changes)
- Logs go to `/var/log/thepopebot/` and journald
- Service runs as your user (not root)

### Timeline

- **Pre-flight checks**: 5 minutes
- **Backup**: 2 minutes
- **Stop processes**: 5 minutes
- **Deployment**: 10 minutes
- **Verification**: 5 minutes
- **Total**: ~30 minutes

---

## Prerequisites

### System Requirements

- ✅ Linux with systemd (Ubuntu 16.04+, Debian 8+, CentOS 7+, etc.)
- ✅ Node.js 14+ installed
- ✅ sudo/root access for systemd operations
- ✅ thepopebot repository cloned
- ✅ Event Handler configured (`.env` file)

### Check Your System

```bash
# Check systemd
systemctl --version

# Check Node.js
node --version
npm --version

# Check repository
ls -la /path/to/thepopebot/event_handler/server.js

# Check .env
ls -la /path/to/thepopebot/event_handler/.env
```

### What You Need

1. Path to thepopebot repository
2. Current user account (non-root)
3. Active terminal session with sudo access
4. 5-10 minutes of downtime (while migrating)

---

## Quick Start

**⚡ Fast path for experienced users:**

```bash
# Navigate to deployment directory
cd /path/to/thepopebot/logs/YOUR_JOB_ID/deployment/

# 1. Backup (2 min)
./01-backup.sh

# 2. Diagnostic (1 min)
./02-diagnostic.sh

# 3. Stop processes (3 min)
./03-stop-processes.sh

# 4. Deploy (5 min)
./04-deploy.sh

# 5. Verify (2 min)
./05-verify.sh

# 6. Watch logs
sudo journalctl -u thepopebot -f
```

**Done!** Your thepopebot is now running as a systemd service.

---

## Detailed Steps

### Step 1: Backup (Required)

**Purpose**: Create a complete backup before making changes.

```bash
./01-backup.sh
```

**What it does:**
- Copies `.env`, `package.json`, code, config
- Captures current process state
- Creates timestamped backup directory
- Generates restore script

**Output:**
```
✓ Backup location: /path/to/thepopebot/backups/pre-systemd-20260215_184500/
✓ Ready to proceed with deployment
```

**Rollback later:**
```bash
# If you need to undo changes
/path/to/thepopebot/backups/pre-systemd-TIMESTAMP/RESTORE.sh
```

---

### Step 2: Diagnostic Check (Required)

**Purpose**: Verify system readiness and identify issues.

```bash
./02-diagnostic.sh
```

**What it checks:**
- Node.js and npm installed
- systemd available
- Repository structure
- Running processes
- Port 3000 availability
- Environment configuration
- Permissions

**Expected result:**
```
✓✓✓ ALL CHECKS PASSED ✓✓✓
System is ready for deployment!
```

**If warnings appear:**
```
⚠ WARNINGS DETECTED

You can proceed, but consider addressing warnings:
  • Stop running Node.js processes (run ./03-stop-processes.sh)
  
Next step: Run ./03-stop-processes.sh
```

**If errors appear:**
```
✗ CRITICAL ISSUES FOUND

Cannot proceed with deployment. Fix errors above first.
```

Fix the errors and run diagnostic again.

---

### Step 3: Stop Existing Processes (If Needed)

**Purpose**: Safely stop any running thepopebot instances.

```bash
./03-stop-processes.sh
```

**What it does:**
- Stops systemd service (if running)
- Stops PM2 processes
- Closes screen sessions
- Terminates Node.js processes
- Frees port 3000
- Interactive confirmation for each action

**Example interaction:**
```
1. Checking systemd service...
-----------------------------------
systemd service not running

2. Checking PM2 processes...
-----------------------------------
Found PM2 process 'thepopebot'
Stop PM2 process 'thepopebot'? (Y/n): y
✓ PM2 process 'thepopebot' stopped and removed

3. Checking screen sessions...
-----------------------------------
Found screen sessions:
  12345.pts-0.hostname
Stop screen session '12345.pts-0.hostname'? (y/N): y
✓ Screen session terminated
```

**Expected result:**
```
✓✓✓ System is clean - ready for deployment! ✓✓✓

Next step: Run ./04-deploy.sh
```

---

### Step 4: Deploy systemd Service (The Big One)

**Purpose**: Install and start the systemd service.

```bash
./04-deploy.sh
```

**What it does:**

1. **Detects configuration** automatically
   - Your username
   - Node.js path
   - Repository location
   
2. **Installs dependencies** (if needed)
   ```
   npm install
   ```

3. **Creates log directory**
   ```
   /var/log/thepopebot/
   ```

4. **Generates service file**
   - Pre-configured for your system
   - Reviews with you before installing

5. **Installs service**
   ```
   /etc/systemd/system/thepopebot.service
   ```

6. **Starts service**
   ```
   sudo systemctl start thepopebot
   ```

7. **Enables auto-start** (optional)
   ```
   sudo systemctl enable thepopebot
   ```

**Example interaction:**
```
Detecting system configuration...
-----------------------------------
• Username: youruser
• Node.js: /usr/bin/node (v18.17.0)
• .env file: Found
• Dependencies: Installed

Configuration to use:
-----------------------------------
User: youruser
Node: /usr/bin/node
Working Directory: /home/youruser/thepopebot/event_handler
Repository Root: /home/youruser/thepopebot

Is this configuration correct? (y/N): y

...

Starting thepopebot service...
✓ Service started successfully!

Enable thepopebot to start automatically on system boot? (Y/n): y
✓ Auto-start enabled
```

**Expected result:**
```
✓✓✓ Deployment Complete! ✓✓✓

✓ thepopebot is now running as a systemd service

Service Details:
  • Status: active
  • Enabled: enabled
  • User: youruser
  • Working Directory: /home/youruser/thepopebot/event_handler
  • Logs: /var/log/thepopebot/

Next step: Run ./05-verify.sh
```

---

### Step 5: Verification (Recommended)

**Purpose**: Test that deployment was successful.

```bash
./05-verify.sh
```

**What it tests:**

1. **Service Status** (4 tests)
   - Service file installed
   - Service running
   - Auto-start enabled
   - Not in failed state

2. **Process Tests** (3 tests)
   - Node.js process running
   - Port 3000 listening
   - Single instance only

3. **Log Tests** (5 tests)
   - Log directory exists and writable
   - Output log created
   - Error log empty
   - Recent logs in journald

4. **Configuration** (5 tests)
   - .env file exists
   - Required variables set
   - Dependencies installed

5. **Network** (2 tests)
   - HTTP server responding
   - Listening on correct port

6. **Resources** (3 tests)
   - Memory usage reasonable
   - CPU usage normal
   - Process uptime

7. **Security** (3 tests)
   - File permissions correct
   - Not running as root

**Expected result:**
```
✓✓✓ ALL TESTS PASSED! ✓✓✓

Your thepopebot deployment is working correctly!

Tests run: 25
Passed: 25
Failed: 0
Skipped: 0
```

**If tests fail:**
```
✗ SOME TESTS FAILED ✗

Issues detected. Review failed tests above.

Troubleshooting:
1. Check service status: systemctl status thepopebot
2. View logs: sudo journalctl -u thepopebot -n 100
3. Check error log: tail -f /var/log/thepopebot/error.log
```

---

## Verification

### Quick Status Check

```bash
# Service status
systemctl status thepopebot

# Is it running?
systemctl is-active thepopebot

# Is auto-start enabled?
systemctl is-enabled thepopebot
```

### View Logs

```bash
# Follow live logs (journald)
sudo journalctl -u thepopebot -f

# Last 100 lines
sudo journalctl -u thepopebot -n 100

# Logs since boot
sudo journalctl -u thepopebot -b

# Output log file
tail -f /var/log/thepopebot/output.log

# Error log file
tail -f /var/log/thepopebot/error.log
```

### Test Endpoints

```bash
# Test webhook (if configured)
curl -X POST http://localhost:3000/webhook \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"test": "hello"}'

# Check Telegram bot (if configured)
# Send message to your bot in Telegram
```

### Check Resources

```bash
# Memory usage
systemctl status thepopebot | grep Memory

# CPU usage
systemctl status thepopebot | grep CPU

# Detailed stats
systemctl show thepopebot
```

---

## Troubleshooting

### Service Won't Start

**Symptom**: `systemctl start thepopebot` fails

**Diagnosis:**
```bash
# Check status
systemctl status thepopebot

# View logs
sudo journalctl -u thepopebot -n 50

# Check what failed
sudo journalctl -u thepopebot --since "5 minutes ago"
```

**Common causes:**

1. **Missing .env file**
   ```bash
   ls -la /path/to/thepopebot/event_handler/.env
   ```
   **Fix**: Copy `.env.example` and configure

2. **Port 3000 in use**
   ```bash
   lsof -i :3000
   ```
   **Fix**: Stop conflicting process or change PORT in .env

3. **Wrong paths in service file**
   ```bash
   cat /etc/systemd/system/thepopebot.service
   ```
   **Fix**: Edit service file, reload: `sudo systemctl daemon-reload`

4. **Missing dependencies**
   ```bash
   cd /path/to/thepopebot/event_handler
   npm install
   ```

5. **Permission denied**
   ```bash
   # Check log directory
   ls -la /var/log/thepopebot
   
   # Fix ownership
   sudo chown YOUR_USER:YOUR_USER /var/log/thepopebot
   ```

### Service Keeps Restarting

**Symptom**: Service status shows restarts

**Diagnosis:**
```bash
# Watch status
watch -n 1 'systemctl status thepopebot'

# Check crash logs
sudo journalctl -u thepopebot -f

# Check error log
tail -f /var/log/thepopebot/error.log
```

**Common causes:**

1. **Uncaught exception** → Fix code bug
2. **Missing environment variable** → Check .env
3. **Database connection** → Check external services
4. **File system errors** → Check permissions

### Can't Connect to Webhook

**Symptom**: Webhook requests fail or timeout

**Checks:**
```bash
# Is service running?
systemctl is-active thepopebot

# Is port listening?
lsof -i :3000

# Test locally
curl http://localhost:3000/webhook

# Check firewall
sudo ufw status
sudo iptables -L
```

### High Memory Usage

**Symptom**: Service using too much memory

**Check:**
```bash
# Current usage
systemctl status thepopebot | grep Memory

# Restart to clear
sudo systemctl restart thepopebot
```

**Fix**: Adjust limit in service file
```bash
sudo nano /etc/systemd/system/thepopebot.service

# Change:
MemoryMax=1G

# To:
MemoryMax=2G

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart thepopebot
```

---

## Rollback

### When to Rollback

- Service won't start after multiple attempts
- Critical functionality broken
- Performance issues with systemd
- Need to revert to manual management

### How to Rollback

**Option 1: Use rollback script**
```bash
./06-rollback.sh
```

This will:
1. Stop the service
2. Disable auto-start  
3. Remove service file
4. Optionally restore from backup
5. Optionally clean up logs

**Option 2: Manual rollback**
```bash
# 1. Stop service
sudo systemctl stop thepopebot
sudo systemctl disable thepopebot

# 2. Remove service file
sudo rm /etc/systemd/system/thepopebot.service
sudo systemctl daemon-reload

# 3. Restore backup (if needed)
/path/to/thepopebot/backups/pre-systemd-TIMESTAMP/RESTORE.sh

# 4. Start manually
cd /path/to/thepopebot/event_handler
node server.js
```

### After Rollback

You can run thepopebot manually:

```bash
# Simple
cd /path/to/thepopebot/event_handler
node server.js

# With PM2
pm2 start server.js --name thepopebot
pm2 save

# In screen
screen -S thepopebot
cd /path/to/thepopebot/event_handler
node server.js
# Ctrl+A, D to detach
```

---

## Maintenance

### Daily Operations

**Start/Stop/Restart:**
```bash
sudo systemctl start thepopebot
sudo systemctl stop thepopebot
sudo systemctl restart thepopebot
```

**Check status:**
```bash
systemctl status thepopebot
```

**View logs:**
```bash
# Live logs
sudo journalctl -u thepopebot -f

# Recent logs
sudo journalctl -u thepopebot -n 100

# Today's logs
sudo journalctl -u thepopebot --since today

# Search logs
sudo journalctl -u thepopebot | grep ERROR
```

### Updates

**Update code:**
```bash
# 1. Stop service
sudo systemctl stop thepopebot

# 2. Update repository
cd /path/to/thepopebot
git pull

# 3. Update dependencies
cd event_handler
npm install

# 4. Start service
sudo systemctl start thepopebot

# 5. Verify
systemctl status thepopebot
```

**Update configuration:**
```bash
# Edit .env
nano /path/to/thepopebot/event_handler/.env

# Restart to apply
sudo systemctl restart thepopebot
```

**Update service file:**
```bash
# Edit service
sudo nano /etc/systemd/system/thepopebot.service

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart thepopebot
```

### Log Management

**View log sizes:**
```bash
du -sh /var/log/thepopebot
journalctl --disk-usage
```

**Rotate logs:**
```bash
# Truncate old logs
sudo truncate -s 0 /var/log/thepopebot/output.log
sudo truncate -s 0 /var/log/thepopebot/error.log

# Or archive
cd /var/log/thepopebot
sudo tar -czf archive-$(date +%Y%m%d).tar.gz *.log
sudo truncate -s 0 *.log
```

**Clean journald:**
```bash
# Keep last 1 week
sudo journalctl --vacuum-time=1w

# Keep last 100MB
sudo journalctl --vacuum-size=100M
```

### Health Checks

**Manual check:**
```bash
# Run verification
cd /path/to/deployment
./05-verify.sh
```

**Automated monitoring:**
```bash
# Add to crontab
crontab -e

# Check every 5 minutes
*/5 * * * * systemctl is-active --quiet thepopebot || /path/to/restart-script.sh
```

---

## Quick Reference

### Service Commands

```bash
# Status
systemctl status thepopebot
systemctl is-active thepopebot
systemctl is-enabled thepopebot

# Control
sudo systemctl start thepopebot
sudo systemctl stop thepopebot
sudo systemctl restart thepopebot
sudo systemctl reload thepopebot

# Auto-start
sudo systemctl enable thepopebot
sudo systemctl disable thepopebot

# Reload configuration
sudo systemctl daemon-reload
```

### Log Commands

```bash
# journald
sudo journalctl -u thepopebot -f          # Follow live
sudo journalctl -u thepopebot -n 100      # Last 100 lines
sudo journalctl -u thepopebot --since today
sudo journalctl -u thepopebot --since "1 hour ago"

# Files
tail -f /var/log/thepopebot/output.log    # Output
tail -f /var/log/thepopebot/error.log     # Errors
grep ERROR /var/log/thepopebot/*.log      # Search
```

### File Locations

```bash
# Service file
/etc/systemd/system/thepopebot.service

# Logs
/var/log/thepopebot/output.log
/var/log/thepopebot/error.log
sudo journalctl -u thepopebot

# Configuration
/path/to/thepopebot/event_handler/.env

# Backups
/path/to/thepopebot/backups/pre-systemd-*/
```

---

## Support

### Documentation

- **This guide**: Complete deployment reference
- **PROCESS_AUDIT_REPORT.md**: Original system audit
- **Repository README.md**: thepopebot architecture
- **CLAUDE.md**: Agent behavior and skills

### Scripts

```
01-backup.sh          → Create pre-deployment backup
02-diagnostic.sh      → System readiness check
03-stop-processes.sh  → Stop existing instances
04-deploy.sh          → Install and start service
05-verify.sh          → Test deployment
06-rollback.sh        → Undo deployment
```

### Getting Help

1. **Check verification**: `./05-verify.sh`
2. **View logs**: `sudo journalctl -u thepopebot -n 100`
3. **Check status**: `systemctl status thepopebot`
4. **Review this guide**: Search for your issue above

---

**Generated by thepopebot Docker Agent**  
**Job ID**: `ffdee98b-d63e-4be0-b09d-3dd2c456fa2d`  
**Date**: 2026-02-15
