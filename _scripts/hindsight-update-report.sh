#!/bin/bash
################################################################################
# Hindsight Update History Report
#
# Displays update history, current version, and backup status
#
# Usage: bash hindsight-update-report.sh
################################################################################

echo "=================================================="
echo "Hindsight Update History Report"
echo "=================================================="
echo ""

LOG_FILE="/mnt/stateful_partition/hindsight/logs/auto-update.log"
STATE_FILE="/mnt/stateful_partition/hindsight/logs/last-update-commit.txt"
BACKUP_DIR="/mnt/stateful_partition/hindsight/backups"

echo "📍 Current Version:"
if [ -f "$STATE_FILE" ]; then
    COMMIT=$(cat "$STATE_FILE")
    echo "   Commit: ${COMMIT:0:12}"
    echo "   Full SHA: $COMMIT"
    echo "   GitHub: https://github.com/vectorize-io/hindsight/commit/${COMMIT:0:12}"
else
    echo "   Not yet tracked (first update pending)"
fi

echo ""
echo "✅ Successful Updates (Last 10):"
grep "Update completed successfully" "$LOG_FILE" 2>/dev/null | tail -10 || echo "   No updates yet"

echo ""
echo "❌ Failed Updates:"
grep "Rolling back update" "$LOG_FILE" 2>/dev/null | tail -10 || echo "   None (all updates successful)"

echo ""
echo "💾 Backups Available:"
if [ -d "$BACKUP_DIR" ]; then
    ls -lh "$BACKUP_DIR" 2>/dev/null | tail -8 || echo "   No backups yet"
else
    echo "   No backups yet"
fi

echo ""
echo "📊 Update Statistics:"
TOTAL_RUNS=$(grep -c "Auto-Update Started" "$LOG_FILE" 2>/dev/null || echo "0")
SUCCESSFUL=$(grep -c "Update completed successfully" "$LOG_FILE" 2>/dev/null || echo "0")
FAILED=$(grep -c "Rolling back" "$LOG_FILE" 2>/dev/null || echo "0")
NO_UPDATES=$(grep -c "No updates needed" "$LOG_FILE" 2>/dev/null || echo "0")

echo "   Total runs: $TOTAL_RUNS"
echo "   Successful updates: $SUCCESSFUL"
echo "   Failed updates: $FAILED"
echo "   No update needed: $NO_UPDATES"

if [ "$TOTAL_RUNS" -gt 0 ]; then
    SUCCESS_RATE=$((SUCCESSFUL * 100 / TOTAL_RUNS))
    echo "   Success rate: ${SUCCESS_RATE}%"
fi

echo ""
echo "⏰ Next Scheduled Update:"
systemctl list-timers hindsight-update.timer --no-pager 2>/dev/null | grep hindsight | awk '{print "   "$1, $2, $3}' || echo "   Timer not configured"

echo ""
echo "🔍 Recent Activity (Last 20 lines):"
tail -20 "$LOG_FILE" 2>/dev/null || echo "   No log entries yet"

echo ""
echo "=================================================="
