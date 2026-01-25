# Hindsight Auto-Update System Setup Guide

**Version:** 1.0.0
**Last Updated:** 2026-01-25
**Repository:** https://github.com/PakAbhishek/claude-code-config

---

## 🎯 Overview

Automated system that:
- ✅ Checks GitHub for Hindsight updates daily at 4 AM
- ✅ Starts container if stopped
- ✅ Applies updates automatically
- ✅ Runs comprehensive health tests
- ✅ Rolls back if tests fail
- ✅ Shuts down container after update (saves ~$130/month)

---

## 📋 Prerequisites

### GCP VM Requirements
- **VM:** hindsight-vm (n2-standard-4)
- **OS:** Container-Optimized OS (COS) or Ubuntu/Debian
- **Region:** us-south1-a
- **IP:** 34.174.13.163 (static)

### Software Requirements
- Docker
- curl
- jq (JSON processor)
- git

---

## 🚀 Installation

### Step 1: SSH into GCP VM

```bash
# From your local machine
gcloud compute ssh hindsight-vm \
  --zone=us-south1-a \
  --project=hindsight-prod-9802
```

### Step 2: Install Dependencies

```bash
# For Container-Optimized OS
toolbox
apt-get update
apt-get install -y jq git curl

# For Ubuntu/Debian (if not using COS)
sudo apt-get update
sudo apt-get install -y docker.io jq git curl
```

### Step 3: Download Update Script

```bash
# Create directory
sudo mkdir -p /opt/hindsight/scripts
cd /opt/hindsight/scripts

# Download from GitHub
sudo curl -o hindsight-auto-update.sh \
  https://raw.githubusercontent.com/PakAbhishek/claude-code-config/main/_scripts/hindsight-auto-update.sh

# Make executable
sudo chmod +x hindsight-auto-update.sh
```

**Or manually upload:**
```bash
# From local machine
gcloud compute scp \
  hindsight-auto-update.sh \
  hindsight-vm:/tmp/ \
  --zone=us-south1-a

# On VM
sudo mv /tmp/hindsight-auto-update.sh /opt/hindsight/scripts/
sudo chmod +x /opt/hindsight/scripts/hindsight-auto-update.sh
```

### Step 4: Configure Script

Edit configuration variables if needed:

```bash
sudo nano /opt/hindsight/scripts/hindsight-auto-update.sh
```

**Key Configuration Options:**
```bash
# Shutdown after update (set to false to keep running)
SHUTDOWN_AFTER_UPDATE=true

# Container name
CONTAINER_NAME="hindsight-server"

# GitHub repository
GITHUB_REPO="https://github.com/vectorize-io/hindsight"

# Hindsight endpoints
CONTROL_PLANE_URL="http://localhost:9999"
MCP_API_URL="http://localhost:8888"
BANK_NAME="claude-code"
```

### Step 5: Create Cron Job

```bash
# Edit root crontab
sudo crontab -e

# Add this line (runs daily at 4 AM)
0 4 * * * /opt/hindsight/scripts/hindsight-auto-update.sh run >> /var/log/hindsight/cron.log 2>&1
```

**Cron Schedule Options:**
```bash
# Daily at 4 AM
0 4 * * * /opt/hindsight/scripts/hindsight-auto-update.sh run

# Every 6 hours
0 */6 * * * /opt/hindsight/scripts/hindsight-auto-update.sh run

# Weekly on Sunday at 3 AM
0 3 * * 0 /opt/hindsight/scripts/hindsight-auto-update.sh run

# Every other day at 2 AM
0 2 */2 * * /opt/hindsight/scripts/hindsight-auto-update.sh run
```

### Step 6: Create Log Directory

```bash
# Create log directory
sudo mkdir -p /var/log/hindsight
sudo mkdir -p /var/backups/hindsight

# Set permissions
sudo chown -R root:root /var/log/hindsight
sudo chown -R root:root /var/backups/hindsight
```

### Step 7: Test the Setup

```bash
# Test dependencies
/opt/hindsight/scripts/hindsight-auto-update.sh test

# Test container start
/opt/hindsight/scripts/hindsight-auto-update.sh start

# Check status
/opt/hindsight/scripts/hindsight-auto-update.sh status

# Manual run (don't wait for cron)
sudo /opt/hindsight/scripts/hindsight-auto-update.sh run
```

---

## 📊 How It Works

### Update Workflow

```
┌─────────────────────────────────────────────┐
│ 1. Cron triggers at 4 AM                    │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│ 2. Check GitHub for new commits             │
│    GET https://api.github.com/repos/...     │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
         ┌────────────────────┐
         │  Update available? │
         └─────┬──────────┬───┘
               │ No       │ Yes
               │          │
               ▼          ▼
    ┌──────────────┐  ┌─────────────────────────┐
    │ Shutdown &   │  │ 3. Backup current state │
    │ exit         │  └──────────┬──────────────┘
    └──────────────┘             │
                                 ▼
                   ┌─────────────────────────────┐
                   │ 4. Start container if down  │
                   └──────────┬──────────────────┘
                              │
                              ▼
                   ┌─────────────────────────────┐
                   │ 5. Pull latest Docker image │
                   │    docker pull vectorize/...│
                   └──────────┬──────────────────┘
                              │
                              ▼
                   ┌─────────────────────────────┐
                   │ 6. Restart with new version │
                   └──────────┬──────────────────┘
                              │
                              ▼
                   ┌─────────────────────────────┐
                   │ 7. Run health tests:        │
                   │    • Control Plane API      │
                   │    • MCP Server API         │
                   │    • Memory bank access     │
                   │    • Recall operation       │
                   │    • Docker logs check      │
                   └──────┬──────────────┬───────┘
                          │ Pass         │ Fail
                          │              │
                          ▼              ▼
              ┌────────────────┐  ┌──────────────┐
              │ 8a. Success    │  │ 8b. Rollback │
              │     Shutdown   │  │     Restore  │
              │     container  │  │     backup   │
              └────────────────┘  └──────────────┘
```

### Cost Savings Logic

**Without Auto-Shutdown:**
- VM running 24/7: **$130/month**
- Always available but costly

**With Auto-Shutdown:**
- VM up only during updates: **~$10/month**
- Savings: **~$120/month** (~92% reduction)

**Trade-off:**
- Auto-capture hook will fail when container is down
- Manual start required for queries: `docker start hindsight-server`
- Or keep running with `SHUTDOWN_AFTER_UPDATE=false`

---

## 🧪 Testing

### Manual Test Run

```bash
# Full update cycle (dry run)
sudo /opt/hindsight/scripts/hindsight-auto-update.sh run

# Just test health checks
sudo /opt/hindsight/scripts/hindsight-auto-update.sh test

# Check container status
sudo /opt/hindsight/scripts/hindsight-auto-update.sh status
```

### Verify Cron Job

```bash
# List cron jobs
sudo crontab -l

# Check cron logs
tail -f /var/log/hindsight/cron.log

# Check main logs
tail -f /var/log/hindsight/auto-update.log

# Check last run
grep "Auto-Update Started" /var/log/hindsight/auto-update.log | tail -5
```

### Test Rollback

```bash
# Simulate failure by breaking health check
sudo docker stop hindsight-server

# Run update (should detect failure and rollback)
sudo /opt/hindsight/scripts/hindsight-auto-update.sh run

# Check logs
tail -50 /var/log/hindsight/auto-update.log
```

---

## 📁 File Locations

| File | Path | Purpose |
|------|------|---------|
| **Update script** | `/opt/hindsight/scripts/hindsight-auto-update.sh` | Main automation script |
| **Update logs** | `/var/log/hindsight/auto-update.log` | Detailed execution logs |
| **Cron logs** | `/var/log/hindsight/cron.log` | Cron job output |
| **State file** | `/var/log/hindsight/last-update-commit.txt` | Last applied GitHub commit |
| **Backups** | `/var/backups/hindsight/` | Container backups (7 retained) |
| **Hindsight repo** | `/opt/hindsight/` | Local clone of GitHub repo |

---

## 🚨 Monitoring

### Check Update History

```bash
# Last 10 updates
grep "Update completed successfully" /var/log/hindsight/auto-update.log | tail -10

# Failed updates
grep "TESTS FAILED\|Rolling back" /var/log/hindsight/auto-update.log

# Current commit
cat /var/log/hindsight/last-update-commit.txt
```

### Cloud Logging (if enabled)

```bash
# View logs in GCP Console
gcloud logging read "resource.type=gce_instance AND logName=projects/hindsight-prod-9802/logs/hindsight-updates" \
  --limit 50 \
  --format json
```

### Alerting Setup (Optional)

Create alerting policy in GCP:

1. Go to **Monitoring > Alerting**
2. Create condition: `Log match: "TESTS FAILED"`
3. Notification channel: Email or Slack
4. Alert name: "Hindsight Update Failed"

---

## 🔧 Troubleshooting

### Update Never Runs

**Check cron is enabled:**
```bash
sudo systemctl status cron
sudo systemctl enable cron
sudo systemctl start cron
```

**Verify crontab:**
```bash
sudo crontab -l
```

**Test script manually:**
```bash
sudo /opt/hindsight/scripts/hindsight-auto-update.sh run
```

### Update Fails

**Check logs:**
```bash
tail -100 /var/log/hindsight/auto-update.log
```

**Common issues:**
1. **Missing dependencies** - Install jq, git, curl
2. **Docker not running** - `sudo systemctl start docker`
3. **Network issues** - Check firewall, internet access
4. **GitHub rate limit** - Wait or use GitHub token

**Manual recovery:**
```bash
# Restore latest backup
cd /var/backups/hindsight
ls -lt hindsight-backup-*.tar.gz | head -1

# Restore (replace with actual backup file)
sudo docker stop hindsight-server
sudo docker run --rm \
  -v hindsight_data:/target \
  -v /var/backups/hindsight:/backup \
  alpine tar xzf /backup/hindsight-backup-YYYYMMDD-HHMMSS.tar.gz -C /target
sudo docker start hindsight-server
```

### Tests Fail But System is Healthy

**Adjust test timeouts:**
```bash
sudo nano /opt/hindsight/scripts/hindsight-auto-update.sh

# Increase these values
MAX_STARTUP_WAIT=180  # Was 120
TEST_TIMEOUT=60       # Was 30
```

**Disable specific tests:**
```bash
# In run_comprehensive_tests() function, comment out:
# "test_recall_operation"  # If recall is slow
```

### Container Won't Start

**Check Docker logs:**
```bash
sudo docker logs hindsight-server --tail 100
```

**Check Docker service:**
```bash
sudo systemctl status docker
sudo docker ps -a
```

**Manual start:**
```bash
sudo /opt/hindsight/scripts/hindsight-auto-update.sh start
```

---

## 🔄 Maintenance

### Change Update Schedule

```bash
sudo crontab -e

# Examples:
0 2 * * * /opt/...   # 2 AM daily
0 4 * * 0 /opt/...   # 4 AM Sundays only
0 0 1 * * /opt/...   # Monthly on 1st
```

### Keep Container Running

```bash
# Edit script
sudo nano /opt/hindsight/scripts/hindsight-auto-update.sh

# Change to:
SHUTDOWN_AFTER_UPDATE=false
```

### Clean Old Logs

```bash
# Rotate logs (run monthly)
cd /var/log/hindsight
sudo gzip auto-update.log.2024*
sudo find . -name "*.gz" -mtime +90 -delete
```

### Clean Old Backups

```bash
# Keep last 7, delete older
cd /var/backups/hindsight
sudo ls -t hindsight-backup-*.tar.gz | tail -n +8 | xargs -r rm
```

---

## 📊 Cost Analysis

### Scenario 1: Always Running (Current)
- **Compute:** $130/month
- **Availability:** 100%
- **Auto-capture:** Always works

### Scenario 2: Auto-Shutdown (Recommended)
- **Compute:** ~$10/month
- **Availability:** On-demand (manual start)
- **Auto-capture:** Fails when down (degrades gracefully)
- **Savings:** $120/month (92%)

### Scenario 3: Scheduled Uptime
- **Compute:** ~$40/month (8 hours/day)
- **Availability:** Business hours only
- **Auto-capture:** Works during business hours
- **Savings:** $90/month (69%)

**Cron for Scenario 3:**
```bash
# Start at 8 AM
0 8 * * * docker start hindsight-server

# Shutdown at 6 PM
0 18 * * * docker stop hindsight-server

# Update at 4 AM (will start, update, shutdown)
0 4 * * * /opt/hindsight/scripts/hindsight-auto-update.sh run
```

---

## 🎯 Next Steps

1. **Verify installation:**
   ```bash
   sudo /opt/hindsight/scripts/hindsight-auto-update.sh test
   ```

2. **Wait for first scheduled run:**
   - Next run: Tomorrow at 4 AM
   - Check logs: `/var/log/hindsight/auto-update.log`

3. **Set up monitoring:**
   - GCP logging (optional)
   - Email alerts (optional)
   - Slack notifications (optional)

4. **Document recovery procedures:**
   - Keep backup script accessible
   - Note manual start commands
   - Document GitHub repo access

---

## 📚 References

- **Hindsight GitHub:** https://github.com/vectorize-io/hindsight
- **GCP VM:** http://34.174.13.163:9999
- **This Repo:** https://github.com/PakAbhishek/claude-code-config
- **Cron Tutorial:** https://crontab.guru

---

## 👥 Support

- **Author:** Abhishek Chauhan (achau)
- **Organization:** PakEnergy
- **GCP Project:** hindsight-prod-9802

**For issues:**
1. Check logs: `/var/log/hindsight/auto-update.log`
2. Test manually: `sudo /opt/.../hindsight-auto-update.sh test`
3. Review this guide
4. Contact DevOps team

---

**Version:** 1.0.0
**Last Updated:** 2026-01-25
**Status:** Ready for Production
