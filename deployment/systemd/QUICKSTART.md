# thepopebot Systemd Service - Quick Start

## Installation (3 Steps)

### 1. Run Installation Script
```bash
sudo deployment/systemd/install.sh
```

### 2. Configure Environment
```bash
sudo nano /etc/thepopebot/thepopebot.env
```

Set these required variables:
- `GH_TOKEN` - Your GitHub Personal Access Token
- `GH_OWNER` - Your GitHub username/org
- `GH_REPO` - Your repository name
- `API_KEY` - A secure random string

### 3. Start Service
```bash
sudo systemctl start thepopebot
sudo systemctl status thepopebot
```

## Daily Usage

```bash
# Using the management script (recommended)
sudo deployment/systemd/manage.sh start      # Start service
sudo deployment/systemd/manage.sh stop       # Stop service
sudo deployment/systemd/manage.sh restart    # Restart service
sudo deployment/systemd/manage.sh logs       # View live logs
sudo deployment/systemd/manage.sh status     # Check status
sudo deployment/systemd/manage.sh health     # Health check

# Or using systemctl directly
sudo systemctl start thepopebot
sudo systemctl stop thepopebot
sudo systemctl restart thepopebot
sudo systemctl status thepopebot

# View logs
sudo journalctl -u thepopebot -f            # Live tail
sudo journalctl -u thepopebot -n 100        # Last 100 lines
```

## Common Tasks

### Update from Git
```bash
sudo deployment/systemd/manage.sh update
```

### Edit Configuration
```bash
sudo deployment/systemd/manage.sh config
```

### Validate Configuration
```bash
sudo deployment/systemd/manage.sh validate
```

### Enable Auto-start on Boot
```bash
sudo systemctl enable thepopebot
```

### Disable Auto-start
```bash
sudo systemctl disable thepopebot
```

## Troubleshooting

### Service won't start?
```bash
# Check logs
sudo journalctl -u thepopebot -n 50

# Validate configuration
sudo deployment/systemd/manage.sh validate

# Test manually
sudo -u thepopebot bash
cd /opt/thepopebot
source /etc/thepopebot/thepopebot.env
node event_handler/server.js
```

### Check service health
```bash
sudo deployment/systemd/manage.sh health
```

### View recent errors
```bash
sudo journalctl -u thepopebot -p err --since "1 hour ago"
```

## Uninstallation

```bash
sudo deployment/systemd/uninstall.sh
```

## Files & Directories

- **Service file**: `/etc/systemd/system/thepopebot.service`
- **Configuration**: `/etc/thepopebot/thepopebot.env`
- **Installation**: `/opt/thepopebot/`
- **Job logs**: `/opt/thepopebot/logs/`

## Default Settings

- **User**: `thepopebot` (non-root, no login)
- **Port**: `3000` (configurable in env file)
- **Auto-restart**: Yes (10s delay, max 5 attempts per 5 minutes)
- **Auto-start on boot**: Must enable with `systemctl enable thepopebot`

## Full Documentation

See [README.md](README.md) for complete documentation.
