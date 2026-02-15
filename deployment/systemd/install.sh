#!/bin/bash
set -e

# thepopebot Event Handler - Installation Script
# This script installs thepopebot as a systemd service

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="thepopebot"
SERVICE_USER="thepopebot"
SERVICE_GROUP="thepopebot"
INSTALL_DIR="/opt/thepopebot"
CONFIG_DIR="/etc/thepopebot"
LOG_DIR="/var/log/thepopebot"

echo_success() { echo -e "${GREEN}✓${NC} $1"; }
echo_error() { echo -e "${RED}✗${NC} $1"; }
echo_info() { echo -e "${YELLOW}→${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo_error "This script must be run as root (use sudo)"
   exit 1
fi

echo_info "Starting thepopebot installation..."
echo ""

# 1. Check prerequisites
echo_info "Checking prerequisites..."
if ! command -v node &> /dev/null; then
    echo_error "Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo_error "Node.js version must be 18 or higher. Current: $(node --version)"
    exit 1
fi
echo_success "Node.js $(node --version) found"

if ! command -v npm &> /dev/null; then
    echo_error "npm is not installed"
    exit 1
fi
echo_success "npm $(npm --version) found"

if ! command -v git &> /dev/null; then
    echo_error "git is not installed"
    exit 1
fi
echo_success "git $(git --version | cut -d' ' -f3) found"
echo ""

# 2. Create service user
echo_info "Creating service user..."
if id "$SERVICE_USER" &>/dev/null; then
    echo_success "User $SERVICE_USER already exists"
else
    useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"
    echo_success "Created user $SERVICE_USER"
fi
echo ""

# 3. Create directories
echo_info "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"
echo_success "Created installation directories"
echo ""

# 4. Get repository URL or use current directory
if [ -d ".git" ]; then
    echo_info "Found git repository in current directory"
    REPO_PATH=$(pwd)
    USE_GIT=false
else
    echo_info "Enter your thepopebot repository URL:"
    read -p "Repository URL (or press Enter to skip): " REPO_URL
    if [ -z "$REPO_URL" ]; then
        echo_error "No repository specified. Please run this script from your thepopebot directory."
        exit 1
    fi
    USE_GIT=true
fi
echo ""

# 5. Install/copy files
echo_info "Installing thepopebot files..."
if [ "$USE_GIT" = true ]; then
    # Clone from repository
    if [ -d "$INSTALL_DIR/.git" ]; then
        echo_info "Updating existing installation..."
        cd "$INSTALL_DIR"
        sudo -u "$SERVICE_USER" git pull
    else
        echo_info "Cloning repository..."
        rm -rf "$INSTALL_DIR"/*
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
else
    # Copy from current directory
    echo_info "Copying files from current directory..."
    rsync -a --exclude='.git' --exclude='node_modules' --exclude='logs/*' \
          --exclude='tmp' --exclude='.env' "$REPO_PATH/" "$INSTALL_DIR/"
fi
echo_success "Files installed to $INSTALL_DIR"
echo ""

# 6. Install dependencies
echo_info "Installing Node.js dependencies..."
cd "$INSTALL_DIR"
npm install --production
echo_success "Dependencies installed"
echo ""

# 7. Set permissions
echo_info "Setting permissions..."
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR"
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$LOG_DIR"
chmod 755 "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$INSTALL_DIR/event_handler/cron"
mkdir -p "$INSTALL_DIR/event_handler/triggers"
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR/logs"
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR/event_handler/cron"
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR/event_handler/triggers"
echo_success "Permissions configured"
echo ""

# 8. Install environment file
echo_info "Setting up environment configuration..."
if [ ! -f "$CONFIG_DIR/thepopebot.env" ]; then
    cp "$INSTALL_DIR/deployment/systemd/thepopebot.env.example" "$CONFIG_DIR/thepopebot.env"
    chmod 600 "$CONFIG_DIR/thepopebot.env"
    chown root:root "$CONFIG_DIR/thepopebot.env"
    echo_success "Created environment file at $CONFIG_DIR/thepopebot.env"
    echo ""
    echo_error "⚠️  IMPORTANT: Edit $CONFIG_DIR/thepopebot.env with your credentials"
    echo_info "   Required variables: GH_TOKEN, GH_OWNER, GH_REPO, API_KEY"
else
    echo_success "Environment file already exists at $CONFIG_DIR/thepopebot.env"
fi
echo ""

# 9. Install systemd service
echo_info "Installing systemd service..."
cp "$INSTALL_DIR/deployment/systemd/thepopebot.service" /etc/systemd/system/
chmod 644 /etc/systemd/system/thepopebot.service
systemctl daemon-reload
echo_success "Service installed"
echo ""

# 10. Enable service
echo_info "Enabling service to start on boot..."
systemctl enable thepopebot.service
echo_success "Service enabled"
echo ""

# 11. Installation complete
echo ""
echo_success "═══════════════════════════════════════════════════════════"
echo_success "  thepopebot installation complete!"
echo_success "═══════════════════════════════════════════════════════════"
echo ""
echo_info "Next steps:"
echo ""
echo "  1. Edit the environment file:"
echo "     sudo nano $CONFIG_DIR/thepopebot.env"
echo ""
echo "  2. Start the service:"
echo "     sudo systemctl start thepopebot"
echo ""
echo "  3. Check the status:"
echo "     sudo systemctl status thepopebot"
echo ""
echo "  4. View logs:"
echo "     sudo journalctl -u thepopebot -f"
echo ""
echo_info "Management script available at: $INSTALL_DIR/deployment/systemd/manage.sh"
echo ""
