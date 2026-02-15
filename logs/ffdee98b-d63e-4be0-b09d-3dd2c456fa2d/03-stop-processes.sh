#!/bin/bash
# thepopebot Safe Process Stopper
# Enhanced version with better feedback and safety
# Run this on your HOST system before installing systemd service

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}======================================"
echo "thepopebot Safe Process Stopper"
echo "======================================${NC}"
echo ""

STOPPED_SOMETHING=0
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Function to wait and check if process stopped
wait_for_stop() {
    local pid=$1
    local name=$2
    local max_wait=${3:-10}
    local count=0
    
    echo -n "Waiting for $name to stop"
    while [ $count -lt $max_wait ]; do
        if ! ps -p $pid > /dev/null 2>&1; then
            echo ""
            echo -e "${GREEN}✓ $name stopped successfully${NC}"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    echo ""
    echo -e "${YELLOW}⚠ $name did not stop gracefully (waited ${max_wait}s)${NC}"
    return 1
}

# Function to confirm action
confirm() {
    local prompt=$1
    local default=${2:-"N"}
    
    if [ "$default" = "Y" ]; then
        read -p "$prompt (Y/n): " -n 1 -r
        echo ""
        [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]
    else
        read -p "$prompt (y/N): " -n 1 -r
        echo ""
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# Section 1: Stop systemd service first
echo -e "${BOLD}1. Checking systemd service...${NC}"
echo "-----------------------------------"

if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet thepopebot 2>/dev/null; then
        echo -e "${YELLOW}thepopebot systemd service is running${NC}"
        systemctl status thepopebot --no-pager --lines=5 || true
        echo ""
        
        if confirm "Stop systemd service?"; then
            echo "Stopping thepopebot service..."
            sudo systemctl stop thepopebot
            sleep 2
            
            if ! systemctl is-active --quiet thepopebot 2>/dev/null; then
                echo -e "${GREEN}✓ systemd service stopped${NC}"
                STOPPED_SOMETHING=1
            else
                echo -e "${RED}✗ Failed to stop systemd service${NC}"
            fi
            
            if confirm "Disable auto-start on boot?"; then
                sudo systemctl disable thepopebot
                echo -e "${GREEN}✓ Auto-start disabled${NC}"
            fi
        fi
    else
        echo -e "${GREEN}systemd service not running${NC}"
    fi
else
    echo "systemd not available"
fi

echo ""

# Section 2: Stop PM2 processes
echo -e "${BOLD}2. Checking PM2 processes...${NC}"
echo "-----------------------------------"

if command -v pm2 &> /dev/null; then
    PM2_LIST=$(pm2 jlist 2>/dev/null || echo "[]")
    
    if echo "$PM2_LIST" | grep -q "thepopebot"; then
        echo -e "${YELLOW}Found PM2 process 'thepopebot'${NC}"
        pm2 info thepopebot 2>/dev/null || true
        echo ""
        
        if confirm "Stop PM2 process 'thepopebot'?" "Y"; then
            pm2 stop thepopebot
            pm2 delete thepopebot
            pm2 save --force
            echo -e "${GREEN}✓ PM2 process 'thepopebot' stopped and removed${NC}"
            STOPPED_SOMETHING=1
        fi
    elif echo "$PM2_LIST" | grep -q "online"; then
        echo -e "${YELLOW}Found other PM2 processes:${NC}"
        pm2 list
        echo ""
        
        if confirm "Stop ALL PM2 processes?"; then
            pm2 stop all
            pm2 delete all
            pm2 save --force
            echo -e "${GREEN}✓ All PM2 processes stopped${NC}"
            STOPPED_SOMETHING=1
        fi
    else
        echo -e "${GREEN}No PM2 processes running${NC}"
    fi
else
    echo "PM2 not installed"
fi

echo ""

# Section 3: Stop screen sessions
echo -e "${BOLD}3. Checking screen sessions...${NC}"
echo "-----------------------------------"

if command -v screen &> /dev/null; then
    SESSIONS=$(screen -ls 2>&1 | grep -E "^\s+[0-9]+\." | awk '{print $1}' || true)
    
    if [ ! -z "$SESSIONS" ]; then
        echo -e "${YELLOW}Found screen sessions:${NC}"
        screen -ls 2>&1 | grep -E "^\s+[0-9]+\." || true
        echo ""
        
        for session in $SESSIONS; do
            if confirm "Stop screen session '$session'?"; then
                screen -X -S "$session" quit 2>/dev/null || true
                sleep 1
                
                if screen -ls 2>&1 | grep -q "$session"; then
                    echo -e "${RED}✗ Failed to stop session '$session'${NC}"
                else
                    echo -e "${GREEN}✓ Screen session '$session' terminated${NC}"
                    STOPPED_SOMETHING=1
                fi
            fi
        done
    else
        echo -e "${GREEN}No screen sessions running${NC}"
    fi
else
    echo "screen not installed"
fi

echo ""

# Section 4: Stop Node.js processes
echo -e "${BOLD}4. Checking Node.js processes...${NC}"
echo "-----------------------------------"

# Look for Node.js processes running server.js in our repo
NODE_PIDS=$(pgrep -f "$REPO_ROOT/event_handler/server.js" 2>/dev/null || true)

if [ ! -z "$NODE_PIDS" ]; then
    echo -e "${YELLOW}Found Node.js processes for this repository:${NC}"
    for pid in $NODE_PIDS; do
        ps -p $pid -o pid,user,cmd --no-headers 2>/dev/null || true
    done
    echo ""
    
    for pid in $NODE_PIDS; do
        USER=$(ps -p $pid -o user= 2>/dev/null || echo "unknown")
        if confirm "Stop process $pid (user: $USER)?" "Y"; then
            echo "Sending SIGTERM (graceful shutdown)..."
            kill -15 $pid 2>/dev/null || true
            
            if wait_for_stop $pid "Process $pid" 15; then
                STOPPED_SOMETHING=1
            else
                if confirm "Force kill with SIGKILL?"; then
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
    # Check for any Node.js server processes
    ALL_NODE_PIDS=$(pgrep -f "node.*server.js" 2>/dev/null || true)
    
    if [ ! -z "$ALL_NODE_PIDS" ]; then
        echo -e "${YELLOW}Found other Node.js server processes:${NC}"
        ps aux | grep "node.*server.js" | grep -v grep | head -n 5
        echo ""
        
        if confirm "Review and stop these processes?"; then
            for pid in $ALL_NODE_PIDS; do
                CMDLINE=$(ps -p $pid -o cmd= 2>/dev/null || echo "unknown")
                echo ""
                echo "Process $pid: $CMDLINE"
                
                if confirm "Stop this process?"; then
                    kill -15 $pid 2>/dev/null || true
                    if wait_for_stop $pid "Process $pid" 10; then
                        STOPPED_SOMETHING=1
                    else
                        if confirm "Force kill?"; then
                            kill -9 $pid 2>/dev/null || true
                            sleep 1
                            echo -e "${GREEN}✓ Process force killed${NC}"
                            STOPPED_SOMETHING=1
                        fi
                    fi
                fi
            done
        fi
    else
        echo -e "${GREEN}No Node.js server processes found${NC}"
    fi
fi

echo ""

# Section 5: Verify port 3000
echo -e "${BOLD}5. Verifying port 3000...${NC}"
echo "-----------------------------------"

if command -v lsof &> /dev/null; then
    PORT_PIDS=$(lsof -ti :3000 2>/dev/null || true)
    
    if [ ! -z "$PORT_PIDS" ]; then
        echo -e "${YELLOW}Something is still using port 3000:${NC}"
        lsof -i :3000 2>/dev/null | head -n 10
        echo ""
        
        if confirm "Kill process(es) on port 3000?" "Y"; then
            for pid in $PORT_PIDS; do
                echo "Killing process $pid..."
                kill -15 $pid 2>/dev/null || true
            done
            
            sleep 2
            
            REMAINING=$(lsof -ti :3000 2>/dev/null || true)
            if [ ! -z "$REMAINING" ]; then
                echo "Processes didn't stop, force killing..."
                for pid in $REMAINING; do
                    kill -9 $pid 2>/dev/null || true
                done
            fi
            
            sleep 1
            
            if lsof -ti :3000 > /dev/null 2>&1; then
                echo -e "${RED}✗ Failed to free port 3000${NC}"
            else
                echo -e "${GREEN}✓ Port 3000 is now free${NC}"
                STOPPED_SOMETHING=1
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
echo -e "${BLUE}${BOLD}======================================"
echo "Summary"
echo "======================================${NC}"
echo ""

# Check final state
REMAINING_NODE=$(pgrep -f "$REPO_ROOT/event_handler/server.js" 2>/dev/null | wc -l || echo "0")
PORT_USED=0

if command -v lsof &> /dev/null && lsof -ti :3000 > /dev/null 2>&1; then
    PORT_USED=1
fi

if [ $STOPPED_SOMETHING -eq 1 ]; then
    echo -e "${GREEN}✓ Stopped processes successfully${NC}"
else
    echo -e "${YELLOW}No processes were stopped (system was clean)${NC}"
fi

echo ""
echo "Current state:"
echo "  • Node.js processes for this repo: $REMAINING_NODE"
echo "  • Port 3000 in use: $([ $PORT_USED -eq 1 ] && echo 'YES' || echo 'NO')"
echo ""

if [ $REMAINING_NODE -eq 0 ] && [ $PORT_USED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓✓✓ System is clean - ready for deployment! ✓✓✓${NC}"
    echo ""
    echo "Next step: Run ./04-deploy.sh"
else
    echo -e "${YELLOW}⚠ Some processes may still be running${NC}"
    echo ""
    echo "Run './02-diagnostic.sh' to check current state"
    echo ""
    exit 1
fi

echo ""
