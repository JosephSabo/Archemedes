#!/bin/bash
# thepopebot systemd Deployment Script
# Automated deployment with smart configuration detection
# Run this on your HOST system after stopping existing processes

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}======================================"
echo "thepopebot systemd Deployment"
echo "======================================${NC}"
echo ""

# Get paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EVENT_HANDLER="$REPO_ROOT/event_handler"

echo -e "${YELLOW}Repository root: $REPO_ROOT${NC}"
echo -e "${YELLOW}Event handler: $EVENT_HANDLER${NC}"
echo ""

# Detect configuration
echo -e "${BOLD}Detecting system configuration...${NC}"
echo "-----------------------------------"

# Detect username
DETECTED_USER=$(whoami)
echo "• Username: $DETECTED_USER"

# Detect Node.js path
if command -v node &> /dev/null; then
    DETECTED_NODE=$(which node)
    NODE_VERSION=$(node --version)
    echo "• Node.js: $DETECTED_NODE ($NODE_VERSION)"
else
    echo -e "${RED}✗ Node.js not found!${NC}"
    exit 1
fi

# Detect npm path
if command -v npm &> /dev/null; then
    DETECTED_NPM=$(which npm)
    NPM_VERSION=$(npm --version)
    echo "• npm: $DETECTED_NPM ($NPM_VERSION)"
else
    echo -e "${YELLOW}⚠ npm not found${NC}"
fi

# Check if .env exists
if [ -f "$EVENT_HANDLER/.env" ]; then
    echo -e "• .env file: ${GREEN}Found${NC}"
else
    echo -e "• .env file: ${YELLOW}Not found${NC}"
fi

# Check if dependencies are installed
if [ -d "$EVENT_HANDLER/node_modules" ]; then
    echo -e "• Dependencies: ${GREEN}Installed${NC}"
    NEED_INSTALL=0
else
    echo -e "• Dependencies: ${YELLOW}Need installation${NC}"
    NEED_INSTALL=1
fi

echo ""

# Confirm configuration
echo -e "${BOLD}Configuration to use:${NC}"
echo "-----------------------------------"
echo "User: $DETECTED_USER"
echo "Node: $DETECTED_NODE"
echo "Working Directory: $EVENT_HANDLER"
echo "Repository Root: $REPO_ROOT"
echo ""

read -p "Is this configuration correct? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""

# Step 1: Install dependencies if needed
if [ $NEED_INSTALL -eq 1 ]; then
    echo -e "${BOLD}Step 1: Installing dependencies...${NC}"
    echo "-----------------------------------"
    cd "$EVENT_HANDLER"
    
    if command -v npm &> /dev/null; then
        npm install
        echo -e "${GREEN}✓ Dependencies installed${NC}"
    else
        echo -e "${RED}✗ npm not available - cannot install dependencies${NC}"
        echo "Please install dependencies manually and re-run this script."
        exit 1
    fi
    echo ""
else
    echo -e "${BOLD}Step 1: Dependencies${NC}"
    echo "-----------------------------------"
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
    echo ""
fi

# Step 2: Create log directory
echo -e "${BOLD}Step 2: Creating log directory...${NC}"
echo "-----------------------------------"

if [ ! -d "/var/log/thepopebot" ]; then
    sudo mkdir -p /var/log/thepopebot
    sudo chown $DETECTED_USER:$DETECTED_USER /var/log/thepopebot
    sudo chmod 755 /var/log/thepopebot
    echo -e "${GREEN}✓ Log directory created: /var/log/thepopebot${NC}"
else
    echo -e "${GREEN}✓ Log directory already exists${NC}"
    # Ensure correct permissions
    sudo chown $DETECTED_USER:$DETECTED_USER /var/log/thepopebot
fi

echo ""

# Step 3: Generate service file
echo -e "${BOLD}Step 3: Generating systemd service file...${NC}"
echo "-----------------------------------"

SERVICE_FILE="$SCRIPT_DIR/thepopebot.service"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=thepopebot Event Handler - Autonomous AI Agent System
Documentation=https://github.com/stephengpope/thepopebot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$DETECTED_USER
WorkingDirectory=$EVENT_HANDLER
Environment="NODE_ENV=production"
EnvironmentFile=$EVENT_HANDLER/.env
ExecStart=$DETECTED_NODE server.js

# Restart behavior
Restart=always
RestartSec=10
StartLimitBurst=5
StartLimitIntervalSec=300

# Logging
StandardOutput=append:/var/log/thepopebot/output.log
StandardError=append:/var/log/thepopebot/error.log
SyslogIdentifier=thepopebot

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$REPO_ROOT
ReadWritePaths=/var/log/thepopebot

# Resource limits
MemoryMax=1G
CPUQuota=50%

[Install]
WantedBy=multi-user.target
EOF

echo "Generated service file: $SERVICE_FILE"
echo ""
echo "Service configuration:"
cat "$SERVICE_FILE" | grep -E "^(User|WorkingDirectory|ExecStart|EnvironmentFile)=" | sed 's/^/  /'
echo ""

read -p "Does this look correct? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "You can manually edit the service file at: $SERVICE_FILE"
    echo "Then run: sudo cp $SERVICE_FILE /etc/systemd/system/"
    exit 0
fi

echo -e "${GREEN}✓ Service file generated${NC}"
echo ""

# Step 4: Install service
echo -e "${BOLD}Step 4: Installing systemd service...${NC}"
echo "-----------------------------------"

# Backup existing service if it exists
if [ -f "/etc/systemd/system/thepopebot.service" ]; then
    echo "Backing up existing service file..."
    sudo cp /etc/systemd/system/thepopebot.service /etc/systemd/system/thepopebot.service.backup.$(date +%s)
    echo -e "${GREEN}✓ Existing service backed up${NC}"
fi

# Copy service file
sudo cp "$SERVICE_FILE" /etc/systemd/system/thepopebot.service
sudo chmod 644 /etc/systemd/system/thepopebot.service
echo -e "${GREEN}✓ Service file installed${NC}"

# Reload systemd
sudo systemctl daemon-reload
echo -e "${GREEN}✓ systemd reloaded${NC}"

echo ""

# Step 5: Start service
echo -e "${BOLD}Step 5: Starting service...${NC}"
echo "-----------------------------------"

echo "Starting thepopebot service..."
sudo systemctl start thepopebot

# Wait a moment for startup
sleep 3

# Check status
if systemctl is-active --quiet thepopebot; then
    echo -e "${GREEN}✓ Service started successfully!${NC}"
    echo ""
    systemctl status thepopebot --no-pager --lines=10
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo ""
    echo "Checking logs..."
    sudo journalctl -u thepopebot -n 50 --no-pager
    echo ""
    echo "Troubleshooting:"
    echo "1. Check logs: sudo journalctl -u thepopebot -n 100"
    echo "2. Verify .env file exists: ls -la $EVENT_HANDLER/.env"
    echo "3. Test manual start: cd $EVENT_HANDLER && node server.js"
    echo "4. Check file permissions"
    exit 1
fi

echo ""

# Step 6: Enable auto-start (optional)
echo -e "${BOLD}Step 6: Enable auto-start on boot?${NC}"
echo "-----------------------------------"

read -p "Enable thepopebot to start automatically on system boot? (Y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    sudo systemctl enable thepopebot
    echo -e "${GREEN}✓ Auto-start enabled${NC}"
else
    echo "Auto-start not enabled. Enable later with:"
    echo "  sudo systemctl enable thepopebot"
fi

echo ""

# Summary
echo -e "${BLUE}${BOLD}======================================"
echo "Deployment Complete!"
echo "======================================${NC}"
echo ""

echo -e "${GREEN}✓ thepopebot is now running as a systemd service${NC}"
echo ""

echo "Service Details:"
echo "  • Status: $(systemctl is-active thepopebot)"
echo "  • Enabled: $(systemctl is-enabled thepopebot 2>/dev/null || echo 'disabled')"
echo "  • User: $DETECTED_USER"
echo "  • Working Directory: $EVENT_HANDLER"
echo "  • Logs: /var/log/thepopebot/"
echo ""

echo "Quick Reference Commands:"
echo "  • Check status:   systemctl status thepopebot"
echo "  • View logs:      sudo journalctl -u thepopebot -f"
echo "  • Restart:        sudo systemctl restart thepopebot"
echo "  • Stop:           sudo systemctl stop thepopebot"
echo "  • Enable startup: sudo systemctl enable thepopebot"
echo "  • Disable:        sudo systemctl disable thepopebot"
echo ""

echo "Log files:"
echo "  • Output: /var/log/thepopebot/output.log"
echo "  • Errors: /var/log/thepopebot/error.log"
echo "  • System: sudo journalctl -u thepopebot"
echo ""

echo "Next steps:"
echo "1. Run ./05-verify.sh to test the deployment"
echo "2. Monitor logs: sudo journalctl -u thepopebot -f"
echo "3. Test functionality (webhooks, Telegram, etc.)"
echo ""

echo -e "${GREEN}${BOLD}Deployment successful! 🚀${NC}"
echo ""
