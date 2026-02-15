# 🚀 START HERE - thepopebot systemd Deployment

**Welcome!** This is your complete systemd deployment package for thepopebot.

---

## ⚡ Quick Start (3 Commands)

**For experienced users who want to deploy NOW:**

```bash
# 1. Backup (2 minutes)
./01-backup.sh

# 2. Deploy (5 minutes)
./04-deploy.sh

# 3. Verify (2 minutes)
./05-verify.sh
```

**Total time**: ~10 minutes  
**Done!** Your thepopebot is now a systemd service.

---

## 📚 For First-Time Users

**Start with the guide:**

1. **Read**: [README.md](README.md) - Overview and navigation
2. **Follow**: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Step-by-step instructions
3. **Execute**: Run the numbered scripts in order

**Expected time**: ~30 minutes including reading

---

## 📦 What's Included

### Scripts (Ready to Run)

| # | Script | What It Does | Time |
|---|--------|--------------|------|
| 1 | `01-backup.sh` | Creates complete backup | 2 min |
| 2 | `02-diagnostic.sh` | Checks if system is ready | 1 min |
| 3 | `03-stop-processes.sh` | Stops existing instances | 3 min |
| 4 | `04-deploy.sh` | Installs systemd service | 5 min |
| 5 | `05-verify.sh` | Tests deployment | 2 min |
| 6 | `06-rollback.sh` | Undoes deployment | 3 min |

### Documentation

| File | Purpose | When to Read |
|------|---------|--------------|
| **README.md** | Quick reference | Start here for overview |
| **DEPLOYMENT_GUIDE.md** | Complete manual | Before first deployment |
| **PROCESS_OVERVIEW.md** | Technical details | For understanding internals |
| **DEPLOYMENT_REPORT.md** | What was delivered | For project documentation |

---

## 🎯 Choose Your Path

### Path 1: Express (Experienced Users)

**If you know what you're doing:**

```bash
./01-backup.sh && ./04-deploy.sh && ./05-verify.sh
```

Skip diagnostic and stop-processes if you have a clean system.

### Path 2: Safe (Recommended)

**If you want to be careful:**

```bash
./01-backup.sh          # Safety first
./02-diagnostic.sh      # Check readiness
./03-stop-processes.sh  # Clean state
./04-deploy.sh          # Install
./05-verify.sh          # Validate
```

Follow prompts, read output, proceed step by step.

### Path 3: Learning (First Time)

**If you want to understand everything:**

1. Read **README.md** (5 min)
2. Read **DEPLOYMENT_GUIDE.md** (15 min)
3. Run `./02-diagnostic.sh` (1 min)
4. Read diagnostic output
5. Run remaining scripts one by one
6. Read **PROCESS_OVERVIEW.md** after deployment

---

## ⚠️ Important Notes

### Running Location

**You are in a Docker container.** These scripts must be run on your **HOST SYSTEM**.

**On your host**:
```bash
cd /path/to/thepopebot/logs/ffdee98b-d63e-4be0-b09d-3dd2c456fa2d/
./01-backup.sh
```

### Prerequisites

Before running scripts, ensure:
- [ ] Linux system with systemd
- [ ] Node.js 14+ installed
- [ ] sudo access available
- [ ] thepopebot repository cloned
- [ ] `.env` file configured

**Check these**:
```bash
systemctl --version    # systemd?
node --version         # Node.js?
sudo echo "test"       # sudo access?
```

### What Gets Deployed

- ✅ **Event Handler** → Runs as systemd service (managed by systemd)
- ❌ **Docker Agent** → Still runs via GitHub Actions (unchanged)

Only the Event Handler (the Node.js server) becomes a systemd service.

---

## 🔧 Common Scenarios

### Scenario 1: Clean System

**No thepopebot running:**

```bash
./01-backup.sh      # Quick backup
./02-diagnostic.sh  # Should be all green
./04-deploy.sh      # Skip stop-processes
./05-verify.sh
```

### Scenario 2: Manual Process Running

**Started with `node server.js`:**

```bash
./01-backup.sh
./02-diagnostic.sh       # Will show warnings
./03-stop-processes.sh   # Stops process
./04-deploy.sh
./05-verify.sh
```

### Scenario 3: PM2 Running

**Managed by PM2:**

```bash
./01-backup.sh
./03-stop-processes.sh   # Stops PM2
./04-deploy.sh
./05-verify.sh
```

### Scenario 4: Problems After Deploy

**Something went wrong:**

```bash
./06-rollback.sh         # Undo deployment
# Review logs
# Fix issue
# Try again
```

---

## 📖 Documentation Map

```
START_HERE.md (You are here!)
│
├─► README.md
│   ├─ Quick reference
│   ├─ Script descriptions
│   ├─ Usage scenarios
│   └─ Troubleshooting quick tips
│
├─► DEPLOYMENT_GUIDE.md
│   ├─ Detailed instructions
│   ├─ Step-by-step process
│   ├─ Troubleshooting guide
│   ├─ Maintenance procedures
│   └─ Daily operations
│
├─► PROCESS_OVERVIEW.md
│   ├─ Architecture details
│   ├─ Script implementation
│   ├─ Security features
│   ├─ Testing strategy
│   └─ Technical deep-dive
│
└─► DEPLOYMENT_REPORT.md
    ├─ What was delivered
    ├─ Testing performed
    ├─ Success metrics
    └─ Project documentation
```

**Start at top, dive deeper as needed.**

---

## ✅ Success Checklist

After deployment, verify these:

```bash
# 1. Service is active
systemctl is-active thepopebot
# Expected: "active"

# 2. Service is enabled
systemctl is-enabled thepopebot
# Expected: "enabled"

# 3. Process is running
ps aux | grep server.js
# Expected: One process running

# 4. Port is listening
lsof -i :3000
# Expected: node process on port 3000

# 5. Logs are flowing
sudo journalctl -u thepopebot -n 5
# Expected: Recent log entries

# 6. Tests pass
./05-verify.sh
# Expected: "ALL TESTS PASSED"
```

If all green ✅ → **Success!**

---

## 🆘 Quick Help

### Scripts Won't Run

```bash
# Make executable
chmod +x *.sh
```

### Service Won't Start

```bash
# Check why
systemctl status thepopebot
sudo journalctl -u thepopebot -n 50

# Test manually
cd ../../event_handler
node server.js
```

### Port Already in Use

```bash
# Find what's using it
lsof -i :3000

# Stop it
kill <PID>
```

### Need to Rollback

```bash
./06-rollback.sh
# Follow prompts
```

### More Help

- **Quick issues**: See [README.md](README.md) troubleshooting section
- **Detailed issues**: See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) troubleshooting section
- **Technical issues**: See [PROCESS_OVERVIEW.md](PROCESS_OVERVIEW.md)

---

## 🎓 What You'll Learn

By using this deployment package:

1. ✅ How to manage services with systemd
2. ✅ How to configure logging (journald + files)
3. ✅ How to set resource limits
4. ✅ How to secure services (non-root, filesystem protection)
5. ✅ How to test deployments comprehensively
6. ✅ How to rollback safely

**Bonus**: All scripts are heavily commented - read them to learn!

---

## 📊 What Happens During Deployment

```
Before:
  You: node server.js
  System: Hope it keeps running
  Crash: Manual restart
  Boot: Manual start
  Logs: Where did I save those?

After:
  You: systemctl start thepopebot
  System: Automatic management
  Crash: Auto-restart in 10s
  Boot: Auto-start
  Logs: journalctl -u thepopebot
```

**Professional operations. Zero effort.**

---

## 🎯 Your Next Steps

### Right Now

1. **Read** this file (✅ you're doing it!)
2. **Choose** your path above (Express/Safe/Learning)
3. **Execute** the scripts

### After Deployment

1. **Monitor** logs for 24 hours
2. **Test** all functionality (webhooks, Telegram, etc.)
3. **Document** any site-specific notes
4. **Celebrate** your new professional setup! 🎉

---

## 💡 Pro Tips

1. **Always backup first** - `01-backup.sh` is your safety net
2. **Read the output** - Scripts provide detailed feedback
3. **Don't skip verification** - `05-verify.sh` catches issues early
4. **Keep backups** - Don't delete them for at least a week
5. **Monitor logs** - First 24 hours are critical

---

## 🎁 Bonus: One-Liner Deployment

**For the brave and experienced:**

```bash
./01-backup.sh && ./02-diagnostic.sh && ./03-stop-processes.sh && ./04-deploy.sh && ./05-verify.sh
```

**Runs all scripts in sequence with prompts at each step.**

_(Not recommended for first deployment - better to understand each step)_

---

## 📞 Support

### If Something Goes Wrong

1. **Don't panic** - You have backups
2. **Check logs** - Scripts tell you where to look
3. **Run diagnostic** - `./02-diagnostic.sh` shows current state
4. **Review guide** - [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) has troubleshooting
5. **Rollback** - `./06-rollback.sh` if needed

### Resources

- **Logs**: `sudo journalctl -u thepopebot -f`
- **Status**: `systemctl status thepopebot`
- **Files**: `/var/log/thepopebot/`
- **Backups**: `../../backups/pre-systemd-*/`

---

## ✨ What Makes This Special

### Compared to Manual Setup

❌ **Manual Setup**:
- Edit service file by hand
- Copy paths carefully
- Hope you didn't typo
- Cross fingers
- Debug for hours

✅ **This Package**:
- Auto-detects everything
- Confirms before installing
- Tests everything
- Tells you what went wrong
- Deploy in minutes

### Compared to Other Tools

✅ **This package**:
- No dependencies (just bash + systemd)
- Comprehensive testing (50+ tests)
- Full backup/rollback
- Detailed documentation
- Security hardening included
- Production-ready

---

## 🏁 Ready to Start?

### For Express Path:
```bash
./01-backup.sh
```

### For Safe Path:
```bash
less README.md
```

### For Learning Path:
```bash
less DEPLOYMENT_GUIDE.md
```

---

**Good luck with your deployment!** 🚀

Remember: You can always rollback with `./06-rollback.sh` if needed.

---

**Generated by thepopebot Docker Agent**  
Job ID: `ffdee98b-d63e-4be0-b09d-3dd2c456fa2d`  
Date: 2026-02-15
