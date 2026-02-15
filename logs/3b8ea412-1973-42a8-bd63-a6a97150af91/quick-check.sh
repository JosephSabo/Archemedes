#!/bin/bash
# Quick thepopebot Process Check Script
# Run this on your HOST system (not inside Docker container)

set -e

echo "======================================"
echo "thepopebot Process Quick Check"
echo "======================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for Node.js processes
echo "1. Checking for Node.js processes..."
if pgrep -af node > /dev/null; then
    echo -e "${YELLOW}Found Node.js processes:${NC}"
    ps aux | grep node | grep -v grep | grep -v "quick-check"
    echo ""
else
    echo -e "${GREEN}No Node.js processes found${NC}"
    echo ""
fi

# Check port 3000
echo "2. Checking port 3000..."
if command -v lsof &> /dev/null; then
    if lsof -i :3000 2>/dev/null | grep -q LISTEN; then
        echo -e "${YELLOW}Port 3000 is in use:${NC}"
        lsof -i :3000
        echo ""
    else
        echo -e "${GREEN}Port 3000 is free${NC}"
        echo ""
    fi
else
    echo "lsof not available, checking with netstat/ss..."
    if command -v netstat &> /dev/null; then
        netstat -tlnp 2>/dev/null | grep :3000 || echo -e "${GREEN}Port 3000 is free${NC}"
    elif command -v ss &> /dev/null; then
        ss -tlnp 2>/dev/null | grep :3000 || echo -e "${GREEN}Port 3000 is free${NC}"
    else
        echo "Cannot check port status (no lsof, netstat, or ss)"
    fi
    echo ""
fi

# Check screen sessions
echo "3. Checking for screen sessions..."
if command -v screen &> /dev/null; then
    if screen -ls 2>&1 | grep -q "Socket"; then
        echo -e "${YELLOW}Active screen sessions:${NC}"
        screen -ls
        echo ""
    else
        echo -e "${GREEN}No screen sessions found${NC}"
        echo ""
    fi
else
    echo "screen not installed"
    echo ""
fi

# Check PM2
echo "4. Checking for PM2 processes..."
if command -v pm2 &> /dev/null; then
    if pm2 list 2>/dev/null | grep -q "online"; then
        echo -e "${YELLOW}PM2 processes found:${NC}"
        pm2 list
        echo ""
    else
        echo -e "${GREEN}No PM2 processes running${NC}"
        echo ""
    fi
else
    echo "PM2 not installed"
    echo ""
fi

# Check systemd
echo "5. Checking for systemd service..."
if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet thepopebot 2>/dev/null; then
        echo -e "${YELLOW}thepopebot systemd service is running:${NC}"
        systemctl status thepopebot --no-pager
        echo ""
    elif systemctl list-unit-files | grep -q thepopebot; then
        echo -e "${YELLOW}thepopebot systemd service exists but is not running${NC}"
        systemctl status thepopebot --no-pager
        echo ""
    else
        echo -e "${GREEN}No thepopebot systemd service found${NC}"
        echo ""
    fi
else
    echo "systemd not available on this system"
    echo ""
fi

# Summary
echo "======================================"
echo "Summary"
echo "======================================"

NODE_PROCS=$(pgrep -f node | wc -l)
PORT_USED=0
SCREEN_ACTIVE=0
PM2_ACTIVE=0
SYSTEMD_ACTIVE=0

if lsof -i :3000 2>/dev/null | grep -q LISTEN; then
    PORT_USED=1
fi

if command -v screen &> /dev/null && screen -ls 2>&1 | grep -q "Socket"; then
    SCREEN_ACTIVE=1
fi

if command -v pm2 &> /dev/null && pm2 list 2>/dev/null | grep -q "online"; then
    PM2_ACTIVE=1
fi

if command -v systemctl &> /dev/null && systemctl is-active --quiet thepopebot 2>/dev/null; then
    SYSTEMD_ACTIVE=1
fi

echo "Node.js processes: $NODE_PROCS"
echo "Port 3000 in use: $([ $PORT_USED -eq 1 ] && echo 'YES' || echo 'NO')"
echo "Screen sessions: $([ $SCREEN_ACTIVE -eq 1 ] && echo 'YES' || echo 'NO')"
echo "PM2 processes: $([ $PM2_ACTIVE -eq 1 ] && echo 'YES' || echo 'NO')"
echo "systemd service: $([ $SYSTEMD_ACTIVE -eq 1 ] && echo 'RUNNING' || echo 'NOT RUNNING')"
echo ""

if [ $NODE_PROCS -eq 0 ] && [ $PORT_USED -eq 0 ] && [ $SYSTEMD_ACTIVE -eq 0 ]; then
    echo -e "${GREEN}✓ System is clean - ready to install systemd service${NC}"
elif [ $SYSTEMD_ACTIVE -eq 1 ]; then
    echo -e "${GREEN}✓ thepopebot is running via systemd${NC}"
else
    echo -e "${YELLOW}⚠ Manual processes detected - stop them before installing systemd${NC}"
    echo ""
    echo "To stop processes, see PROCESS_AUDIT_REPORT.md section:"
    echo "'How to Safely Stop Existing Processes'"
fi

echo ""
echo "For detailed instructions, see PROCESS_AUDIT_REPORT.md"
