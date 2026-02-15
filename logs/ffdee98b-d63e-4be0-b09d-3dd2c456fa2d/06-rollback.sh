#!/bin/bash
# thepopebot Rollback Script
# Safely rollback systemd deployment and restore previous state
# Run this if you need to undo the deployment

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}======================================"
echo "thepopebot Deployment Rollback"
echo "======================================${NC}"
echo ""

# Get paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${RED}${BOLD}WARNING: This will remove the systemd service${NC}"
echo ""
echo "This script will:"
echo "  1. Stop the thepopebot systemd service"
echo "  2. Disable auto-start"
echo "  3. Remove the service file"
echo "  4. Optionally restore from backup"
echo "  5. Clean up logs (optional)"
echo ""

read -p "Are you sure you want to rollback? (yes/NO): " -r
echo ""

if [ "$REPLY" != "yes" ]; then
    echo "Rollback cancelled."
    exit 0
fi

echo ""

# Step 1: Stop service
echo -e "${BOLD}Step 1: Stopping systemd service...${NC}"
echo "-----------------------------------"

if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet thepopebot 2>/dev/null; then
        echo "Stopping thepopebot service..."
        sudo systemctl stop thepopebot
        sleep 2
        
        if ! systemctl is-active --quiet thepopebot; then
            echo -e "${GREEN}✓ Service stopped${NC}"
        else
            echo -e "${RED}✗ Failed to stop service${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Service not running${NC}"
    fi
else
    echo -e "${YELLOW}systemd not available${NC}"
fi

echo ""

# Step 2: Disable service
echo -e "${BOLD}Step 2: Disabling auto-start...${NC}"
echo "-----------------------------------"

if systemctl is-enabled --quiet thepopebot 2>/dev/null; then
    echo "Disabling thepopebot service..."
    sudo systemctl disable thepopebot
    echo -e "${GREEN}✓ Auto-start disabled${NC}"
else
    echo -e "${YELLOW}Service not enabled${NC}"
fi

echo ""

# Step 3: Remove service file
echo -e "${BOLD}Step 3: Removing service file...${NC}"
echo "-----------------------------------"

if [ -f "/etc/systemd/system/thepopebot.service" ]; then
    # Create final backup
    TIMESTAMP=$(date +%s)
    BACKUP_FILE="/etc/systemd/system/thepopebot.service.removed.$TIMESTAMP"
    
    echo "Creating final backup: $BACKUP_FILE"
    sudo cp /etc/systemd/system/thepopebot.service "$BACKUP_FILE"
    
    echo "Removing service file..."
    sudo rm /etc/systemd/system/thepopebot.service
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}✓ Service file removed${NC}"
    echo "  Backup saved: $BACKUP_FILE"
else
    echo -e "${YELLOW}Service file not found${NC}"
fi

echo ""

# Step 4: Restore from backup
echo -e "${BOLD}Step 4: Restore from backup?${NC}"
echo "-----------------------------------"

# Find most recent backup
BACKUP_DIR=$(find "$REPO_ROOT/backups" -type d -name "pre-systemd-*" 2>/dev/null | sort -r | head -n1 || echo "")

if [ ! -z "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    echo "Found backup: $BACKUP_DIR"
    echo ""
    
    if [ -f "$BACKUP_DIR/MANIFEST.txt" ]; then
        echo "Backup manifest:"
        cat "$BACKUP_DIR/MANIFEST.txt" | head -n 10
        echo ""
    fi
    
    read -p "Restore from this backup? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "$BACKUP_DIR/RESTORE.sh" ]; then
            echo "Running restore script..."
            bash "$BACKUP_DIR/RESTORE.sh"
            echo -e "${GREEN}✓ Backup restored${NC}"
        else
            echo -e "${YELLOW}⚠ Restore script not found${NC}"
            echo "Manual restore needed from: $BACKUP_DIR"
        fi
    else
        echo "Skipping restore"
    fi
else
    echo -e "${YELLOW}No backup found${NC}"
    echo "To restore manually, see: $REPO_ROOT/backups/"
fi

echo ""

# Step 5: Clean up logs
echo -e "${BOLD}Step 5: Clean up logs?${NC}"
echo "-----------------------------------"

if [ -d "/var/log/thepopebot" ]; then
    LOG_SIZE=$(du -sh /var/log/thepopebot 2>/dev/null | cut -f1)
    echo "Log directory size: $LOG_SIZE"
    echo ""
    
    read -p "Remove log directory? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Archive logs first
        ARCHIVE="/tmp/thepopebot-logs-$(date +%Y%m%d_%H%M%S).tar.gz"
        echo "Archiving logs to: $ARCHIVE"
        sudo tar -czf "$ARCHIVE" -C /var/log thepopebot 2>/dev/null || true
        
        echo "Removing log directory..."
        sudo rm -rf /var/log/thepopebot
        
        echo -e "${GREEN}✓ Logs archived and removed${NC}"
        echo "  Archive: $ARCHIVE"
    else
        echo "Logs preserved at: /var/log/thepopebot"
    fi
else
    echo -e "${YELLOW}Log directory not found${NC}"
fi

echo ""

# Step 6: Verify clean state
echo -e "${BOLD}Step 6: Verifying clean state...${NC}"
echo "-----------------------------------"

ISSUES=0

# Check service
if systemctl list-unit-files 2>/dev/null | grep -q thepopebot; then
    echo -e "${YELLOW}⚠ Service still listed in systemd${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✓ Service removed from systemd${NC}"
fi

# Check service file
if [ -f "/etc/systemd/system/thepopebot.service" ]; then
    echo -e "${YELLOW}⚠ Service file still exists${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✓ Service file removed${NC}"
fi

# Check processes
if pgrep -f "$REPO_ROOT/event_handler/server.js" > /dev/null; then
    echo -e "${YELLOW}⚠ Node.js process still running${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✓ No Node.js processes running${NC}"
fi

# Check port
if command -v lsof &> /dev/null && lsof -ti :3000 > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Port 3000 still in use${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✓ Port 3000 is free${NC}"
fi

echo ""

# Summary
echo -e "${BLUE}${BOLD}======================================"
echo "Rollback Complete"
echo "======================================${NC}"
echo ""

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓✓✓ Rollback successful! ✓✓✓${NC}"
    echo ""
    echo "The systemd service has been completely removed."
    echo ""
    echo "Your system is back to its pre-deployment state."
    echo ""
    echo "What's next:"
    echo "  • To run manually: cd $REPO_ROOT/event_handler && node server.js"
    echo "  • To redeploy: Run ./01-backup.sh and start over"
    echo "  • Backups are preserved in: $REPO_ROOT/backups/"
    echo ""
else
    echo -e "${YELLOW}${BOLD}⚠ Rollback completed with warnings ⚠${NC}"
    echo ""
    echo "Issues detected: $ISSUES"
    echo ""
    echo "Manual cleanup may be needed:"
    echo "  • Check: systemctl status thepopebot"
    echo "  • Check: ps aux | grep server.js"
    echo "  • Check: lsof -i :3000"
    echo ""
fi

# Additional cleanup suggestions
echo "Additional cleanup (if needed):"
echo "  • Remove service file: sudo rm /etc/systemd/system/thepopebot.service*"
echo "  • Reload systemd: sudo systemctl daemon-reload"
echo "  • Kill process: pkill -f server.js"
echo "  • Remove logs: sudo rm -rf /var/log/thepopebot"
echo ""

# Show how to start manually
echo "To start thepopebot manually:"
echo "  cd $REPO_ROOT/event_handler"
echo "  node server.js"
echo ""
