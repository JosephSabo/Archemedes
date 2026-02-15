#!/bin/bash

# thepopebot Event Handler - Management Script
# Provides convenient commands for managing the thepopebot service

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVICE_NAME="thepopebot"
CONFIG_FILE="/etc/thepopebot/thepopebot.env"
INSTALL_DIR="/opt/thepopebot"

echo_success() { echo -e "${GREEN}✓${NC} $1"; }
echo_error() { echo -e "${RED}✗${NC} $1"; }
echo_info() { echo -e "${BLUE}→${NC} $1"; }
echo_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Function to check if service exists
check_service() {
    if ! systemctl list-unit-files | grep -q "^$SERVICE_NAME.service"; then
        echo_error "Service $SERVICE_NAME is not installed"
        echo_info "Run: sudo $INSTALL_DIR/deployment/systemd/install.sh"
        exit 1
    fi
}

# Function to check if running as root when needed
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo_error "This command requires root privileges"
        echo_info "Run: sudo $0 $1"
        exit 1
    fi
}

# Show usage
usage() {
    echo ""
    echo "thepopebot Management Script"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  start       Start the service"
    echo "  stop        Stop the service"
    echo "  restart     Restart the service"
    echo "  status      Show service status"
    echo "  enable      Enable service to start on boot"
    echo "  disable     Disable service from starting on boot"
    echo "  logs        Show recent logs (live tail)"
    echo "  logs-full   Show full log history"
    echo "  config      Edit configuration file"
    echo "  validate    Validate configuration"
    echo "  update      Update installation from git"
    echo "  health      Check service health"
    echo ""
}

# Start service
cmd_start() {
    check_root "start"
    check_service
    echo_info "Starting $SERVICE_NAME..."
    systemctl start "$SERVICE_NAME"
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo_success "Service started successfully"
        systemctl status "$SERVICE_NAME" --no-pager -l
    else
        echo_error "Service failed to start"
        echo_info "Check logs with: sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
}

# Stop service
cmd_stop() {
    check_root "stop"
    check_service
    echo_info "Stopping $SERVICE_NAME..."
    systemctl stop "$SERVICE_NAME"
    echo_success "Service stopped"
}

# Restart service
cmd_restart() {
    check_root "restart"
    check_service
    echo_info "Restarting $SERVICE_NAME..."
    systemctl restart "$SERVICE_NAME"
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo_success "Service restarted successfully"
        systemctl status "$SERVICE_NAME" --no-pager -l
    else
        echo_error "Service failed to restart"
        echo_info "Check logs with: sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
}

# Show status
cmd_status() {
    check_service
    systemctl status "$SERVICE_NAME" --no-pager -l
}

# Enable service
cmd_enable() {
    check_root "enable"
    check_service
    echo_info "Enabling $SERVICE_NAME to start on boot..."
    systemctl enable "$SERVICE_NAME"
    echo_success "Service enabled"
}

# Disable service
cmd_disable() {
    check_root "disable"
    check_service
    echo_info "Disabling $SERVICE_NAME from starting on boot..."
    systemctl disable "$SERVICE_NAME"
    echo_success "Service disabled"
}

# Show logs
cmd_logs() {
    check_service
    echo_info "Showing logs (Ctrl+C to exit)..."
    echo ""
    journalctl -u "$SERVICE_NAME" -f
}

# Show full logs
cmd_logs_full() {
    check_service
    journalctl -u "$SERVICE_NAME" --no-pager
}

# Edit configuration
cmd_config() {
    check_root "config"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Determine editor
    if [ -n "$EDITOR" ]; then
        EDIT_CMD="$EDITOR"
    elif command -v nano &> /dev/null; then
        EDIT_CMD="nano"
    elif command -v vim &> /dev/null; then
        EDIT_CMD="vim"
    else
        EDIT_CMD="vi"
    fi
    
    echo_info "Opening configuration file with $EDIT_CMD..."
    $EDIT_CMD "$CONFIG_FILE"
    
    echo ""
    read -p "Restart service to apply changes? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        cmd_restart
    else
        echo_info "Remember to restart the service to apply changes"
    fi
}

# Validate configuration
cmd_validate() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    echo_info "Validating configuration..."
    echo ""
    
    # Source the config file
    set -a
    source "$CONFIG_FILE"
    set +a
    
    # Check required variables
    MISSING=0
    
    check_var() {
        local var_name=$1
        local var_value=${!var_name}
        if [ -z "$var_value" ]; then
            echo_error "$var_name is not set"
            MISSING=1
        else
            echo_success "$var_name is set"
        fi
    }
    
    echo "Required variables:"
    check_var "GH_TOKEN"
    check_var "GH_OWNER"
    check_var "GH_REPO"
    check_var "API_KEY"
    
    echo ""
    echo "Optional variables:"
    check_var "PORT"
    check_var "TELEGRAM_BOT_TOKEN"
    check_var "ANTHROPIC_API_KEY"
    
    echo ""
    if [ $MISSING -eq 0 ]; then
        echo_success "Configuration is valid"
    else
        echo_error "Configuration is missing required variables"
        exit 1
    fi
}

# Update installation
cmd_update() {
    check_root "update"
    
    if [ ! -d "$INSTALL_DIR/.git" ]; then
        echo_error "Installation directory is not a git repository"
        echo_info "Cannot update automatically"
        exit 1
    fi
    
    echo_info "Updating thepopebot installation..."
    echo ""
    
    # Stop service
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo_info "Stopping service..."
        systemctl stop "$SERVICE_NAME"
    fi
    
    # Pull updates
    echo_info "Pulling latest changes..."
    cd "$INSTALL_DIR"
    sudo -u thepopebot git pull
    
    # Install dependencies
    echo_info "Updating dependencies..."
    npm install --production
    
    # Reload systemd
    echo_info "Reloading systemd..."
    cp "$INSTALL_DIR/deployment/systemd/thepopebot.service" /etc/systemd/system/
    systemctl daemon-reload
    
    # Start service
    echo_info "Starting service..."
    systemctl start "$SERVICE_NAME"
    
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo ""
        echo_success "Update completed successfully"
    else
        echo ""
        echo_error "Service failed to start after update"
        echo_info "Check logs with: sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
}

# Health check
cmd_health() {
    check_service
    
    echo_info "Checking service health..."
    echo ""
    
    # Check if service is active
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo_success "Service is running"
    else
        echo_error "Service is not running"
        exit 1
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        echo_success "Service is enabled (will start on boot)"
    else
        echo_warn "Service is not enabled (will not start on boot)"
    fi
    
    # Show uptime
    UPTIME=$(systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp --value)
    if [ -n "$UPTIME" ]; then
        echo_success "Service started: $UPTIME"
    fi
    
    # Check port
    source "$CONFIG_FILE" 2>/dev/null || true
    PORT=${PORT:-3000}
    if netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
        echo_success "Listening on port $PORT"
    else
        echo_warn "Not listening on port $PORT (may still be starting)"
    fi
    
    # Show recent errors
    ERROR_COUNT=$(journalctl -u "$SERVICE_NAME" --since "1 hour ago" -p err -q | wc -l)
    if [ "$ERROR_COUNT" -eq 0 ]; then
        echo_success "No errors in the last hour"
    else
        echo_warn "$ERROR_COUNT errors in the last hour"
        echo_info "View with: sudo journalctl -u $SERVICE_NAME -p err --since '1 hour ago'"
    fi
    
    echo ""
    echo_success "Health check complete"
}

# Main command dispatcher
case "${1:-}" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    enable)
        cmd_enable
        ;;
    disable)
        cmd_disable
        ;;
    logs)
        cmd_logs
        ;;
    logs-full)
        cmd_logs_full
        ;;
    config)
        cmd_config
        ;;
    validate)
        cmd_validate
        ;;
    update)
        cmd_update
        ;;
    health)
        cmd_health
        ;;
    *)
        usage
        exit 1
        ;;
esac
