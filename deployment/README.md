# thepopebot Deployment Guide

This directory contains deployment configurations for running thepopebot in production environments.

## Available Deployment Methods

### systemd Service (Linux)

**Location**: `deployment/systemd/`

Run the Event Handler as a systemd service on Linux servers.

**Features**:
- Automatic startup on system boot
- Auto-restart on failure
- Non-root execution with security hardening
- Systemd journal logging
- Easy management with systemctl

**Quick Start**:
```bash
sudo deployment/systemd/install.sh
```

**Documentation**: See [systemd/README.md](systemd/README.md) or [systemd/QUICKSTART.md](systemd/QUICKSTART.md)

---

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Production Deployment                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────┐                                                 │
│  │   Internet     │                                                 │
│  └───────┬────────┘                                                 │
│          │                                                           │
│          ▼                                                           │
│  ┌────────────────────┐                                             │
│  │  Reverse Proxy     │  (nginx/Apache + HTTPS)                    │
│  │  - SSL/TLS         │                                             │
│  │  - Rate limiting   │                                             │
│  │  - Access logs     │                                             │
│  └────────┬───────────┘                                             │
│           │                                                          │
│           ▼                                                          │
│  ┌─────────────────────────────────────────┐                        │
│  │  systemd Service (thepopebot)          │                        │
│  │  ┌───────────────────────────────────┐  │                        │
│  │  │  Event Handler (Node.js)         │  │                        │
│  │  │  - Telegram webhooks             │  │                        │
│  │  │  - Generic webhooks              │  │                        │
│  │  │  - GitHub webhooks               │  │                        │
│  │  │  - Cron scheduler                │  │                        │
│  │  │  - Trigger middleware            │  │                        │
│  │  └───────────────────────────────────┘  │                        │
│  │                                         │                        │
│  │  User: thepopebot (non-root)          │                        │
│  │  Working Dir: /opt/thepopebot          │                        │
│  │  Logs: journalctl + /opt/thepopebot/logs│                      │
│  └─────────────────────────────────────────┘                        │
│                           │                                         │
│                           ▼                                         │
│  ┌─────────────────────────────────────────┐                        │
│  │  GitHub Actions                        │                        │
│  │  - run-job.yml (Docker agent)         │                        │
│  │  - auto-merge.yml (PR merge)          │                        │
│  │  - update-event-handler.yml (notify)  │                        │
│  └─────────────────────────────────────────┘                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Deployment Checklist

### Pre-deployment

- [ ] Server/VPS provisioned with Linux (Ubuntu 20.04+ recommended)
- [ ] Node.js 18+ installed
- [ ] Git installed
- [ ] Firewall configured (allow HTTP/HTTPS)
- [ ] DNS records configured
- [ ] SSL certificate obtained (Let's Encrypt recommended)

### Event Handler Setup

- [ ] Clone thepopebot repository
- [ ] Run `sudo deployment/systemd/install.sh`
- [ ] Configure `/etc/thepopebot/thepopebot.env` with:
  - [ ] `GH_TOKEN` (GitHub Personal Access Token)
  - [ ] `GH_OWNER` (GitHub username/org)
  - [ ] `GH_REPO` (Repository name)
  - [ ] `API_KEY` (Secure random string)
  - [ ] Optional: Telegram bot token
  - [ ] Optional: Claude API key
  - [ ] Optional: Webhook secrets
- [ ] Start service: `sudo systemctl start thepopebot`
- [ ] Enable auto-start: `sudo systemctl enable thepopebot`
- [ ] Verify status: `sudo systemctl status thepopebot`

### GitHub Configuration

- [ ] Set GitHub repository secrets:
  - [ ] `SECRETS` (Base64-encoded JSON with credentials)
  - [ ] `LLM_SECRETS` (Optional, for LLM-accessible credentials)
  - [ ] `GH_WEBHOOK_SECRET` (For update-event-handler.yml)
- [ ] Set GitHub repository variables:
  - [ ] `GH_WEBHOOK_URL` (Your server URL)
  - [ ] `AUTO_MERGE` (Set to `false` to disable, or leave unset)
  - [ ] `ALLOWED_PATHS` (Comma-separated paths, default: `/logs`)
  - [ ] `IMAGE_URL` (Optional, for custom Docker images)
  - [ ] `MODEL` (Optional, for custom Anthropic model)

### Reverse Proxy (nginx example)

- [ ] Install nginx: `sudo apt install nginx`
- [ ] Configure nginx (example below)
- [ ] Enable and start nginx
- [ ] Test configuration: `sudo nginx -t`
- [ ] Obtain SSL certificate: `sudo certbot --nginx`

**Example nginx configuration**:
```nginx
server {
    listen 80;
    server_name your-domain.com;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req zone=api burst=20 nodelay;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Access log
    access_log /var/log/nginx/thepopebot_access.log;
    error_log /var/log/nginx/thepopebot_error.log;
}
```

### Monitoring & Logging

- [ ] Set up log rotation for nginx
- [ ] Configure systemd journal retention
- [ ] Set up monitoring (optional):
  - [ ] Server monitoring (CPU, memory, disk)
  - [ ] Service health checks
  - [ ] Log aggregation
  - [ ] Alert on errors
- [ ] Test service restart: `sudo systemctl restart thepopebot`
- [ ] Test auto-restart: Kill the process and verify it restarts

### Security Hardening

- [ ] Firewall rules configured (only allow 22, 80, 443)
- [ ] SSH key authentication enabled
- [ ] SSH password authentication disabled
- [ ] Automatic security updates enabled
- [ ] Strong passwords/secrets for all services
- [ ] File permissions correct:
  - [ ] `/etc/thepopebot/thepopebot.env` is 600
  - [ ] `/opt/thepopebot` owned by thepopebot user
- [ ] SELinux/AppArmor configured (if applicable)
- [ ] Regular backups configured

### Testing

- [ ] Test webhook endpoint: `curl -X POST -H "x-api-key: YOUR_API_KEY" https://your-domain.com/webhook -d '{"job":"echo test"}'`
- [ ] Test Telegram bot (if configured)
- [ ] Create test job via GitHub Actions
- [ ] Verify PR auto-merge
- [ ] Check notification delivery
- [ ] Test service restart behavior
- [ ] Test health check: `sudo deployment/systemd/manage.sh health`

### Post-deployment

- [ ] Document your specific configuration
- [ ] Set up backup schedule for `/etc/thepopebot/`
- [ ] Set up monitoring alerts
- [ ] Test disaster recovery procedure
- [ ] Update DNS TTL to production values
- [ ] Remove test data/jobs
- [ ] Monitor logs for 24-48 hours

## Maintenance

### Regular Tasks

**Daily/Weekly**:
- Check service status: `sudo systemctl status thepopebot`
- Review logs for errors: `sudo journalctl -u thepopebot -p err --since "1 week ago"`
- Monitor disk space: `df -h /opt/thepopebot`

**Monthly**:
- Update system packages: `sudo apt update && sudo apt upgrade`
- Update thepopebot: `sudo deployment/systemd/manage.sh update`
- Review and rotate old job logs
- Check certificate expiration
- Review security logs

**Quarterly**:
- Review and rotate API keys
- Audit user access
- Test backup restoration
- Review and update firewall rules

### Updates

To update thepopebot:
```bash
sudo deployment/systemd/manage.sh update
```

This will:
1. Stop the service
2. Pull latest changes from git
3. Update dependencies
4. Reload configuration
5. Start the service

### Backups

**Critical files to backup**:
- `/etc/thepopebot/thepopebot.env` (contains credentials)
- `/opt/thepopebot/operating_system/` (configuration)
- `/opt/thepopebot/logs/` (job history)

**Example backup script**:
```bash
#!/bin/bash
BACKUP_DIR="/backups/thepopebot"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"
tar czf "$BACKUP_DIR/thepopebot_$DATE.tar.gz" \
    /etc/thepopebot/thepopebot.env \
    /opt/thepopebot/operating_system \
    /opt/thepopebot/logs

# Keep only last 30 days
find "$BACKUP_DIR" -name "thepopebot_*.tar.gz" -mtime +30 -delete
```

## Troubleshooting

See [systemd/README.md](systemd/README.md#troubleshooting) for detailed troubleshooting guide.

**Quick checks**:
```bash
# Service health
sudo deployment/systemd/manage.sh health

# Recent logs
sudo journalctl -u thepopebot -n 100

# Configuration validation
sudo deployment/systemd/manage.sh validate

# Test manually
sudo -u thepopebot bash
cd /opt/thepopebot
source /etc/thepopebot/thepopebot.env
node event_handler/server.js
```

## Support

- **systemd documentation**: [systemd/README.md](systemd/README.md)
- **Quick reference**: [systemd/QUICKSTART.md](systemd/QUICKSTART.md)
- **Project documentation**: [/job/CLAUDE.md](/job/CLAUDE.md)
- **Security guide**: [/job/SECURITY.md](/job/SECURITY.md)

## Future Deployment Methods

Planned deployment options:
- Docker Compose (for containerized deployment)
- Kubernetes manifests (for k8s clusters)
- Ansible playbook (for automated provisioning)
- Terraform modules (for infrastructure as code)

Contributions welcome!
