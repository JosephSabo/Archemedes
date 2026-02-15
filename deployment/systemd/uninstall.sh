#!/bin/bash
set -e

# thepopebot Event Handler - Uninstallation Script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="thepopebot"
SERVICE_USER="thepopebot"
INSTALL_DIR="/opt/thepopebot"
CONFIG_DIR="/etc/thepopebot"
LOG_DIR="/var/log/thepopebot"

echo_success() { echo -e "${GREEN}✓${NC} $1"; }
echo_error() { echo -e "${RED}✗${NC} $1"; }
echo_info() { echo -e "${YELLOW}→${NC} $1"; }
echo_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo_error "This script must be run as root (use sudo)"
   exit 1
fi

echo ""
echo_warn "═══════════════════════════════════════════════════════════"
echo_warn "  WARNING: This will completely remove thepopebot"
echo_warn "═══════════════════════════════════════════════════════════"
echo ""
echo_info "The following will be removed:"
echo "  - Service: /etc/systemd/system/$SERVICE_NAME.service"
echo "  - Installation: $INSTALL_DIR"
echo "  - Logs: $LOG_DIR"
echo ""
echo_warn "The following will be PRESERVED:"
echo "  - Configuration: $CONFIG_DIR (contains credentials)"
echo "  - User account: $SERVICE_USER"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo_info "Uninstallation cancelled"
    exit 0
fi

echo_info "Starting uninstallation..."
echo ""

# 1. Stop and disable service
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo_info "Stopping service..."
    systemctl stop "$SERVICE_NAME"
    echo_success "Service stopped"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo_info "Disabling service..."
    systemctl disable "$SERVICE_NAME"
    echo_success "Service disabled"
fi
echo ""

# 2. Remove service file
if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
    echo_info "Removing service file..."
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    systemctl daemon-reload
    echo_success "Service file removed"
fi
echo ""

# 3. Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
    echo_info "Removing installation directory..."
    rm -rf "$INSTALL_DIR"
    echo_success "Installation directory removed"
fi
echo ""

# 4. Remove logs (with confirmation)
if [ -d "$LOG_DIR" ]; then
    read -p "Remove log directory $LOG_DIR? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        rm -rf "$LOG_DIR"
        echo_success "Log directory removed"
    else
        echo_info "Log directory preserved"
    fi
fi
echo ""

# 5. Ask about config directory
if [ -d "$CONFIG_DIR" ]; then
    echo ""
    echo_warn "Configuration directory contains credentials:"
    echo "  $CONFIG_DIR"
    echo ""
    read -p "Remove configuration directory? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        rm -rf "$CONFIG_DIR"
        echo_success "Configuration directory removed"
    else
        echo_info "Configuration directory preserved"
    fi
fi
echo ""

# 6. Ask about user account
echo_warn "User account $SERVICE_USER still exists"
read -p "Remove user account? (yes/no): " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    userdel "$SERVICE_USER" 2>/dev/null || true
    echo_success "User account removed"
else
    echo_info "User account preserved"
fi
echo ""

# 7. Uninstallation complete
echo ""
echo_success "═══════════════════════════════════════════════════════════"
echo_success "  thepopebot has been uninstalled"
echo_success "═══════════════════════════════════════════════════════════"
echo ""

if [ -d "$CONFIG_DIR" ]; then
    echo_warn "Preserved configuration: $CONFIG_DIR"
fi

echo ""
