#!/bin/bash
set -euo pipefail

# =============================================================================
# IqroKu Non-Destructive Restore Drill
#
# Restores a backup into a temporary database, runs migrations/status checks
# against that temporary database, then drops it again.
#
# Usage:
#   ./deploy/restore-drill.sh /opt/iqroku/backups/iqroku_YYYYMMDD_HHMMSS.sql.gz [uploads_backup.tar.gz]
# =============================================================================

APP_DIR="${APP_DIR:-/opt/iqroku}"
DB_USER="${DB_USER:-iqroku}"
BACKUP_FILE="${1:-}"
UPLOADS_FILE="${2:-}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DRILL_DB_NAME="${DRILL_DB_NAME:-iqroku_restore_drill_${TIMESTAMP}}"
KEEP_RESTORE_DRILL_DB="${KEEP_RESTORE_DRILL_DB:-}"

if [[ ! "$DRILL_DB_NAME" =~ ^[a-zA-Z0-9_]+$ ]] || [[ ! "$DB_USER" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "DRILL_DB_NAME and DB_USER must contain only letters, numbers, and underscores."
    exit 1
fi

if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
    echo "Usage: $0 /path/to/iqroku_backup.sql.gz [uploads_backup.tar.gz]"
    exit 1
fi

cleanup() {
    if [ "$KEEP_RESTORE_DRILL_DB" = "YES" ]; then
        echo "Keeping drill database: ${DRILL_DB_NAME}"
        return
    fi
    sudo -u postgres dropdb --if-exists "$DRILL_DB_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

drill_database_url() {
    if [ -n "${DRILL_DATABASE_URL:-}" ]; then
        echo "$DRILL_DATABASE_URL"
        return
    fi

    local base_url=""
    if [ -f "${APP_DIR}/backend/.env" ]; then
        base_url="$(grep -E '^DATABASE_URL=' "${APP_DIR}/backend/.env" | tail -n 1 | cut -d= -f2- || true)"
    fi

    if [ -z "$base_url" ]; then
        echo "postgresql://${DB_USER}@localhost:5432/${DRILL_DB_NAME}"
        return
    fi

    local prefix="$base_url"
    local suffix=""
    if [[ "$base_url" == *\?* ]]; then
        prefix="${base_url%%\?*}"
        suffix="?${base_url#*\?}"
    fi
    echo "${prefix%/*}/${DRILL_DB_NAME}${suffix}"
}

echo "=== IqroKu Restore Drill ==="
echo "Backup:        ${BACKUP_FILE}"
echo "Drill DB:      ${DRILL_DB_NAME}"
echo "App dir:       ${APP_DIR}"
echo ""

echo "[1/6] Verifying database backup archive..."
gzip -t "$BACKUP_FILE"

if [ -n "$UPLOADS_FILE" ]; then
    echo "[2/6] Verifying uploads backup archive..."
    if [ ! -f "$UPLOADS_FILE" ]; then
        echo "Uploads backup not found: ${UPLOADS_FILE}"
        exit 1
    fi
    tar -tzf "$UPLOADS_FILE" >/dev/null
    if tar -tzf "$UPLOADS_FILE" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
        echo "Uploads archive contains unsafe paths."
        exit 1
    fi
else
    echo "[2/6] No uploads archive supplied; skipping uploads archive check."
fi

echo "[3/6] Creating temporary drill database..."
sudo -u postgres dropdb --if-exists "$DRILL_DB_NAME" >/dev/null 2>&1 || true
sudo -u postgres createdb -O "$DB_USER" "$DRILL_DB_NAME"

echo "[4/6] Restoring database backup into drill database..."
gunzip -c "$BACKUP_FILE" | sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DRILL_DB_NAME" >/dev/null

echo "[5/6] Running migrations against drill database..."
DRILL_URL="$(drill_database_url)"
DATABASE_URL="$DRILL_URL" npm run migrate --prefix "${APP_DIR}/backend"
DATABASE_URL="$DRILL_URL" npm run migrate:status --prefix "${APP_DIR}/backend"

echo "[6/6] Checking restored schema basics..."
sudo -u postgres psql -d "$DRILL_DB_NAME" -v ON_ERROR_STOP=1 -c \
    "SELECT COUNT(*) AS migration_count FROM schema_migrations;" >/dev/null
sudo -u postgres psql -d "$DRILL_DB_NAME" -v ON_ERROR_STOP=1 -c \
    "SELECT COUNT(*) AS parent_count FROM parents;" >/dev/null

echo ""
echo "Restore drill passed. Production database was not modified."
