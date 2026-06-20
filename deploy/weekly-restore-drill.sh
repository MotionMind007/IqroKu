#!/bin/bash
set -euo pipefail

# =============================================================================
# IqroKu Weekly Restore Drill
#
# Finds the newest database backup and newest uploads archive, then runs the
# non-destructive restore drill against a temporary database.
#
# Cron example:
#   30 4 * * 0 /opt/iqroku/weekly-restore-drill.sh >> /var/log/iqroku/restore-drill.log 2>&1
# =============================================================================

APP_DIR="${APP_DIR:-/opt/iqroku}"
BACKUP_DIR="${BACKUP_DIR:-${APP_DIR}/backups}"
RESTORE_DRILL_SCRIPT="${RESTORE_DRILL_SCRIPT:-${APP_DIR}/deploy/restore-drill.sh}"
REQUIRE_UPLOADS_BACKUP="${REQUIRE_UPLOADS_BACKUP:-false}"

echo "=== IqroKu Weekly Restore Drill ==="
echo "Time:    $(date '+%Y-%m-%d %H:%M:%S')"
echo "App dir: ${APP_DIR}"
echo "Backups: ${BACKUP_DIR}"
echo ""

if [ ! -x "$RESTORE_DRILL_SCRIPT" ]; then
    echo "Restore drill script is not executable: ${RESTORE_DRILL_SCRIPT}"
    exit 1
fi

LATEST_DB_BACKUP="$(ls -1t "${BACKUP_DIR}"/iqroku_*.sql.gz 2>/dev/null | head -n 1 || true)"
if [ -z "$LATEST_DB_BACKUP" ]; then
    echo "No database backup found in ${BACKUP_DIR}"
    exit 1
fi

LATEST_UPLOADS_BACKUP="$(ls -1t "${BACKUP_DIR}"/uploads_*.tar.gz 2>/dev/null | head -n 1 || true)"
if [ -z "$LATEST_UPLOADS_BACKUP" ] && [ "$REQUIRE_UPLOADS_BACKUP" = "true" ]; then
    echo "No uploads backup found in ${BACKUP_DIR}"
    exit 1
fi

echo "Database backup: ${LATEST_DB_BACKUP}"
if [ -n "$LATEST_UPLOADS_BACKUP" ]; then
    echo "Uploads backup:  ${LATEST_UPLOADS_BACKUP}"
else
    echo "Uploads backup:  none"
fi
echo ""

if [ -n "$LATEST_UPLOADS_BACKUP" ]; then
    "$RESTORE_DRILL_SCRIPT" "$LATEST_DB_BACKUP" "$LATEST_UPLOADS_BACKUP"
else
    "$RESTORE_DRILL_SCRIPT" "$LATEST_DB_BACKUP"
fi

echo ""
echo "Weekly restore drill passed."
