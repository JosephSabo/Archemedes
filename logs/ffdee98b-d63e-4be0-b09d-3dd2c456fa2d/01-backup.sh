#!/bin/bash
# thepopebot Pre-Deployment Backup Script
# Creates a complete backup before systemd migration
# Run this FIRST on your HOST system

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}======================================"
echo "thepopebot Pre-Deployment Backup"
echo "======================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${YELLOW}Repository root: $REPO_ROOT${NC}"
echo ""

# Create backup directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$REPO_ROOT/backups/pre-systemd-$TIMESTAMP"

echo "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Function to backup with status
backup_item() {
    local source=$1
    local name=$2
    
    if [ -e "$source" ]; then
        echo -n "Backing up $name... "
        cp -r "$source" "$BACKUP_DIR/" 2>/dev/null || {
            echo -e "${RED}FAILED${NC}"
            return 1
        }
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ $name not found - skipping${NC}"
        return 0
    fi
}

echo ""
echo "Backing up configuration files..."
echo "-----------------------------------"

# Backup .env file
backup_item "$REPO_ROOT/event_handler/.env" ".env file"

# Backup package files
backup_item "$REPO_ROOT/event_handler/package.json" "package.json"
backup_item "$REPO_ROOT/event_handler/package-lock.json" "package-lock.json"

# Backup operating system config
backup_item "$REPO_ROOT/operating_system" "operating_system directory"

# Backup event handler code
echo ""
echo "Backing up event handler code..."
echo "-----------------------------------"
backup_item "$REPO_ROOT/event_handler" "event_handler directory"

# Backup logs directory
echo ""
echo "Backing up logs directory..."
echo "-----------------------------------"
backup_item "$REPO_ROOT/logs" "logs directory"

# Save current process state
echo ""
echo "Capturing current process state..."
echo "-----------------------------------"

{
    echo "# thepopebot Process State Snapshot"
    echo "# Captured: $(date)"
    echo "# Hostname: $(hostname)"
    echo ""
    
    echo "## Node.js Processes"
    ps aux | grep node | grep -v grep || echo "No Node.js processes found"
    echo ""
    
    echo "## Port 3000 Status"
    if command -v lsof &> /dev/null; then
        lsof -i :3000 2>/dev/null || echo "Port 3000 is free"
    else
        echo "lsof not available"
    fi
    echo ""
    
    echo "## PM2 Status"
    if command -v pm2 &> /dev/null; then
        pm2 list 2>/dev/null || echo "No PM2 processes"
    else
        echo "PM2 not installed"
    fi
    echo ""
    
    echo "## Screen Sessions"
    if command -v screen &> /dev/null; then
        screen -ls 2>&1 || echo "No screen sessions"
    else
        echo "screen not installed"
    fi
    echo ""
    
    echo "## systemd Status"
    if command -v systemctl &> /dev/null; then
        systemctl status thepopebot 2>&1 || echo "systemd service not found"
    else
        echo "systemd not available"
    fi
    
} > "$BACKUP_DIR/process-state.txt"

echo -e "${GREEN}✓ Process state captured${NC}"

# Create backup manifest
echo ""
echo "Creating backup manifest..."
echo "-----------------------------------"

{
    echo "# thepopebot Backup Manifest"
    echo "# Created: $(date)"
    echo "# Backup directory: $BACKUP_DIR"
    echo ""
    echo "## Backed up files:"
    echo ""
    find "$BACKUP_DIR" -type f -o -type d | sed "s|$BACKUP_DIR/||g" | sort
    echo ""
    echo "## Disk usage:"
    du -sh "$BACKUP_DIR"
} > "$BACKUP_DIR/MANIFEST.txt"

echo -e "${GREEN}✓ Manifest created${NC}"

# Create restore instructions
cat > "$BACKUP_DIR/RESTORE.sh" << 'EOF'
#!/bin/bash
# thepopebot Backup Restore Script
# Use this to rollback changes if needed

set -e

echo "======================================"
echo "thepopebot Backup Restore"
echo "======================================"
echo ""

BACKUP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$BACKUP_DIR/../.." && pwd)"

echo "This will restore from backup:"
echo "  Backup: $BACKUP_DIR"
echo "  Target: $REPO_ROOT"
echo ""

read -p "Are you sure you want to restore? This will overwrite current files. (yes/NO): " -r
echo ""

if [ "$REPLY" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo "Restoring files..."

# Restore .env
if [ -f "$BACKUP_DIR/.env" ]; then
    echo "Restoring .env..."
    cp "$BACKUP_DIR/.env" "$REPO_ROOT/event_handler/.env"
fi

# Restore operating_system
if [ -d "$BACKUP_DIR/operating_system" ]; then
    echo "Restoring operating_system..."
    rm -rf "$REPO_ROOT/operating_system"
    cp -r "$BACKUP_DIR/operating_system" "$REPO_ROOT/"
fi

# Restore event_handler
if [ -d "$BACKUP_DIR/event_handler" ]; then
    echo "Restoring event_handler..."
    rm -rf "$REPO_ROOT/event_handler"
    cp -r "$BACKUP_DIR/event_handler" "$REPO_ROOT/"
fi

echo ""
echo "✓ Restore complete!"
echo ""
echo "Next steps:"
echo "1. Stop systemd service: sudo systemctl stop thepopebot"
echo "2. Reinstall dependencies: cd $REPO_ROOT/event_handler && npm install"
echo "3. Start service manually: node server.js"
echo "4. Or start systemd: sudo systemctl start thepopebot"
EOF

chmod +x "$BACKUP_DIR/RESTORE.sh"

# Summary
echo ""
echo -e "${BLUE}${BOLD}======================================"
echo "Backup Complete!"
echo "======================================${NC}"
echo ""
echo -e "${GREEN}Backup location:${NC} $BACKUP_DIR"
echo ""
echo "Backed up:"
echo "  • Configuration files (.env, package.json)"
echo "  • Event handler code"
echo "  • Operating system config"
echo "  • Logs directory"
echo "  • Current process state"
echo ""
echo "To restore this backup later, run:"
echo -e "${YELLOW}  $BACKUP_DIR/RESTORE.sh${NC}"
echo ""

# Calculate total size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "Total backup size: $BACKUP_SIZE"
echo ""
echo -e "${GREEN}✓✓✓ Ready to proceed with deployment ✓✓✓${NC}"
echo ""
echo "Next step: Run ./02-diagnostic.sh"
echo ""
