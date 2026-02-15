#!/bin/bash
# thepopebot Enhanced Diagnostic Script
# Comprehensive system check before deployment
# Run this on your HOST system (not inside Docker container)

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}======================================"
echo "thepopebot Deployment Diagnostic"
echo "======================================${NC}"
echo ""

# Get paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${YELLOW}Repository root: $REPO_ROOT${NC}"
echo -e "${YELLOW}Hostname: $(hostname)${NC}"
echo -e "${YELLOW}Current user: $(whoami)${NC}"
echo ""

# Initialize counters
WARNINGS=0
ERRORS=0
TOTAL_CHECKS=0

# Check function
check_item() {
    local name=$1
    local status=$2
    local message=$3
    local level=${4:-"INFO"} # INFO, WARN, ERROR
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$status" = "OK" ]; then
        echo -e "  ${GREEN}✓${NC} $name"
        if [ ! -z "$message" ]; then
            echo -e "    ${message}"
        fi
    elif [ "$level" = "WARN" ]; then
        WARNINGS=$((WARNINGS + 1))
        echo -e "  ${YELLOW}⚠${NC} $name"
        if [ ! -z "$message" ]; then
            echo -e "    ${YELLOW}$message${NC}"
        fi
    elif [ "$level" = "ERROR" ]; then
        ERRORS=$((ERRORS + 1))
        echo -e "  ${RED}✗${NC} $name"
        if [ ! -z "$message" ]; then
            echo -e "    ${RED}$message${NC}"
        fi
    else
        echo -e "  ${BLUE}ℹ${NC} $name"
        if [ ! -z "$message" ]; then
            echo -e "    ${message}"
        fi
    fi
}

# Section 1: System Requirements
echo -e "${BOLD}1. System Requirements${NC}"
echo "-----------------------------------"

# Check Node.js
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    NODE_PATH=$(which node)
    check_item "Node.js installed" "OK" "Version: $NODE_VERSION at $NODE_PATH"
else
    check_item "Node.js installed" "FAIL" "Node.js not found" "ERROR"
fi

# Check npm
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    check_item "npm installed" "OK" "Version: $NPM_VERSION"
else
    check_item "npm installed" "FAIL" "npm not found" "WARN"
fi

# Check systemd
if command -v systemctl &> /dev/null; then
    check_item "systemd available" "OK" "$(systemctl --version | head -n1)"
else
    check_item "systemd available" "FAIL" "systemd not found - cannot deploy service" "ERROR"
fi

# Check git
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    check_item "git installed" "OK" "$GIT_VERSION"
else
    check_item "git installed" "FAIL" "git not found" "WARN"
fi

echo ""

# Section 2: Repository Structure
echo -e "${BOLD}2. Repository Structure${NC}"
echo "-----------------------------------"

if [ -d "$REPO_ROOT/event_handler" ]; then
    check_item "event_handler directory" "OK"
else
    check_item "event_handler directory" "FAIL" "Missing event_handler directory" "ERROR"
fi

if [ -f "$REPO_ROOT/event_handler/server.js" ]; then
    check_item "server.js exists" "OK"
else
    check_item "server.js exists" "FAIL" "Missing server.js file" "ERROR"
fi

if [ -f "$REPO_ROOT/event_handler/package.json" ]; then
    check_item "package.json exists" "OK"
else
    check_item "package.json exists" "FAIL" "Missing package.json" "ERROR"
fi

if [ -d "$REPO_ROOT/event_handler/node_modules" ]; then
    check_item "node_modules exists" "OK" "Dependencies installed"
else
    check_item "node_modules exists" "FAIL" "Run 'npm install' in event_handler/" "WARN"
fi

if [ -f "$REPO_ROOT/event_handler/.env" ]; then
    check_item ".env file exists" "OK"
else
    check_item ".env file exists" "FAIL" "Missing .env file" "WARN"
fi

if [ -d "$REPO_ROOT/operating_system" ]; then
    check_item "operating_system directory" "OK"
else
    check_item "operating_system directory" "FAIL" "Missing operating_system directory" "WARN"
fi

echo ""

# Section 3: Running Processes
echo -e "${BOLD}3. Running Processes${NC}"
echo "-----------------------------------"

NODE_PROCS=$(pgrep -f node | wc -l)
if [ $NODE_PROCS -eq 0 ]; then
    check_item "Node.js processes" "OK" "No running processes"
else
    check_item "Node.js processes" "WARN" "$NODE_PROCS process(es) running" "WARN"
    echo ""
    echo "    Processes:"
    ps aux | grep node | grep -v grep | grep -v diagnostic | sed 's/^/    /'
fi

echo ""

# Section 4: Port Availability
echo -e "${BOLD}4. Port Availability${NC}"
echo "-----------------------------------"

if command -v lsof &> /dev/null; then
    if lsof -i :3000 2>/dev/null | grep -q LISTEN; then
        PORT_USER=$(lsof -i :3000 2>/dev/null | grep LISTEN | awk '{print $3}' | head -n1)
        check_item "Port 3000 free" "WARN" "Port in use by user: $PORT_USER" "WARN"
        echo ""
        echo "    Port details:"
        lsof -i :3000 2>/dev/null | sed 's/^/    /'
    else
        check_item "Port 3000 free" "OK"
    fi
else
    check_item "Port 3000 check" "SKIP" "lsof not available"
fi

echo ""

# Section 5: Process Managers
echo -e "${BOLD}5. Process Managers${NC}"
echo "-----------------------------------"

if command -v pm2 &> /dev/null; then
    if pm2 list 2>/dev/null | grep -q "online"; then
        PM2_COUNT=$(pm2 list 2>/dev/null | grep "online" | wc -l)
        check_item "PM2 processes" "WARN" "$PM2_COUNT process(es) running" "WARN"
    else
        check_item "PM2 processes" "OK" "No PM2 processes running"
    fi
else
    check_item "PM2" "OK" "Not installed"
fi

if command -v screen &> /dev/null; then
    if screen -ls 2>&1 | grep -q "Socket"; then
        SCREEN_COUNT=$(screen -ls 2>&1 | grep -c "Socket" || echo "0")
        check_item "screen sessions" "WARN" "$SCREEN_COUNT session(s) active" "WARN"
    else
        check_item "screen sessions" "OK" "No screen sessions"
    fi
else
    check_item "screen" "OK" "Not installed"
fi

echo ""

# Section 6: systemd Service
echo -e "${BOLD}6. Existing systemd Service${NC}"
echo "-----------------------------------"

if systemctl list-unit-files 2>/dev/null | grep -q thepopebot; then
    if systemctl is-active --quiet thepopebot 2>/dev/null; then
        check_item "thepopebot service" "WARN" "Service already running" "WARN"
    else
        check_item "thepopebot service" "WARN" "Service exists but not running" "WARN"
    fi
else
    check_item "thepopebot service" "OK" "No existing service"
fi

if [ -f "/etc/systemd/system/thepopebot.service" ]; then
    check_item "Service file" "WARN" "/etc/systemd/system/thepopebot.service exists" "WARN"
else
    check_item "Service file" "OK" "No existing service file"
fi

echo ""

# Section 7: Permissions
echo -e "${BOLD}7. Permissions${NC}"
echo "-----------------------------------"

if [ -w "$REPO_ROOT/event_handler" ]; then
    check_item "Write access to event_handler" "OK"
else
    check_item "Write access to event_handler" "FAIL" "No write permission" "ERROR"
fi

if [ -d "/var/log/thepopebot" ]; then
    if [ -w "/var/log/thepopebot" ]; then
        check_item "Write access to /var/log/thepopebot" "OK"
    else
        check_item "Write access to /var/log/thepopebot" "WARN" "No write permission" "WARN"
    fi
else
    check_item "Log directory /var/log/thepopebot" "SKIP" "Not created yet"
fi

if groups | grep -q sudo; then
    check_item "sudo access" "OK" "User is in sudo group"
else
    check_item "sudo access" "WARN" "User may not have sudo access" "WARN"
fi

echo ""

# Section 8: Environment Variables
echo -e "${BOLD}8. Environment Configuration${NC}"
echo "-----------------------------------"

if [ -f "$REPO_ROOT/event_handler/.env" ]; then
    # Check for required variables
    if grep -q "^GH_TOKEN=" "$REPO_ROOT/event_handler/.env" 2>/dev/null; then
        check_item "GH_TOKEN configured" "OK"
    else
        check_item "GH_TOKEN configured" "FAIL" "Missing in .env" "WARN"
    fi
    
    if grep -q "^API_KEY=" "$REPO_ROOT/event_handler/.env" 2>/dev/null; then
        check_item "API_KEY configured" "OK"
    else
        check_item "API_KEY configured" "FAIL" "Missing in .env" "WARN"
    fi
    
    if grep -q "^GH_OWNER=" "$REPO_ROOT/event_handler/.env" 2>/dev/null; then
        check_item "GH_OWNER configured" "OK"
    else
        check_item "GH_OWNER configured" "FAIL" "Missing in .env" "WARN"
    fi
    
    if grep -q "^GH_REPO=" "$REPO_ROOT/event_handler/.env" 2>/dev/null; then
        check_item "GH_REPO configured" "OK"
    else
        check_item "GH_REPO configured" "FAIL" "Missing in .env" "WARN"
    fi
else
    check_item "Environment file" "FAIL" ".env file not found" "WARN"
fi

echo ""

# Summary
echo -e "${BLUE}${BOLD}======================================"
echo "Diagnostic Summary"
echo "======================================${NC}"
echo ""
echo "Total checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $((TOTAL_CHECKS - WARNINGS - ERRORS))${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Errors: $ERRORS${NC}"
echo ""

# Overall status
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}${BOLD}✗ CRITICAL ISSUES FOUND${NC}"
    echo ""
    echo "Cannot proceed with deployment. Fix errors above first."
    echo ""
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}${BOLD}⚠ WARNINGS DETECTED${NC}"
    echo ""
    echo "You can proceed, but consider addressing warnings:"
    if [ $NODE_PROCS -gt 0 ]; then
        echo "  • Stop running Node.js processes (run ./03-stop-processes.sh)"
    fi
    if pm2 list 2>/dev/null | grep -q "online"; then
        echo "  • Stop PM2 processes"
    fi
    if screen -ls 2>&1 | grep -q "Socket"; then
        echo "  • Close screen sessions"
    fi
    if systemctl is-active --quiet thepopebot 2>/dev/null; then
        echo "  • Stop existing systemd service"
    fi
    echo ""
    echo "Next step: Run ./03-stop-processes.sh"
    echo ""
    exit 0
else
    echo -e "${GREEN}${BOLD}✓✓✓ ALL CHECKS PASSED ✓✓✓${NC}"
    echo ""
    echo "System is ready for deployment!"
    echo ""
    echo "Next step: Run ./04-deploy.sh"
    echo ""
    exit 0
fi
