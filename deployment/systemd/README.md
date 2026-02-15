# thepopebot Systemd Service

This directory contains systemd service configuration for running the thepopebot Event Handler as a system service.

## Overview

The systemd service provides:
- **Automatic startup** on system boot
- **Auto-restart** on failure with backoff policy
- **Isolated execution** with a dedicated service user
- **Security hardening** with systemd security features
- **Structured logging** via systemd journal
- **Resource management** with configurable limits

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      System Boot / Manual Start                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   systemd (thepopebot.service)                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Service Configuration:                                   │  │
│  │  - User: thepopebot (non-root)                           │  │
│  │  - Working Directory: /opt/thepopebot                    │  │
│  │  - Environment: /etc/thepopebot/thepopebot.env          │  │
│  │  - Auto-restart: Always (10s delay, 5 attempts/5min)    │  │
│  │  - Security: NoNewPrivileges, ProtectSystem, etc.       │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Event Handler (Node.js)                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  event_handler/server.js                                 │  │
│  │  - Telegram bot webhooks                                 │  │
│  │  - Generic job webhooks                                  │  │
│  │  - GitHub webhooks                                       │  │
│  │  - Cron jobs (CRONS.json)                               │  │
│  │  - Webhook triggers (TRIGGERS.json)                     │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Output                                 │
│  - Logs: journalctl -u thepopebot                              │
│  - Job files: /opt/thepopebot/logs/                           │
│  - Working dirs: /opt/thepopebot/event_handler/{cron,triggers}│
└─────────────────────────────────────────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `thepopebot.service` | systemd unit file |
| `thepopebot.env.example` | Environment configuration template |
| `install.sh` | Installation script |
| `uninstall.sh` | Uninstallation script |
| `manage.sh` | Management utility |
| `README.md` | This documentation |

## Quick Start

### Installation

1. **Clone your thepopebot repository** (or navigate to it):
   ```bash
   git clone https://github.com/yourusername/thepopebot.git
   cd thepopebot
   ```

2. **Run the installation script**:
   ```bash
   sudo deployment/systemd/install.sh
   ```

3. **Edit the configuration file**:
   ```bash
   sudo nano /etc/thepopebot/thepopebot.env
   ```
   
   Required variables:
   - `GH_TOKEN` - GitHub Personal Access Token
   - `GH_OWNER` - GitHub username/organization
   - `GH_REPO` - Repository name
   - `API_KEY` - Secure random string for webhook authentication

4. **Start the service**:
   ```bash
   sudo systemctl start thepopebot
   ```

5. **Check status**:
   ```bash
   sudo systemctl status thepopebot
   ```

### Using the Management Script

The `manage.sh` script provides convenient commands:

```bash
# Make it executable
sudo chmod +x /opt/thepopebot/deployment/systemd/manage.sh

# Start service
sudo ./deployment/systemd/manage.sh start

# Stop service
sudo ./deployment/systemd/manage.sh stop

# Restart service
sudo ./deployment/systemd/manage.sh restart

# View live logs
sudo ./deployment/systemd/manage.sh logs

# Check health
sudo ./deployment/systemd/manage.sh health

# Edit configuration
sudo ./deployment/systemd/manage.sh config

# Update from git
sudo ./deployment/systemd/manage.sh update
```

## Installation Details

### What Gets Installed

The installation script:
1. Checks prerequisites (Node.js 18+, npm, git)
2. Creates system user `thepopebot` (no login, no home directory)
3. Creates directories:
   - `/opt/thepopebot` - Installation directory
   - `/etc/thepopebot` - Configuration directory
   - `/var/log/thepopebot` - Log directory (if needed)
4. Installs/clones the thepopebot repository
5. Installs Node.js dependencies
6. Copies and configures systemd service
7. Sets proper permissions and ownership

### Directory Structure

```
/opt/thepopebot/           # Installation directory (owned by thepopebot:thepopebot)
├── event_handler/         # Event handler code
├── operating_system/      # Operating system files (SOUL.md, CRONS.json, etc.)
├── logs/                  # Job logs (writable by thepopebot user)
├── deployment/            # Deployment configurations
└── node_modules/          # Dependencies

/etc/thepopebot/           # Configuration directory (owned by root)
└── thepopebot.env         # Environment variables (600 permissions)

/var/log/thepopebot/       # Additional logs if needed (owned by thepopebot)
```

## Configuration

### Environment Variables

Edit `/etc/thepopebot/thepopebot.env` to configure the service.

#### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GH_TOKEN` | GitHub Personal Access Token | `ghp_xxxxxxxxxxxx` |
| `GH_OWNER` | GitHub repository owner | `myusername` |
| `GH_REPO` | GitHub repository name | `thepopebot` |
| `API_KEY` | Webhook authentication key | `your_secure_random_key` |

#### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | HTTP server port | `3000` |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | — |
| `TELEGRAM_WEBHOOK_SECRET` | Telegram webhook validation | — |
| `GH_WEBHOOK_SECRET` | GitHub webhook validation | — |
| `ANTHROPIC_API_KEY` | Claude API key for chat | — |
| `EVENT_HANDLER_MODEL` | Claude model ID | `claude-sonnet-4` |

### Security Notes

- The environment file is owned by `root:root` with `600` permissions
- The service runs as the `thepopebot` user (no sudo/root access)
- Secrets are never logged or exposed
- systemd security features enabled (see Service Security below)

## Service Management

### systemctl Commands

```bash
# Start service
sudo systemctl start thepopebot

# Stop service
sudo systemctl stop thepopebot

# Restart service
sudo systemctl restart thepopebot

# Check status
sudo systemctl status thepopebot

# Enable auto-start on boot
sudo systemctl enable thepopebot

# Disable auto-start
sudo systemctl disable thepopebot

# View service configuration
systemctl cat thepopebot
```

### Viewing Logs

```bash
# Live tail (follow)
sudo journalctl -u thepopebot -f

# Recent logs
sudo journalctl -u thepopebot -n 100

# Logs since boot
sudo journalctl -u thepopebot -b

# Logs for specific time range
sudo journalctl -u thepopebot --since "2024-01-01" --until "2024-01-02"

# Errors only
sudo journalctl -u thepopebot -p err

# Export logs
sudo journalctl -u thepopebot --since today > thepopebot.log
```

### Service Health Check

The `manage.sh health` command checks:
- Service active status
- Service enabled status
- Uptime
- Port listening status
- Recent error count

```bash
sudo /opt/thepopebot/deployment/systemd/manage.sh health
```

## Service Security

The systemd service includes comprehensive security hardening:

### Isolation Features

| Feature | Purpose |
|---------|---------|
| `User=thepopebot` | Runs as non-root user |
| `NoNewPrivileges=true` | Cannot gain additional privileges |
| `PrivateTmp=true` | Isolated /tmp directory |
| `ProtectSystem=strict` | Read-only filesystem (except explicit paths) |
| `ProtectHome=true` | No access to user home directories |
| `ReadWritePaths=...` | Only logs and working dirs are writable |

### Kernel Protection

| Feature | Purpose |
|---------|---------|
| `ProtectKernelTunables=true` | Cannot modify kernel parameters |
| `ProtectKernelModules=true` | Cannot load kernel modules |
| `ProtectControlGroups=true` | Cannot modify cgroups |

### Execution Protection

| Feature | Purpose |
|---------|---------|
| `RestrictRealtime=true` | No real-time scheduling |
| `RestrictNamespaces=true` | Cannot create namespaces |
| `LockPersonality=true` | Cannot change execution domain |
| `RestrictAddressFamilies=...` | Only AF_UNIX, AF_INET, AF_INET6 |

### Resource Limits

| Limit | Value | Purpose |
|-------|-------|---------|
| `LimitNOFILE` | 65536 | Max open files |
| `TasksMax` | 4096 | Max processes/threads |

## Auto-Restart Policy

The service automatically restarts on failure:

```
Restart=always              # Restart on any exit
RestartSec=10              # Wait 10 seconds between restarts
StartLimitBurst=5          # Allow 5 restart attempts
StartLimitInterval=300     # Within 5 minutes
```

If the service fails 5 times within 5 minutes, systemd stops trying and marks the service as failed.

## Updating the Service

### Update from Git

If installed from a git repository:

```bash
sudo /opt/thepopebot/deployment/systemd/manage.sh update
```

This will:
1. Stop the service
2. Pull latest changes from git
3. Update dependencies
4. Reload systemd configuration
5. Start the service

### Manual Update

```bash
# Stop service
sudo systemctl stop thepopebot

# Update files
cd /opt/thepopebot
sudo -u thepopebot git pull
sudo -u thepopebot npm install --production

# Update systemd service file if changed
sudo cp deployment/systemd/thepopebot.service /etc/systemd/system/
sudo systemctl daemon-reload

# Start service
sudo systemctl start thepopebot
```

## Troubleshooting

### Service Won't Start

1. **Check configuration**:
   ```bash
   sudo /opt/thepopebot/deployment/systemd/manage.sh validate
   ```

2. **Check logs**:
   ```bash
   sudo journalctl -u thepopebot -n 50
   ```

3. **Verify environment file**:
   ```bash
   sudo cat /etc/thepopebot/thepopebot.env
   # Ensure all required variables are set
   ```

4. **Test manually**:
   ```bash
   sudo -u thepopebot bash
   cd /opt/thepopebot
   source /etc/thepopebot/thepopebot.env
   node event_handler/server.js
   ```

### Service Keeps Restarting

1. **Check recent errors**:
   ```bash
   sudo journalctl -u thepopebot -p err --since "1 hour ago"
   ```

2. **Check disk space**:
   ```bash
   df -h /opt/thepopebot
   ```

3. **Check permissions**:
   ```bash
   ls -la /opt/thepopebot/logs
   ls -la /opt/thepopebot/event_handler/cron
   ```

### Port Already in Use

1. **Find what's using the port**:
   ```bash
   sudo netstat -tulpn | grep :3000
   ```

2. **Change port**:
   ```bash
   sudo nano /etc/thepopebot/thepopebot.env
   # Change PORT=3000 to another port
   sudo systemctl restart thepopebot
   ```

### Permission Issues

All job files and logs should be readable by the service user:

```bash
# Fix ownership
sudo chown -R thepopebot:thepopebot /opt/thepopebot/logs
sudo chown -R thepopebot:thepopebot /opt/thepopebot/event_handler/cron
sudo chown -R thepopebot:thepopebot /opt/thepopebot/event_handler/triggers
```

## Uninstallation

To completely remove the service:

```bash
sudo /opt/thepopebot/deployment/systemd/uninstall.sh
```

This will:
1. Stop and disable the service
2. Remove the service file
3. Remove the installation directory
4. Optionally remove logs, configuration, and user account

The uninstall script preserves the configuration directory by default (contains credentials).

## Advanced Configuration

### Custom Working Directory

To install in a different directory, edit `install.sh` before running:

```bash
INSTALL_DIR="/your/custom/path"
```

### Running on Different Port

Edit `/etc/thepopebot/thepopebot.env`:

```bash
PORT=8080
```

Then restart:

```bash
sudo systemctl restart thepopebot
```

### Multiple Instances

To run multiple instances:

1. Copy and rename the service file
2. Change the service name, working directory, and config file
3. Use different ports in each config file

```bash
# Example for second instance
sudo cp /etc/systemd/system/thepopebot.service /etc/systemd/system/thepopebot-dev.service
sudo nano /etc/systemd/system/thepopebot-dev.service
# Change WorkingDirectory and EnvironmentFile
sudo systemctl daemon-reload
sudo systemctl start thepopebot-dev
```

### Systemd Journal Retention

Configure journal retention in `/etc/systemd/journald.conf`:

```ini
[Journal]
SystemMaxUse=500M
MaxRetentionSec=1month
```

Then restart journald:

```bash
sudo systemctl restart systemd-journald
```

## Integration with GitHub Actions

The Event Handler receives notifications from GitHub Actions via the `/github/webhook` endpoint. This is configured in the repository's `.github/workflows/update-event-handler.yml` workflow.

### Required GitHub Configuration

Set these in your repository:

1. **Repository Secret**: `GH_WEBHOOK_SECRET`
   ```bash
   # Generate a secure secret
   openssl rand -hex 32
   ```

2. **Repository Variable**: `GH_WEBHOOK_URL`
   ```
   https://your-server.com
   ```

The workflow will append `/github/webhook` automatically.

## Production Deployment Checklist

- [ ] Install on a dedicated server or VPS
- [ ] Configure firewall to allow HTTP traffic on configured port
- [ ] Set up reverse proxy (nginx/Apache) with HTTPS
- [ ] Configure proper DNS records
- [ ] Set strong random values for `API_KEY` and webhook secrets
- [ ] Enable automatic security updates on the host
- [ ] Set up monitoring and alerting
- [ ] Configure log rotation
- [ ] Test service restart behavior
- [ ] Document your specific configuration
- [ ] Set up backups of `/etc/thepopebot/` directory

## Support

For issues and questions:
- Check troubleshooting section above
- Review logs: `sudo journalctl -u thepopebot -n 100`
- See main project documentation: `/job/CLAUDE.md`
- Check project issues on GitHub

## License

Same as thepopebot project.
