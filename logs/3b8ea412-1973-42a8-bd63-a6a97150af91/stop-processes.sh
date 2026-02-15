#!/bin/bash
# Safe Process Stop Script for thepopebot
# Run this on your HOST system before installing systemd service

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================"
echo "thepopebot Safe Process Stopper"
echo "======================================${NC}"
echo ""

STOPPED_SOMETHING=0

# Function to wait and check if process stopped
wait_for_stop() {
    local pid=$1
    local name=$2
    local max_wait=10
    local count=0
    
    while [ $count -lt $max_wait ]; do
        if ! ps -p $pid > /dev/null 2>&1; then
            echo -e "${GREEN}✓ $name stopped successfully${NC}"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    echo ""
    echo -e "${YELLOW}⚠ $name did not stop gracefully${NC}"
    return 1
}

# Stop PM2 processes
echo "1. Checking for PM2 processes..."
if command -v pm2 &> /dev/null; then
    if pm2 list 2>/dev/null | grep -q "thepopebot"; then
        echo -e "${YELLOW}Stopping PM2 process 'thepopebot'...${NC}"
        pm2 stop thepopebot
        pm2 delete thepopebot
        pm2 save --force
        echo -e "${GREEN}✓ PM2 process stopped and removed${NC}"
        STOPPED_SOMETHING=1
    elif pm2 list 2>/dev/null | grep -q "online"; then
        echo -e "${YELLOW}Found other PM2 processes:${NC}"
        pm2 list
        read -p "Stop all PM2 processes? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pm2 stop all
            pm2 delete all
            pm2 save --force
            echo -e "${GREEN}✓ All PM2 processes stopped${NC}"
            STOPPED_SOMETHING=1
        fi
    else
        echo -e "${GREEN}No PM2 processes to stop${NC}"
    fi
else
    echo "PM2 not installed - skipping"
fi
echo ""

# Stop screen sessions
echo "2. Checking for screen sessions..."
if command -v screen &> /dev/null; then
    SESSIONS=$(screen -ls 2>&1 | grep -E "^\s+[0-9]+\." | awk '{print $1}' || true)
    if [ ! -z "$SESSIONS" ]; then
        echo -e "${YELLOW}Found screen sessions:${NC}"
        screen -ls
        echo ""
        for session in $SESSIONS; do
            read -p "Stop screen session '$session'? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                screen -X -S "$session" quit
                echo -e "${GREEN}✓ Screen session '$session' terminated${NC}"
                STOPPED_SOMETHING=1
            fi
        done
    else
        echo -e "${GREEN}No screen sessions to stop${NC}"
    fi
else
    echo "screen not installed - skipping"
fi
echo ""

# Stop systemd service
echo "3. Checking for systemd service..."
if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet thepopebot 2>/dev/null; then
        echo -e "${YELLOW}Stopping systemd service 'thepopebot'...${NC}"
        sudo systemctl stop thepopebot
        echo -e "${GREEN}✓ systemd service stopped${NC}"
        STOPPED_SOMETHING=1
        
        read -p "Disable auto-start on boot? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo systemctl disable thepopebot
            echo -e "${GREEN}✓ Auto-start disabled${NC}"
        fi
    else
        echo -e "${GREEN}systemd service not running${NC}"
    fi
else
    echo "systemd not available - skipping"
fi
echo ""

# Stop Node.js processes
echo "4. Checking for Node.js processes..."
NODE_PIDS=$(pgrep -f "node.*server.js" || true)
if [ ! -z "$NODE_PIDS" ]; then
    echo -e "${YELLOW}Found Node.js processes:${NC}"
    ps aux | grep "node.*server.js" | grep -v grep
    echo ""
    
    for pid in $NODE_PIDS; do
        CMDLINE=$(ps -p $pid -o cmd= 2>/dev/null || echo "process")
        read -p "Stop process $pid ($CMDLINE)? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Sending SIGTERM (graceful shutdown)..."
            kill -15 $pid 2>/dev/null || true
            
            if wait_for_stop $pid "Process $pid"; then
                STOPPED_SOMETHING=1
            else
                read -p "Force kill with SIGKILL? (y/N): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    kill -9 $pid 2>/dev/null || true
                    sleep 1
                    if ! ps -p $pid > /dev/null 2>&1; then
                        echo -e "${GREEN}✓ Process $pid force killed${NC}"
                        STOPPED_SOMETHING=1
                    else
                        echo -e "${RED}✗ Failed to kill process $pid${NC}"
                    fi
                fi
            fi
        fi
    done
else
    echo -e "${GREEN}No Node.js processes to stop${NC}"
fi
echo ""

# Verify port 3000 is free
echo "5. Verifying port 3000..."
if command -v lsof &> /dev/null; then
    if lsof -ti :3000 > /dev/null 2>&1; then
        echo -e "${YELLOW}Something is still using port 3000:${NC}"
        lsof -i :3000
        echo ""
        read -p "Kill process on port 3000? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            lsof -ti :3000 | xargs kill -15 2>/dev/null || true
            sleep 2
            if lsof -ti :3000 > /dev/null 2>&1; then
                echo "Process didn't stop, force killing..."
                lsof -ti :3000 | xargs kill -9 2>/dev/null || true
            fi
            sleep 1
            if ! lsof -ti :3000 > /dev/null 2>&1; then
                echo -e "${GREEN}✓ Port 3000 is now free${NC}"
                STOPPED_SOMETHING=1
            else
                echo -e "${RED}✗ Failed to free port 3000${NC}"
            fi
        fi
    else
        echo -e "${GREEN}Port 3000 is free${NC}"
    fi
else
    echo "lsof not available - cannot verify port"
fi
echo ""

# Final summary
echo -e "${BLUE}======================================"
echo "Summary"
echo "======================================${NC}"
echo ""

# Check final state
REMAINING_NODE=$(pgrep -f node | wc -l)
PORT_USED=0
if command -v lsof &> /dev/null && lsof -ti :3000 > /dev/null 2>&1; then
    PORT_USED=1
fi

if [ $STOPPED_SOMETHING -eq 1 ]; then
    echo -e "${GREEN}✓ Stopped some processes${NC}"
else
    echo -e "${YELLOW}No processes were stopped${NC}"
fi

echo ""
echo "Current state:"
echo "- Node.js processes: $REMAINING_NODE"
echo "- Port 3000 in use: $([ $PORT_USED -eq 1 ] && echo 'YES' || echo 'NO')"
echo ""

if [ $REMAINING_NODE -eq 0 ] && [ $PORT_USED -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ System is clean - ready to install systemd service! ✓✓✓${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Edit thepopebot.service.template with your paths"
    echo "2. Follow installation instructions in PROCESS_AUDIT_REPORT.md"
    echo "3. Test the systemd service"
else
    echo -e "${YELLOW}⚠ Some processes may still be running${NC}"
    echo ""
    echo "Run './quick-check.sh' to see current state"
fi
