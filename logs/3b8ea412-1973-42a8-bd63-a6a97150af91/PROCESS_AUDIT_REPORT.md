# thepopebot Process Audit & systemd Setup Guide

**Date:** February 15, 2026  
**Environment:** Docker Agent Container  
**Job ID:** 3b8ea412-1973-42a8-bd63-a6a97150af91

---

## Executive Summary

This report documents the current process state and provides comprehensive instructions for:
1. Checking running thepopebot processes on your HOST system
2. Safely stopping existing processes before migration
3. Setting up and verifying a systemd service for permanent deployment

### Important Context

**You are reading this from inside the Docker Agent container.** The commands in this report are for your **HOST SYSTEM** where the Event Handler runs, not inside this container.

---

## Current Environment Analysis

### Docker Agent Container (This Environment)

Running processes inside this container (PID 1 = /bin/bash /entrypoint.sh):

| Process | PID | Memory | Description |
|---------|-----|--------|-------------|
| Chrome headless | 10 | 183 MB | Browser automation for Pi |
| Pi agent | 161 | 179 MB | The AI coding agent executing this job |
| Various Chrome subprocesses | Multiple | ~400 MB total | Renderer, GPU, network services |

**Key Finding:** 
- ✅ No systemd available (Docker container)
- ✅ This is the autonomous agent layer, not the event handler
- ✅ Event handler runs on HOST system outside this container

---

## Commands to Run on Your HOST System

### 1. Check for Running Node.js Processes

```bash
# Find all Node.js processes
ps aux | grep node | grep -v grep

# More detailed view with full command
ps aux | grep -E '(node|thepopebot)' | grep -v grep

# Find specific to event handler or server
pgrep -af "node.*server.js"
pgrep -af "node.*event_handler"
```

**What to look for:**
- Processes running `node server.js` or `node event_handler/server.js`
- PIDs, CPU%, MEM%, and command arguments
- Working directory (should be in your thepopebot clone)

### 2. Check for Processes on Port 3000

```bash
# Check what's listening on port 3000
lsof -i :3000

# Alternative if lsof not available
netstat -tlnp | grep :3000

# Or using ss (modern alternative)
ss -tlnp | grep :3000

# Find process by port
fuser 3000/tcp 2>/dev/null
```

**Expected output:**
```
node    12345 user  21u  IPv4  123456  0t0  TCP *:3000 (LISTEN)
```

### 3. Check for Screen Sessions

```bash
# List all screen sessions
screen -ls

# Look for thepopebot-related sessions
screen -ls | grep -E '(thepopebot|bot|event)'
```

**Common patterns:**
- `thepopebot-server`
- `bot-handler`
- `event-handler`

### 4. Check for PM2 Processes

```bash
# List PM2 processes
pm2 list

# Check PM2 status
pm2 status

# Show specific process info
pm2 info thepopebot 2>/dev/null
```

### 5. Check for Systemd Services

```bash
# Check if thepopebot service exists
systemctl status thepopebot

# List all running services with 'bot' in name
systemctl list-units --type=service --state=running | grep bot

# Check if service is enabled
systemctl is-enabled thepopebot 2>/dev/null
```

### 6. Memory and Resource Usage

```bash
# Total memory usage by Node.js
ps aux | grep node | grep -v grep | awk '{sum+=$6} END {print "Total Memory: " sum/1024 " MB"}'

# Detailed process tree
pstree -p | grep -A 5 -B 2 node

# Check system resources
free -h
df -h
```

---

## How to Safely Stop Existing Processes

### Method 1: Graceful Shutdown (Recommended)

If running in **screen**:
```bash
# List sessions
screen -ls

# Attach to session
screen -r <session-name>

# Then press: Ctrl+C to stop the process
# Then press: Ctrl+A then D to detach (if needed)

# Or kill the session directly
screen -X -S <session-name> quit
```

If running via **PM2**:
```bash
# Stop specific process
pm2 stop thepopebot

# Delete from PM2
pm2 delete thepopebot

# Save PM2 list (removes deleted processes)
pm2 save --force
```

If running as **systemd service**:
```bash
# Stop service
sudo systemctl stop thepopebot

# Disable from auto-start
sudo systemctl disable thepopebot

# Remove service file (optional)
sudo rm /etc/systemd/system/thepopebot.service
sudo systemctl daemon-reload
```

### Method 2: Direct Process Termination

```bash
# Find PID
PID=$(pgrep -f "node.*server.js")
echo "Found process: $PID"

# Graceful shutdown (SIGTERM)
kill -15 $PID

# Wait 10 seconds, then check if still running
sleep 10
ps -p $PID > /dev/null && echo "Process still running"

# Force kill if needed (SIGKILL)
# WARNING: May lose data or leave connections open
kill -9 $PID
```

### Method 3: Port-Based Termination

```bash
# Find process using port 3000
lsof -ti :3000

# Kill it gracefully
lsof -ti :3000 | xargs kill -15

# Or force kill
lsof -ti :3000 | xargs kill -9
```

### Verification After Stopping

```bash
# Verify no processes running
ps aux | grep node | grep -v grep
lsof -i :3000
screen -ls

# Check if port is free
nc -zv localhost 3000 && echo "Port 3000 is open" || echo "Port 3000 is free"
```

---

## systemd Service Setup Guide

### Prerequisites

1. **Root/sudo access** on your HOST system
2. **Event handler working** when run manually
3. **All processes stopped** as per instructions above
4. **Full path to Node.js**: `which node`
5. **Full path to repo**: `pwd` (from inside event_handler directory)

### Step 1: Create Service File

```bash
# Create service file
sudo nano /etc/systemd/system/thepopebot.service
```

**Service file template:**

```ini
[Unit]
Description=thepopebot Event Handler
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=YOUR_USERNAME
WorkingDirectory=/full/path/to/thepopebot/event_handler
Environment="NODE_ENV=production"
EnvironmentFile=/full/path/to/thepopebot/event_handler/.env
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=append:/var/log/thepopebot/output.log
StandardError=append:/var/log/thepopebot/error.log

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/full/path/to/thepopebot
ReadWritePaths=/var/log/thepopebot

[Install]
WantedBy=multi-user.target
```

**Customize these fields:**
- `User=YOUR_USERNAME` → Your Linux username (run `whoami`)
- `WorkingDirectory=` → Full path to `event_handler` directory
- `EnvironmentFile=` → Full path to `.env` file
- `ExecStart=` → Full path to node binary (run `which node`)
- `ReadWritePaths=` → Full path to repo root

### Step 2: Create Log Directory

```bash
sudo mkdir -p /var/log/thepopebot
sudo chown YOUR_USERNAME:YOUR_USERNAME /var/log/thepopebot
sudo chmod 755 /var/log/thepopebot
```

### Step 3: Verify Service Configuration

```bash
# Check syntax
sudo systemd-analyze verify /etc/systemd/system/thepopebot.service

# Reload systemd
sudo systemctl daemon-reload

# Check service file is loaded
systemctl cat thepopebot

# Check status (should be inactive/dead initially)
systemctl status thepopebot
```

### Step 4: Test Service Start

```bash
# Start service
sudo systemctl start thepopebot

# Check status
systemctl status thepopebot

# Should show:
# ● thepopebot.service - thepopebot Event Handler
#    Loaded: loaded (/etc/systemd/system/thepopebot.service; disabled)
#    Active: active (running) since [timestamp]

# View logs
sudo journalctl -u thepopebot -f

# Check application logs
tail -f /var/log/thepopebot/output.log
tail -f /var/log/thepopebot/error.log
```

### Step 5: Test Functionality

```bash
# Test webhook (replace with your API_KEY)
curl -X POST http://localhost:3000/webhook \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_API_KEY" \
  -d '{"job": "Test job from systemd service"}'

# Test Telegram (send a message to your bot)

# Check logs for activity
sudo journalctl -u thepopebot --since "1 minute ago"
```

### Step 6: Enable Auto-Start on Boot

```bash
# Enable service
sudo systemctl enable thepopebot

# Verify enabled
systemctl is-enabled thepopebot
# Should output: enabled

# Test reboot (optional but recommended)
sudo systemctl reboot

# After reboot, verify service started automatically
systemctl status thepopebot
```

---

## systemd Service Management Commands

### Daily Operations

```bash
# Start service
sudo systemctl start thepopebot

# Stop service
sudo systemctl stop thepopebot

# Restart service
sudo systemctl restart thepopebot

# Reload configuration without restart
sudo systemctl reload thepopebot

# Check status
systemctl status thepopebot

# View logs (live tail)
sudo journalctl -u thepopebot -f

# View logs (last 100 lines)
sudo journalctl -u thepopebot -n 100

# View logs (since specific time)
sudo journalctl -u thepopebot --since "1 hour ago"
sudo journalctl -u thepopebot --since "2024-02-15 10:00:00"

# Check if enabled for auto-start
systemctl is-enabled thepopebot

# Enable auto-start
sudo systemctl enable thepopebot

# Disable auto-start
sudo systemctl disable thepopebot
```

### Troubleshooting

```bash
# Check for errors
systemctl status thepopebot --no-pager
sudo journalctl -u thepopebot -p err

# Verify environment variables loaded
sudo systemctl show thepopebot --property=Environment

# Test service start in foreground (for debugging)
sudo -u YOUR_USERNAME bash -c 'cd /path/to/event_handler && node server.js'

# Check file permissions
ls -la /etc/systemd/system/thepopebot.service
ls -la /path/to/event_handler/.env
ls -la /var/log/thepopebot/

# Verify port not already in use
sudo lsof -i :3000
sudo netstat -tlnp | grep :3000

# Check SELinux/AppArmor (if applicable)
sudo getenforce  # SELinux
sudo aa-status   # AppArmor
```

### Updating Service Configuration

```bash
# Edit service file
sudo nano /etc/systemd/system/thepopebot.service

# Reload systemd after changes
sudo systemctl daemon-reload

# Restart service to apply changes
sudo systemctl restart thepopebot

# Verify changes
systemctl status thepopebot
```

---

## Expected Process Behavior

### Normal State (systemd running)

```bash
$ systemctl status thepopebot
● thepopebot.service - thepopebot Event Handler
     Loaded: loaded (/etc/systemd/system/thepopebot.service; enabled)
     Active: active (running) since Sat 2026-02-15 18:25:05 UTC; 1h ago
   Main PID: 12345 (node)
      Tasks: 11 (limit: 4915)
     Memory: 85.3M
        CPU: 2.456s
     CGroup: /system.slice/thepopebot.service
             └─12345 /usr/bin/node server.js

$ ps aux | grep node
user  12345  0.5  2.1  900000 85000 ?  Ssl  18:25  0:02 /usr/bin/node server.js
```

### Normal Memory Usage

| Component | Typical Memory | Notes |
|-----------|---------------|-------|
| Node.js event handler | 60-120 MB | Increases with concurrent jobs |
| Per cron job (agent) | Not on host | Runs in Docker container |
| Telegram bot | Included above | Part of event handler |

### Red Flags

⚠️ **Process stopped unexpectedly**
```bash
systemctl status thepopebot
# Shows: inactive (dead) or failed
```
→ Check logs: `sudo journalctl -u thepopebot -n 50`

⚠️ **High memory usage (>500 MB)**
```bash
ps aux | grep node
# Shows: 500000+ in RSS column
```
→ May indicate memory leak or stuck job

⚠️ **Restart loop**
```bash
sudo journalctl -u thepopebot | grep -i restart
# Shows: Multiple rapid restarts
```
→ Check for configuration errors or port conflicts

---

## Migration Checklist

Use this checklist when migrating from manual/screen/PM2 to systemd:

- [ ] **Backup current setup**
  - [ ] Export environment variables: `env | grep -E '(API_KEY|TOKEN|SECRET)' > .env.backup`
  - [ ] Note current working directory: `pwd > path.backup`
  - [ ] Save screen/PM2 configuration

- [ ] **Stop existing processes**
  - [ ] Screen sessions terminated: `screen -ls` (should show "No Sockets found")
  - [ ] PM2 processes stopped: `pm2 list` (should be empty or not installed)
  - [ ] Manual processes killed: `ps aux | grep node | grep -v grep` (should be empty)
  - [ ] Port 3000 free: `lsof -i :3000` (should return nothing)

- [ ] **Prepare systemd service**
  - [ ] Service file created: `/etc/systemd/system/thepopebot.service`
  - [ ] Paths customized (User, WorkingDirectory, ExecStart, EnvironmentFile)
  - [ ] Log directory created: `/var/log/thepopebot`
  - [ ] Permissions set correctly: `ls -la /var/log/thepopebot`
  - [ ] systemd reloaded: `sudo systemctl daemon-reload`

- [ ] **Test service**
  - [ ] Service starts: `sudo systemctl start thepopebot`
  - [ ] Status is active: `systemctl status thepopebot`
  - [ ] Logs show startup: `sudo journalctl -u thepopebot -n 20`
  - [ ] Webhook test successful
  - [ ] Telegram test successful
  - [ ] Can stop cleanly: `sudo systemctl stop thepopebot`

- [ ] **Enable production**
  - [ ] Service enabled: `sudo systemctl enable thepopebot`
  - [ ] Reboot test passed: Service auto-starts after reboot
  - [ ] Monitor logs: No errors in first 24 hours
  - [ ] Old backup files removed (after 1 week of stable operation)

---

## Quick Reference

### Find Running Process

```bash
# Quick check
systemctl status thepopebot || ps aux | grep "node.*server.js" | grep -v grep
```

### Restart After Code Changes

```bash
# If you pushed changes to main branch
cd /path/to/thepopebot
git pull origin main
cd event_handler
npm install  # if package.json changed
sudo systemctl restart thepopebot
sudo journalctl -u thepopebot -f  # watch logs
```

### Check Last 10 Jobs

```bash
cd /path/to/thepopebot
ls -lt logs/ | head -11
```

### Emergency Stop

```bash
sudo systemctl stop thepopebot
sudo pkill -9 -f "node.*server.js"
```

---

## Common Issues & Solutions

### Issue: Service won't start

**Symptom:** `systemctl status thepopebot` shows "failed" or "inactive (dead)"

**Debugging:**
```bash
# Check detailed error
sudo journalctl -u thepopebot -n 50 --no-pager

# Test manual start
cd /path/to/event_handler
node server.js
# Look for errors in output
```

**Common causes:**
- Wrong path in WorkingDirectory
- Wrong path to node in ExecStart
- Missing `.env` file
- Port 3000 already in use
- Permission errors (wrong User in service file)

### Issue: Environment variables not loaded

**Symptom:** Bot starts but API calls fail (no ANTHROPIC_API_KEY, etc.)

**Solution:**
```bash
# Verify .env file exists and is readable
ls -la /path/to/event_handler/.env

# Check systemd loaded the environment
sudo systemctl show thepopebot --property=Environment

# Make sure EnvironmentFile= path is correct in service file
sudo nano /etc/systemd/system/thepopebot.service

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart thepopebot
```

### Issue: Permission denied errors

**Symptom:** Logs show "EACCES" or "permission denied"

**Solution:**
```bash
# Check ownership of repo
ls -la /path/to/thepopebot
# Should be owned by User specified in service file

# Fix ownership if needed
sudo chown -R YOUR_USERNAME:YOUR_USERNAME /path/to/thepopebot

# Check log directory permissions
ls -la /var/log/thepopebot
sudo chown YOUR_USERNAME:YOUR_USERNAME /var/log/thepopebot
```

### Issue: High memory usage

**Symptom:** Memory grows over time, system slow

**Solution:**
```bash
# Check current memory
ps aux | grep node | grep -v grep

# Restart service (clears memory)
sudo systemctl restart thepopebot

# If problem persists, check for memory leaks in logs
sudo journalctl -u thepopebot | grep -i "memory\|heap"

# Consider adding memory limit to service file:
# Add under [Service]:
# MemoryMax=500M
```

### Issue: Service stops after SSH disconnect

**Symptom:** Service runs while SSH connected, stops when disconnecting

**Cause:** Service not properly daemonized or manual start instead of systemd

**Solution:**
```bash
# Make sure you're using systemctl start, not node server.js
sudo systemctl start thepopebot

# Verify service is a daemon
systemctl show thepopebot --property=Type
# Should show: Type=simple

# Check if enabled for auto-start
systemctl is-enabled thepopebot
# Should show: enabled
```

---

## Verifying a systemd PR (If You Have One)

If someone has created a PR to add systemd support, review these key files:

### Files to check:

1. **Service file** (should be in `docs/thepopebot.service` or similar)
   - Verify `User=` is templated or has instructions
   - Check `WorkingDirectory=` uses placeholder
   - Confirm `ExecStart=` uses placeholder for node path
   - Ensure `EnvironmentFile=` points to `.env`
   - Security options look reasonable (NoNewPrivileges, PrivateTmp, etc.)

2. **Installation documentation** (should be in `docs/SYSTEMD.md` or updated `README.md`)
   - Clear steps for customizing service file
   - Instructions for creating log directory
   - Commands for reload, start, enable
   - Troubleshooting section

3. **Test it:**
```bash
# On your system (not in Docker container)
cd /path/to/thepopebot
git fetch origin
git checkout pr/BRANCH_NAME

# Follow the installation instructions in the PR
# Verify service starts successfully
# Test webhook and Telegram functionality
# Check logs are working
```

### PR approval checklist:

- [ ] Service file is properly templated (no hardcoded paths/usernames)
- [ ] Documentation covers customization steps
- [ ] Security hardening options included
- [ ] Log rotation or log management addressed
- [ ] Restart policy is appropriate (Restart=always)
- [ ] Instructions for enabling auto-start on boot
- [ ] Troubleshooting guide included
- [ ] Works on your system after following instructions

---

## Next Steps

1. **Run the commands in "Commands to Run on Your HOST System"** section on your actual server/machine
2. **Document current state** (what processes are running, how they're managed)
3. **Stop existing processes** safely using appropriate method
4. **Set up systemd service** following the step-by-step guide
5. **Test thoroughly** before enabling auto-start
6. **Monitor for 24 hours** to ensure stability

---

## Report Generated By

- **Agent:** thepopebot Docker Agent
- **Job ID:** 3b8ea412-1973-42a8-bd63-a6a97150af91
- **Timestamp:** 2026-02-15T18:25:05Z
- **Environment:** Docker container (Debian Bookworm)

**Note:** This report was generated from inside the Docker Agent container. All process management and systemd setup must be performed on your HOST SYSTEM where the Event Handler runs.
