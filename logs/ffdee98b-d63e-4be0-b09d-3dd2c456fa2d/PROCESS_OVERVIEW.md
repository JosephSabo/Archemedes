# thepopebot systemd Deployment - Technical Overview

**Deep dive into the deployment process, architecture, and implementation**

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Deployment Flow](#deployment-flow)
3. [Script Details](#script-details)
4. [systemd Configuration](#systemd-configuration)
5. [Security Implementation](#security-implementation)
6. [Log Management](#log-management)
7. [Error Handling](#error-handling)
8. [Testing Strategy](#testing-strategy)

---

## Architecture Overview

### Current Architecture (Pre-Deployment)

```
Host System
│
├── Manual Execution Options:
│   ├── Direct: node server.js
│   ├── PM2: pm2 start server.js
│   ├── screen: screen -S thepopebot
│   └── nohup: nohup node server.js &
│
└── Event Handler (Node.js)
    ├── server.js (Express HTTP server)
    ├── cron.js (Scheduled jobs)
    ├── triggers.js (Webhook handlers)
    ├── claude/ (AI chat integration)
    └── tools/ (GitHub, Telegram, job creation)
```

**Problems:**
- No automatic restart on crash
- No automatic start on boot
- Manual log management
- Inconsistent process management
- No resource limits
- Difficult to monitor

### Target Architecture (Post-Deployment)

```
Host System
│
└── systemd
    └── thepopebot.service
        ├── Manages: Event Handler process
        ├── Logs: journald + /var/log/thepopebot/
        ├── Auto-start: On boot
        ├── Auto-restart: On failure
        ├── Resource limits: Memory (1GB), CPU (50%)
        └── Security: Non-root, protected filesystem
```

**Benefits:**
- ✅ Automatic crash recovery (restarts in 10s)
- ✅ Boot persistence (starts with system)
- ✅ Centralized logging (journald + files)
- ✅ Standard management (systemctl)
- ✅ Resource protection (OOM prevention)
- ✅ Security hardening (filesystem isolation)

---

## Deployment Flow

### High-Level Flow

```
┌─────────────────┐
│  01-backup.sh   │  Create safety net
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 02-diagnostic.sh│  Verify readiness
└────────┬────────┘
         │
         ├──► ERRORS? ──► Fix and re-run
         │
         ▼
┌─────────────────┐
│03-stop-proc.sh  │  Clean state
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  04-deploy.sh   │  Install service
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  05-verify.sh   │  Validate deployment
└────────┬────────┘
         │
         ├──► FAILED? ──► Troubleshoot or rollback
         │
         ▼
    ┌────────┐
    │SUCCESS!│
    └────────┘
```

### Detailed Flow

```
Start
  │
  ├─► 01-backup.sh
  │    ├─► Detect repo location
  │    ├─► Create timestamp directory
  │    ├─► Backup .env, code, config
  │    ├─► Capture process state
  │    ├─► Generate restore script
  │    └─► Create manifest
  │
  ├─► 02-diagnostic.sh
  │    ├─► Check system requirements
  │    │    ├─► Node.js version
  │    │    ├─► systemd availability
  │    │    └─► Git installation
  │    ├─► Verify repository structure
  │    │    ├─► event_handler/
  │    │    ├─► server.js
  │    │    └─► .env file
  │    ├─► Scan running processes
  │    │    ├─► Node.js processes
  │    │    ├─► Port 3000 usage
  │    │    ├─► PM2 processes
  │    │    └─► screen sessions
  │    ├─► Check permissions
  │    └─► Validate environment
  │
  ├─► 03-stop-processes.sh (if needed)
  │    ├─► Stop systemd service
  │    ├─► Stop PM2 processes
  │    ├─► Close screen sessions
  │    ├─► Terminate Node.js processes
  │    └─► Free port 3000
  │
  ├─► 04-deploy.sh
  │    ├─► Auto-detect configuration
  │    │    ├─► Username (whoami)
  │    │    ├─► Node.js path (which node)
  │    │    └─► Repository path (pwd)
  │    ├─► Confirm with user
  │    ├─► Install dependencies (npm install)
  │    ├─► Create log directory
  │    │    └─► /var/log/thepopebot/
  │    ├─► Generate service file
  │    │    ├─► Substitute paths
  │    │    ├─► Configure security
  │    │    └─► Set resource limits
  │    ├─► Install service
  │    │    ├─► Backup existing (if present)
  │    │    ├─► Copy to /etc/systemd/system/
  │    │    └─► Set permissions (644)
  │    ├─► Reload systemd
  │    ├─► Start service
  │    └─► Enable auto-start (optional)
  │
  └─► 05-verify.sh
       ├─► Service status checks (4 tests)
       ├─► Process checks (3 tests)
       ├─► Log checks (5 tests)
       ├─► Configuration checks (5 tests)
       ├─► Network checks (2 tests)
       ├─► Resource checks (3 tests)
       └─► Security checks (3 tests)
            │
            ├─► All passed? ──► Success!
            └─► Failures? ──► Report issues
```

---

## Script Details

### 01-backup.sh

**Purpose**: Risk mitigation through comprehensive backup

**Implementation**:
```bash
# 1. Detect repository root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 2. Create timestamped backup directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$REPO_ROOT/backups/pre-systemd-$TIMESTAMP"

# 3. Backup critical files
cp -r "$REPO_ROOT/event_handler/.env" "$BACKUP_DIR/"
cp -r "$REPO_ROOT/event_handler" "$BACKUP_DIR/"
cp -r "$REPO_ROOT/operating_system" "$BACKUP_DIR/"

# 4. Capture process state
ps aux | grep node > "$BACKUP_DIR/process-state.txt"

# 5. Generate restore script
cat > "$BACKUP_DIR/RESTORE.sh" << 'EOF'
#!/bin/bash
# Restore from backup
cp -r "$BACKUP_DIR/.env" "$REPO_ROOT/event_handler/"
# ... restore other files
EOF
```

**Key Features**:
- Non-destructive (creates new directory)
- Timestamped for multiple backups
- Self-contained restore script
- Manifest for verification
- Captures runtime state

---

### 02-diagnostic.sh

**Purpose**: Pre-flight verification to prevent deployment failures

**Implementation**:
```bash
# Check tracking
WARNINGS=0
ERRORS=0
TOTAL_CHECKS=0

# Generic check function
check_item() {
    local name=$1
    local status=$2
    local message=$3
    local level=${4:-"INFO"}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$status" = "OK" ]; then
        echo -e "✓ $name"
    elif [ "$level" = "WARN" ]; then
        WARNINGS=$((WARNINGS + 1))
        echo -e "⚠ $name: $message"
    elif [ "$level" = "ERROR" ]; then
        ERRORS=$((ERRORS + 1))
        echo -e "✗ $name: $message"
    fi
}

# Example checks
if command -v node &> /dev/null; then
    check_item "Node.js" "OK" "$(node --version)"
else
    check_item "Node.js" "FAIL" "Not found" "ERROR"
fi
```

**Check Categories**:
1. **System Requirements**: node, npm, systemd, git
2. **Repository Structure**: directories, files, dependencies
3. **Running Processes**: node, port 3000, managers
4. **systemd State**: existing service, service file
5. **Permissions**: write access, sudo capability
6. **Environment**: .env file, required variables

**Exit Codes**:
- `0`: All checks passed (green light)
- `0`: Warnings present (yellow light, can proceed)
- `1`: Errors present (red light, must fix)

---

### 03-stop-processes.sh

**Purpose**: Safe shutdown of existing instances

**Implementation**:
```bash
# Graceful stop with fallback to force
stop_process() {
    local pid=$1
    local name=$2
    
    # Try SIGTERM (graceful)
    kill -15 $pid 2>/dev/null || return 1
    
    # Wait up to 10 seconds
    for i in {1..10}; do
        if ! ps -p $pid > /dev/null 2>&1; then
            echo "✓ $name stopped gracefully"
            return 0
        fi
        sleep 1
    done
    
    # Fallback to SIGKILL (force)
    kill -9 $pid 2>/dev/null || return 1
    sleep 1
    
    if ! ps -p $pid > /dev/null 2>&1; then
        echo "✓ $name force stopped"
        return 0
    fi
    
    echo "✗ Failed to stop $name"
    return 1
}
```

**Stop Order**:
1. systemd service (most controlled)
2. PM2 processes (process manager)
3. screen sessions (terminal multiplexer)
4. Direct Node.js processes (manual)
5. Port 3000 processes (catch-all)

**Safety Features**:
- Interactive confirmation before each action
- Graceful shutdown (SIGTERM) before force (SIGKILL)
- Wait periods for clean shutdown
- Verification after each stop
- Detailed feedback

---

### 04-deploy.sh

**Purpose**: Automated installation and configuration

**Implementation**:
```bash
# 1. Auto-detect configuration
DETECTED_USER=$(whoami)
DETECTED_NODE=$(which node)
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 2. Generate service file with substitutions
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=thepopebot Event Handler
After=network-online.target

[Service]
Type=simple
User=$DETECTED_USER
WorkingDirectory=$REPO_ROOT/event_handler
ExecStart=$DETECTED_NODE server.js
EnvironmentFile=$REPO_ROOT/event_handler/.env

Restart=always
RestartSec=10

StandardOutput=append:/var/log/thepopebot/output.log
StandardError=append:/var/log/thepopebot/error.log

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$REPO_ROOT

# Resources
MemoryMax=1G
CPUQuota=50%

[Install]
WantedBy=multi-user.target
EOF

# 3. Install service
sudo cp "$SERVICE_FILE" /etc/systemd/system/thepopebot.service
sudo chmod 644 /etc/systemd/system/thepopebot.service
sudo systemctl daemon-reload

# 4. Start service
sudo systemctl start thepopebot
```

**Key Features**:
- Zero manual configuration (auto-detects paths)
- Interactive confirmation before installation
- Backs up existing service file
- Validates service starts successfully
- Optional auto-start enablement
- Detailed status feedback

---

### 05-verify.sh

**Purpose**: Comprehensive post-deployment validation

**Implementation**:
```bash
# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Generic test function
run_test() {
    local name=$1
    local result=$2
    local message=$3
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$result" = "PASS" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "✓ PASS - $name"
    elif [ "$result" = "FAIL" ]; then
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "✗ FAIL - $name: $message"
    fi
}

# Example test
if systemctl is-active --quiet thepopebot; then
    run_test "Service running" "PASS"
else
    run_test "Service running" "FAIL" "Service not active"
fi
```

**Test Coverage**:
- **Service Status**: Installed, running, enabled, not failed
- **Process**: Running, correct port, single instance
- **Logs**: Directory exists, writable, files created
- **Configuration**: .env exists, variables set, dependencies installed
- **Network**: Port listening, HTTP responding
- **Resources**: Memory reasonable, CPU normal, uptime positive
- **Security**: Correct permissions, not root, hardening enabled

**Exit Codes**:
- `0`: All tests passed
- `1`: One or more tests failed

---

### 06-rollback.sh

**Purpose**: Safe reversal of deployment

**Implementation**:
```bash
# 1. Stop service
sudo systemctl stop thepopebot
sudo systemctl disable thepopebot

# 2. Remove service file (with backup)
TIMESTAMP=$(date +%s)
sudo mv /etc/systemd/system/thepopebot.service \
        /etc/systemd/system/thepopebot.service.removed.$TIMESTAMP

# 3. Reload systemd
sudo systemctl daemon-reload

# 4. Optionally restore from backup
if [ -f "$BACKUP_DIR/RESTORE.sh" ]; then
    bash "$BACKUP_DIR/RESTORE.sh"
fi

# 5. Verify clean state
systemctl status thepopebot  # Should fail
ps aux | grep server.js       # Should be empty
lsof -i :3000                 # Should be empty
```

**Safety Features**:
- Confirmation before destructive actions
- Final backup before removal
- Optional restore from backup
- Optional log cleanup
- State verification
- Rollback instructions

---

## systemd Configuration

### Service File Structure

```ini
[Unit]
Description=thepopebot Event Handler - Autonomous AI Agent System
Documentation=https://github.com/stephengpope/thepopebot
After=network-online.target          # Wait for network
Wants=network-online.target          # Prefer network, but not required

[Service]
Type=simple                          # Main process is the service
User=YOUR_USERNAME                   # Non-root user
WorkingDirectory=/path/to/event_handler
Environment="NODE_ENV=production"
EnvironmentFile=/path/to/.env        # Load environment variables
ExecStart=/path/to/node server.js    # Start command

# Restart behavior
Restart=always                       # Always restart on exit
RestartSec=10                        # Wait 10s before restart
StartLimitBurst=5                    # Max 5 restarts
StartLimitIntervalSec=300            # Within 5 minutes

# Logging
StandardOutput=append:/var/log/thepopebot/output.log
StandardError=append:/var/log/thepopebot/error.log
SyslogIdentifier=thepopebot         # Tag for journald

# Security
NoNewPrivileges=true                # Prevent privilege escalation
PrivateTmp=true                     # Private /tmp directory
ProtectSystem=strict                # Read-only system files
ProtectHome=true                    # No access to other user homes
ReadWritePaths=/path/to/repo        # Allow writes only here

# Resources
MemoryMax=1G                        # Max 1GB RAM
CPUQuota=50%                        # Max 50% of one CPU core

[Install]
WantedBy=multi-user.target          # Start in multi-user mode
```

### Restart Policy

**Configuration**:
```ini
Restart=always
RestartSec=10
StartLimitBurst=5
StartLimitIntervalSec=300
```

**Behavior**:
- Restarts on any exit (crash, signal, error)
- Waits 10 seconds between restart attempts
- Maximum 5 restarts within 5 minutes
- If limit exceeded, service enters failed state

**Restart Triggers**:
- ✅ Uncaught exception
- ✅ Process killed (SIGTERM, SIGKILL)
- ✅ Out of memory
- ✅ Port conflict resolution
- ❌ Manual stop (systemctl stop)
- ❌ Exceeded restart limit

---

## Security Implementation

### Principle of Least Privilege

**Service runs as non-root user**:
```ini
User=YOUR_USERNAME
```
- No root privileges
- Limited filesystem access
- Cannot bind privileged ports (<1024)

### Filesystem Protection

```ini
ProtectSystem=strict   # System files read-only
ProtectHome=true       # Other users' homes hidden
PrivateTmp=true        # Isolated /tmp
ReadWritePaths=/path   # Explicit write permissions
```

**Effect**:
- Cannot write to `/usr`, `/boot`, `/efi`
- Cannot read other users' home directories
- Isolated temporary file space
- Write access only where explicitly granted

### Privilege Protection

```ini
NoNewPrivileges=true
```

Prevents:
- setuid/setgid escalation
- Capability acquisition
- Namespace manipulation
- Security policy bypass

### Resource Limits

```ini
MemoryMax=1G      # Hard memory limit
CPUQuota=50%      # CPU usage cap
```

**Purpose**:
- Prevent memory leaks from causing OOM
- Prevent CPU hogging
- Protect system stability
- Enable fair resource sharing

---

## Log Management

### Dual Logging System

**1. journald (systemd native)**
```bash
# View logs
sudo journalctl -u thepopebot

# Follow live
sudo journalctl -u thepopebot -f

# Since timestamp
sudo journalctl -u thepopebot --since "1 hour ago"

# Priority filtering
sudo journalctl -u thepopebot -p err
```

**2. File logs** (`/var/log/thepopebot/`)
```bash
# Output log
tail -f /var/log/thepopebot/output.log

# Error log
tail -f /var/log/thepopebot/error.log

# Search
grep ERROR /var/log/thepopebot/*.log
```

### Log Configuration

```ini
StandardOutput=append:/var/log/thepopebot/output.log
StandardError=append:/var/log/thepopebot/error.log
SyslogIdentifier=thepopebot
```

**How it works**:
1. Process writes to stdout/stderr
2. systemd captures both streams
3. Sends to journald (structured logging)
4. Appends to file logs (persistent)
5. Tags with identifier (filtering)

### Log Rotation

**journald** (automatic):
- Configured in `/etc/systemd/journald.conf`
- Default: 10% of disk or 4GB
- Automatic vacuum on space pressure

**File logs** (manual):
```bash
# Truncate
sudo truncate -s 0 /var/log/thepopebot/*.log

# Archive and truncate
cd /var/log/thepopebot
sudo tar -czf archive-$(date +%Y%m%d).tar.gz *.log
sudo truncate -s 0 *.log

# Vacuum journald
sudo journalctl --vacuum-time=1w
sudo journalctl --vacuum-size=100M
```

---

## Error Handling

### Deployment-Time Errors

**Script errors**:
```bash
set -e  # Exit on any error

# Safe execution
command || { echo "Error: command failed"; exit 1; }

# Conditional checks
if ! systemctl is-active thepopebot; then
    echo "Service failed to start"
    sudo journalctl -u thepopebot -n 50
    exit 1
fi
```

**User errors**:
- Interactive confirmations prevent accidents
- Detailed error messages guide resolution
- Rollback instructions provided
- Safe defaults (e.g., don't delete without asking)

### Runtime Errors

**Service crashes**:
```
Crash → systemd detects → Wait 10s → Restart → Repeat up to 5 times
```

**Start failures**:
```
Failed start → journald logs error → Service enters failed state
```

**Recovery**:
```bash
# View failure
systemctl status thepopebot
sudo journalctl -u thepopebot -n 100

# Manual restart
sudo systemctl restart thepopebot

# Reset failure count
sudo systemctl reset-failed thepopebot
```

---

## Testing Strategy

### Pre-Deployment Testing

**Diagnostic checks** (02-diagnostic.sh):
- 25+ automated checks
- Covers all prerequisites
- Identifies blockers early
- Provides remediation guidance

### Post-Deployment Testing

**Verification tests** (05-verify.sh):
- 25+ automated tests
- 7 test categories
- PASS/FAIL/SKIP/WARN reporting
- Troubleshooting suggestions

### Manual Testing

**After deployment**:
```bash
# 1. Service responds
curl http://localhost:3000/webhook \
  -H "X-API-Key: YOUR_KEY" \
  -d '{"test": "hello"}'

# 2. Telegram bot works
# Send message to bot

# 3. Logs flowing
sudo journalctl -u thepopebot -f

# 4. Survives restart
sudo systemctl restart thepopebot
# Wait 15 seconds
systemctl is-active thepopebot  # Should be "active"

# 5. Survives reboot
sudo reboot
# After reboot:
systemctl is-active thepopebot  # Should be "active"
```

---

## Deployment Variations

### Clean System

```
02-diagnostic.sh → 04-deploy.sh → 05-verify.sh
```
Skip stop-processes (nothing to stop)

### Existing PM2

```
02-diagnostic.sh → 03-stop-processes.sh → 04-deploy.sh → 05-verify.sh
```
Stop PM2 first

### Existing systemd

```
02-diagnostic.sh → 06-rollback.sh → 04-deploy.sh → 05-verify.sh
```
Rollback old service, redeploy fresh

### Custom Configuration

```
04-deploy.sh → Edit service file → Manual install
```
For non-standard setups

---

## Performance Considerations

### Startup Time

**Typical**: 2-5 seconds
- Load Node.js runtime
- Parse configuration
- Initialize Express
- Bind to port 3000

### Memory Usage

**Initial**: ~50-100 MB
**Typical**: ~100-200 MB
**Limit**: 1 GB (MemoryMax)

**OOM behavior**:
- systemd kills process
- Waits 10 seconds
- Restarts service

### CPU Usage

**Idle**: <1%
**Active**: 5-20%
**Limit**: 50% (CPUQuota)

**Throttling behavior**:
- Process slowed if exceeds quota
- No crash, just slower response

---

## Future Enhancements

### Monitoring

```bash
# Add monitoring service
sudo systemctl enable thepopebot-monitor.timer

# Health check every 5 minutes
# Alert on failures
```

### Metrics

```bash
# Export metrics to Prometheus
# Grafana dashboards
# Alert manager integration
```

### Auto-Update

```bash
# Automatic git pull
# Dependency updates
# Rolling restart
# Rollback on failure
```

---

**Generated by thepopebot Docker Agent**  
Job ID: `ffdee98b-d63e-4be0-b09d-3dd2c456fa2d`  
Date: 2026-02-15
