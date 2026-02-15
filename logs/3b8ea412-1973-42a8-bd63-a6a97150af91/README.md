# thepopebot Process Audit & systemd Migration Kit

This directory contains a comprehensive audit of your thepopebot system and everything you need to migrate to a systemd service.

## 📋 Deliverables

| File | Purpose |
|------|---------|
| **PROCESS_AUDIT_REPORT.md** | Complete audit report with detailed instructions |
| **quick-check.sh** | Fast diagnostic script to check current state |
| **stop-processes.sh** | Interactive script to safely stop existing processes |
| **thepopebot.service.template** | systemd service file ready to customize |
| **README.md** | This file |

## 🚀 Quick Start

### Step 1: Check Current State

On your **HOST system** (not in Docker), run:

```bash
cd /path/to/thepopebot/logs/3b8ea412-1973-42a8-bd63-a6a97150af91/
./quick-check.sh
```

This will show you:
- Running Node.js processes
- Port 3000 usage
- Screen sessions
- PM2 processes
- systemd service status

### Step 2: Stop Existing Processes

If you have processes running, stop them safely:

```bash
./stop-processes.sh
```

This interactive script will:
- Ask before stopping each process
- Use graceful shutdown (SIGTERM) first
- Offer force kill (SIGKILL) if needed
- Verify port 3000 is freed
- Confirm system is clean

### Step 3: Set Up systemd Service

1. **Customize the service file:**
   ```bash
   nano thepopebot.service.template
   ```
   
   Replace these placeholders:
   - `YOUR_USERNAME` → Your Linux username (run `whoami`)
   - `/FULL/PATH/TO/thepopebot` → Absolute path to repo
   - `/FULL/PATH/TO/node` → Node.js path (run `which node`)

2. **Create log directory:**
   ```bash
   sudo mkdir -p /var/log/thepopebot
   sudo chown YOUR_USERNAME:YOUR_USERNAME /var/log/thepopebot
   ```

3. **Install service file:**
   ```bash
   sudo cp thepopebot.service.template /etc/systemd/system/thepopebot.service
   sudo systemctl daemon-reload
   ```

4. **Start and test:**
   ```bash
   sudo systemctl start thepopebot
   systemctl status thepopebot
   sudo journalctl -u thepopebot -f
   ```

5. **Enable auto-start** (after testing):
   ```bash
   sudo systemctl enable thepopebot
   ```

## 📖 Documentation

For detailed information, troubleshooting, and advanced configuration, see:

**[PROCESS_AUDIT_REPORT.md](PROCESS_AUDIT_REPORT.md)**

This comprehensive guide covers:
- Understanding the thepopebot architecture
- All diagnostic commands with examples
- Multiple methods for stopping processes
- Complete systemd setup instructions
- Common issues and solutions
- Daily operations and maintenance
- Migration checklist

## ⚠️ Important Notes

### This is the Docker Agent Container

You're reading this from **inside the Docker Agent container** that executed this job. All the commands and scripts must be run on your **HOST SYSTEM** where the Event Handler runs, not here.

### System Architecture

```
┌─────────────────────────────────────────┐
│          Your HOST System               │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │   Event Handler (Node.js)       │   │  ← This is what runs as systemd service
│  │   - Telegram bot                │   │
│  │   - Webhook receiver             │   │
│  │   - Cron scheduler               │   │
│  │   - Job creator                  │   │
│  └─────────────┬───────────────────┘   │
│                │                        │
│                │ Creates job branches   │
│                ↓                        │
│  ┌─────────────────────────────────┐   │
│  │   GitHub Actions                │   │
│  │   - Runs Docker container       │   │
│  └─────────────┬───────────────────┘   │
└────────────────┼────────────────────────┘
                 │
                 ↓
      ┌──────────────────────┐
      │  Docker Container    │  ← You are here (reading this)
      │  - Pi agent          │
      │  - Chrome browser    │
      │  - Git operations    │
      └──────────────────────┘
```

### What Gets Managed by systemd?

Only the **Event Handler** (the Node.js server on your host) runs as a systemd service. The Docker Agent containers are ephemeral - they spin up for each job via GitHub Actions and shut down when complete.

## 🔍 Troubleshooting

### Quick Check Shows Processes Running

Run `./stop-processes.sh` to safely stop them.

### Scripts Not Executable

```bash
chmod +x quick-check.sh stop-processes.sh
```

### Permission Denied

Make sure you're running on the HOST system with appropriate permissions. Some commands require `sudo`.

### systemd Service Won't Start

1. Check logs: `sudo journalctl -u thepopebot -n 50`
2. Verify paths in service file are correct
3. Test manual start: `cd event_handler && node server.js`
4. See troubleshooting section in PROCESS_AUDIT_REPORT.md

## 📞 Support

For issues or questions about:
- **This audit/migration**: See PROCESS_AUDIT_REPORT.md
- **thepopebot in general**: Check the main repository documentation
- **systemd basics**: `man systemd.service`

## 📜 Generated By

- **Job ID:** 3b8ea412-1973-42a8-bd63-a6a97150af91
- **Timestamp:** 2026-02-15T18:25:05Z
- **Agent:** thepopebot Docker Agent
- **Branch:** job/3b8ea412-1973-42a8-bd63-a6a97150af91

---

**Ready to migrate?** Start with `./quick-check.sh` to see your current state!
