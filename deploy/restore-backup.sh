#!/bin/bash
set -euo pipefail

# =============================================================================
# IqroKu Backup Restore Script
#
# This is intentionally destructive and requires explicit confirmation:
#   CONFIRM_RESTORE=YES ./deploy/restore-backup.sh /opt/iqroku/backups/iqroku_YYYYMMDD_HHMMSS.sql.gz
#
# Optional uploads restore:
#   CONFIRM_RESTORE=YES ./deploy/restore-backup.sh db.sql.gz uploads.tar.gz
# =============================================================================

APP_DIR="${APP_DIR:-/opt/iqroku}"
DB_NAME="${DB_NAME:-iqroku_db}"
DB_USER="${DB_USER:-iqroku}"
BACKUP_FILE="${1:-}"
UPLOADS_FILE="${2:-}"

if [ "${CONFIRM_RESTORE:-}" != "YES" ]; then
    echo "Refusing to restore without CONFIRM_RESTORE=YES"
    exit 1
fi

if [[ ! "$DB_NAME" =~ ^[a-zA-Z0-9_]+$ ]] || [[ ! "$DB_USER" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "DB_NAME and DB_USER must contain only letters, numbers, and underscores."
    exit 1
fi

if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
    echo "Usage: CONFIRM_RESTORE=YES $0 /path/to/iqroku_backup.sql.gz [uploads_backup.tar.gz]"
    exit 1
fi

gzip -t "$BACKUP_FILE"

echo "=== IqroKu Restore ==="
echo "Database: ${DB_NAME}"
echo "Backup:   ${BACKUP_FILE}"
echo ""

if command -v pm2 >/dev/null 2>&1; then
    pm2 stop iqroku || true
fi

sudo -u postgres psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${DB_NAME}' AND pid <> pg_backend_pid();"
sudo -u postgres dropdb --if-exists "$DB_NAME"
sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
gunzip -c "$BACKUP_FILE" | sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DB_NAME"

if [ -n "$UPLOADS_FILE" ]; then
    if [ ! -f "$UPLOADS_FILE" ]; then
        echo "Uploads backup not found: ${UPLOADS_FILE}"
        exit 1
    fi
    tar -tzf "$UPLOADS_FILE" >/dev/null
    if tar -tzf "$UPLOADS_FILE" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
        echo "Uploads archive contains unsafe paths."
        exit 1
    fi
    mkdir -p "$APP_DIR"
    tar --no-same-owner -xzf "$UPLOADS_FILE" -C "$APP_DIR"
fi

npm run migrate --prefix "${APP_DIR}/backend"

if command -v pm2 >/dev/null 2>&1; then
    pm2 restart iqroku --update-env
fi

echo ""
echo "Restore complete."
