#!/bin/bash
# thepopebot Post-Deployment Verification Script
# Tests the deployed systemd service
# Run this after deployment to ensure everything works

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}======================================"
echo "thepopebot Deployment Verification"
echo "======================================${NC}"
echo ""

# Get paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test function
run_test() {
    local name=$1
    local result=$2
    local message=$3
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$result" = "PASS" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "  ${GREEN}✓ PASS${NC} - $name"
        if [ ! -z "$message" ]; then
            echo -e "         $message"
        fi
    elif [ "$result" = "FAIL" ]; then
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "  ${RED}✗ FAIL${NC} - $name"
        if [ ! -z "$message" ]; then
            echo -e "         ${RED}$message${NC}"
        fi
    elif [ "$result" = "SKIP" ]; then
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        echo -e "  ${YELLOW}⊘ SKIP${NC} - $name"
        if [ ! -z "$message" ]; then
            echo -e "         ${YELLOW}$message${NC}"
        fi
    elif [ "$result" = "WARN" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "  ${YELLOW}⚠ WARN${NC} - $name"
        if [ ! -z "$message" ]; then
            echo -e "         ${YELLOW}$message${NC}"
        fi
    fi
}

# Section 1: Service Status
echo -e "${BOLD}1. Service Status Tests${NC}"
echo "-----------------------------------"

if command -v systemctl &> /dev/null; then
    # Test: Service exists
    if systemctl list-unit-files | grep -q thepopebot; then
        run_test "Service file installed" "PASS"
    else
        run_test "Service file installed" "FAIL" "Service file not found"
    fi
    
    # Test: Service is active
    if systemctl is-active --quiet thepopebot; then
        run_test "Service is running" "PASS"
    else
        run_test "Service is running" "FAIL" "Service is not active"
    fi
    
    # Test: Service is enabled
    if systemctl is-enabled --quiet thepopebot 2>/dev/null; then
        run_test "Service auto-start enabled" "PASS"
    else
        run_test "Service auto-start enabled" "SKIP" "Not enabled (optional)"
    fi
    
    # Test: No failed state
    if systemctl is-failed --quiet thepopebot 2>/dev/null; then
        run_test "Service not failed" "FAIL" "Service is in failed state"
    else
        run_test "Service not failed" "PASS"
    fi
else
    run_test "systemd available" "FAIL" "systemd not found"
fi

echo ""

# Section 2: Process Tests
echo -e "${BOLD}2. Process Tests${NC}"
echo "-----------------------------------"

# Test: Process is running
if pgrep -f "$REPO_ROOT/event_handler/server.js" > /dev/null; then
    PID=$(pgrep -f "$REPO_ROOT/event_handler/server.js" | head -n1)
    run_test "Node.js process running" "PASS" "PID: $PID"
else
    run_test "Node.js process running" "FAIL" "No server.js process found"
fi

# Test: Port 3000 is in use
if command -v lsof &> /dev/null; then
    if lsof -i :3000 2>/dev/null | grep -q LISTEN; then
        PORT_PID=$(lsof -ti :3000 | head -n1)
        run_test "Port 3000 listening" "PASS" "PID: $PORT_PID"
    else
        run_test "Port 3000 listening" "FAIL" "Port 3000 is not in use"
    fi
else
    run_test "Port 3000 listening" "SKIP" "lsof not available"
fi

# Test: No duplicate processes
NODE_COUNT=$(pgrep -f "$REPO_ROOT/event_handler/server.js" | wc -l)
if [ $NODE_COUNT -eq 1 ]; then
    run_test "Single process instance" "PASS"
elif [ $NODE_COUNT -eq 0 ]; then
    run_test "Single process instance" "FAIL" "No processes running"
else
    run_test "Single process instance" "WARN" "Multiple instances detected ($NODE_COUNT)"
fi

echo ""

# Section 3: Log Tests
echo -e "${BOLD}3. Log Tests${NC}"
echo "-----------------------------------"

# Test: Log directory exists
if [ -d "/var/log/thepopebot" ]; then
    run_test "Log directory exists" "PASS" "/var/log/thepopebot"
else
    run_test "Log directory exists" "FAIL" "Directory not found"
fi

# Test: Log directory is writable
if [ -w "/var/log/thepopebot" ]; then
    run_test "Log directory writable" "PASS"
else
    run_test "Log directory writable" "FAIL" "No write permission"
fi

# Test: Output log exists
if [ -f "/var/log/thepopebot/output.log" ]; then
    SIZE=$(stat -f%z "/var/log/thepopebot/output.log" 2>/dev/null || stat -c%s "/var/log/thepopebot/output.log" 2>/dev/null || echo "0")
    run_test "Output log exists" "PASS" "Size: $SIZE bytes"
else
    run_test "Output log exists" "SKIP" "No output yet (service just started?)"
fi

# Test: Error log exists
if [ -f "/var/log/thepopebot/error.log" ]; then
    SIZE=$(stat -f%z "/var/log/thepopebot/error.log" 2>/dev/null || stat -c%s "/var/log/thepopebot/error.log" 2>/dev/null || echo "0")
    if [ "$SIZE" -eq 0 ]; then
        run_test "Error log empty" "PASS" "No errors logged"
    else
        run_test "Error log empty" "WARN" "Has $SIZE bytes of errors"
    fi
else
    run_test "Error log exists" "PASS" "No errors (log not created)"
fi

# Test: Recent logs in journald
if command -v journalctl &> /dev/null; then
    RECENT_LOGS=$(sudo journalctl -u thepopebot --since "5 minutes ago" 2>/dev/null | wc -l)
    if [ $RECENT_LOGS -gt 0 ]; then
        run_test "Recent journal logs" "PASS" "$RECENT_LOGS lines in last 5 minutes"
    else
        run_test "Recent journal logs" "WARN" "No recent logs"
    fi
else
    run_test "Journal logs available" "SKIP" "journalctl not available"
fi

echo ""

# Section 4: Configuration Tests
echo -e "${BOLD}4. Configuration Tests${NC}"
echo "-----------------------------------"

# Test: .env file exists
if [ -f "$REPO_ROOT/event_handler/.env" ]; then
    run_test ".env file exists" "PASS"
    
    # Test required variables
    if grep -q "^GH_TOKEN=" "$REPO_ROOT/event_handler/.env" 2>/dev/null; then
        run_test "GH_TOKEN configured" "PASS"
    else
        run_test "GH_TOKEN configured" "WARN" "Not found in .env"
    fi
    
    if grep -q "^API_KEY=" "$REPO_ROOT/event_handler/.env" 2>/dev/null; then
        run_test "API_KEY configured" "PASS"
    else
        run_test "API_KEY configured" "WARN" "Not found in .env"
    fi
else
    run_test ".env file exists" "FAIL" "File not found"
fi

# Test: Dependencies installed
if [ -d "$REPO_ROOT/event_handler/node_modules" ]; then
    run_test "Dependencies installed" "PASS"
else
    run_test "Dependencies installed" "FAIL" "node_modules not found"
fi

echo ""

# Section 5: Network Tests
echo -e "${BOLD}5. Network Tests${NC}"
echo "-----------------------------------"

# Test: HTTP server responding
if command -v curl &> /dev/null; then
    # Try to connect to port 3000
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 --max-time 5 2>/dev/null | grep -q "200\|401\|404"; then
        run_test "HTTP server responding" "PASS" "Server is accessible"
    else
        run_test "HTTP server responding" "FAIL" "No response from localhost:3000"
    fi
else
    run_test "HTTP server responding" "SKIP" "curl not available"
fi

# Test: Listen on correct interface
if command -v netstat &> /dev/null; then
    if netstat -tlnp 2>/dev/null | grep :3000 | grep -q LISTEN; then
        run_test "Listening on port 3000" "PASS"
    else
        run_test "Listening on port 3000" "FAIL" "Not listening"
    fi
elif command -v ss &> /dev/null; then
    if ss -tlnp 2>/dev/null | grep :3000 | grep -q LISTEN; then
        run_test "Listening on port 3000" "PASS"
    else
        run_test "Listening on port 3000" "FAIL" "Not listening"
    fi
else
    run_test "Port listening check" "SKIP" "netstat/ss not available"
fi

echo ""

# Section 6: Resource Tests
echo -e "${BOLD}6. Resource Usage Tests${NC}"
echo "-----------------------------------"

if [ ! -z "$PID" ] && ps -p $PID > /dev/null 2>&1; then
    # Memory usage
    MEM_KB=$(ps -o rss= -p $PID 2>/dev/null || echo "0")
    MEM_MB=$((MEM_KB / 1024))
    
    if [ $MEM_MB -lt 500 ]; then
        run_test "Memory usage reasonable" "PASS" "${MEM_MB}MB (under 500MB)"
    elif [ $MEM_MB -lt 1000 ]; then
        run_test "Memory usage reasonable" "WARN" "${MEM_MB}MB (under 1GB limit)"
    else
        run_test "Memory usage reasonable" "FAIL" "${MEM_MB}MB (over 1GB)"
    fi
    
    # CPU usage
    CPU_PERCENT=$(ps -o %cpu= -p $PID 2>/dev/null || echo "0")
    run_test "CPU usage" "PASS" "${CPU_PERCENT}%"
    
    # Uptime
    ELAPSED=$(ps -o etime= -p $PID 2>/dev/null | tr -d ' ' || echo "0")
    run_test "Process uptime" "PASS" "$ELAPSED"
else
    run_test "Resource checks" "SKIP" "No process found"
fi

echo ""

# Section 7: Security Tests
echo -e "${BOLD}7. Security Tests${NC}"
echo "-----------------------------------"

# Check service file permissions
if [ -f "/etc/systemd/system/thepopebot.service" ]; then
    PERMS=$(stat -c %a "/etc/systemd/system/thepopebot.service" 2>/dev/null || echo "unknown")
    if [ "$PERMS" = "644" ]; then
        run_test "Service file permissions" "PASS" "644"
    else
        run_test "Service file permissions" "WARN" "$PERMS (expected 644)"
    fi
else
    run_test "Service file permissions" "FAIL" "File not found"
fi

# Check log directory permissions
if [ -d "/var/log/thepopebot" ]; then
    PERMS=$(stat -c %a "/var/log/thepopebot" 2>/dev/null || echo "unknown")
    if [ "$PERMS" = "755" ]; then
        run_test "Log directory permissions" "PASS" "755"
    else
        run_test "Log directory permissions" "WARN" "$PERMS (expected 755)"
    fi
fi

# Check if running as root
if [ ! -z "$PID" ] && ps -p $PID > /dev/null 2>&1; then
    PROC_USER=$(ps -o user= -p $PID 2>/dev/null | tr -d ' ')
    if [ "$PROC_USER" != "root" ]; then
        run_test "Not running as root" "PASS" "Running as $PROC_USER"
    else
        run_test "Not running as root" "WARN" "Running as root (not recommended)"
    fi
fi

echo ""

# Summary
echo -e "${BLUE}${BOLD}======================================"
echo "Verification Summary"
echo "======================================${NC}"
echo ""

echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
echo ""

# Overall result
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓✓✓ ALL TESTS PASSED! ✓✓✓${NC}"
    echo ""
    echo "Your thepopebot deployment is working correctly!"
    echo ""
    echo "Recommended next steps:"
    echo "1. Test webhook endpoint (if configured)"
    echo "2. Test Telegram bot (if configured)"
    echo "3. Monitor logs for any issues"
    echo "4. Set up monitoring/alerting"
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}✗ SOME TESTS FAILED ✗${NC}"
    echo ""
    echo "Issues detected. Review failed tests above."
    echo ""
    echo "Troubleshooting:"
    echo "1. Check service status: systemctl status thepopebot"
    echo "2. View logs: sudo journalctl -u thepopebot -n 100"
    echo "3. Check error log: tail -f /var/log/thepopebot/error.log"
    echo "4. Test manual start: cd $REPO_ROOT/event_handler && node server.js"
    echo ""
    echo "If issues persist, see the rollback guide: 06-rollback.sh"
    echo ""
    exit 1
fi
