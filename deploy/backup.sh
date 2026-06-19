#!/bin/bash
set -euo pipefail

# =============================================================================
# IqroKu Daily Backup Script
# Cron: 0 3 * * * /opt/iqroku/backup.sh
# =============================================================================

APP_DIR="${APP_DIR:-/opt/iqroku}"
BACKUP_DIR="${BACKUP_DIR:-${APP_DIR}/backups}"
DB_NAME="${DB_NAME:-iqroku_db}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/iqroku_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

# Dump and compress
sudo -u postgres pg_dump "$DB_NAME" | gzip > "$BACKUP_FILE"

# Also backup uploads
UPLOADS_BACKUP="${BACKUP_DIR}/uploads_${TIMESTAMP}.tar.gz"
if [ -d "${APP_DIR}/uploads" ] && [ "$(ls -A "${APP_DIR}/uploads" 2>/dev/null)" ]; then
    tar -czf "$UPLOADS_BACKUP" -C "$APP_DIR" uploads/
fi

# Remove old backups
find "$BACKUP_DIR" -name "iqroku_*.sql.gz" -mtime +${RETENTION_DAYS} -delete
find "$BACKUP_DIR" -name "uploads_*.tar.gz" -mtime +${RETENTION_DAYS} -delete

# Log
BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
gzip -t "$BACKUP_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup done: ${BACKUP_FILE} (${BACKUP_SIZE})"
