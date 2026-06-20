#!/bin/bash
set -euo pipefail

# =============================================================================
# IqroKu Operations Check
#
# Intended for cron/manual production checks. It validates the app process,
# health endpoint, migration status, backup freshness, disk usage, and common
# security-sensitive file/config permissions.
#
# Usage:
#   BASE_URL=https://iqroku.motionmind.store ./deploy/ops-check.sh
# =============================================================================

APP_DIR="${APP_DIR:-/opt/iqroku}"
BASE_URL="${BASE_URL:-http://localhost:8787}"
BACKUP_DIR="${BACKUP_DIR:-${APP_DIR}/backups}"
BACKUP_MAX_AGE_HOURS="${BACKUP_MAX_AGE_HOURS:-30}"
DISK_WARN_PERCENT="${DISK_WARN_PERCENT:-85}"
UPLOADS_WARN_MB="${UPLOADS_WARN_MB:-5120}"
BACKUPS_WARN_MB="${BACKUPS_WARN_MB:-10240}"
AUDIO_FILE_WARN_COUNT="${AUDIO_FILE_WARN_COUNT:-10000}"
CHECK_MIGRATIONS="${CHECK_MIGRATIONS:-true}"

FAILURES=0

section() {
    echo ""
    echo "[$1] $2"
}

pass() {
    echo "  OK  $1"
}

warn() {
    echo "  WARN $1"
}

fail() {
    echo "  FAIL $1"
    FAILURES=$((FAILURES + 1))
}

file_mode() {
    stat -c '%a' "$1" 2>/dev/null || echo ""
}

is_mode_private() {
    local mode="$1"
    [ -n "$mode" ] && [ "$mode" -le 600 ]
}

dir_size_mb() {
    local path="$1"
    if [ ! -d "$path" ]; then
        echo "0"
        return
    fi
    du -sm "$path" 2>/dev/null | awk '{print $1}'
}

echo "=== IqroKu Operations Check ==="
echo "Time:    $(date '+%Y-%m-%d %H:%M:%S')"
echo "App dir: ${APP_DIR}"
echo "Base:    ${BASE_URL}"

section 1 "Health endpoint"
if HEALTH_BODY="$(curl -fsS --connect-timeout 5 --max-time 15 "${BASE_URL}/health" 2>/dev/null)"; then
    echo "  ${HEALTH_BODY}"
    if echo "$HEALTH_BODY" | grep -q '"ok":true' && echo "$HEALTH_BODY" | grep -q '"store":"postgresql"'; then
        pass "backend and PostgreSQL health are OK"
    else
        fail "health endpoint returned unexpected body"
    fi
else
    fail "health endpoint is unreachable"
fi

section 2 "PM2 process"
if command -v pm2 >/dev/null 2>&1; then
    PM2_PID="$(pm2 pid iqroku 2>/dev/null | tail -n 1 | tr -d '[:space:]' || true)"
    if [ -n "$PM2_PID" ] && [ "$PM2_PID" != "0" ]; then
        pass "pm2 process iqroku is online with pid ${PM2_PID}"
    else
        fail "pm2 process iqroku is not online"
    fi
else
    fail "pm2 command is not installed"
fi

section 3 "Migration status"
if [ "$CHECK_MIGRATIONS" = "true" ]; then
    if [ -d "${APP_DIR}/backend" ]; then
        if npm run migrate:status --prefix "${APP_DIR}/backend"; then
            pass "migration status command passed"
        else
            fail "migration status command failed"
        fi
    else
        fail "backend directory not found at ${APP_DIR}/backend"
    fi
else
    warn "migration status check skipped"
fi

section 4 "Backups"
LATEST_DB_BACKUP="$(ls -1t "${BACKUP_DIR}"/iqroku_*.sql.gz 2>/dev/null | head -n 1 || true)"
if [ -z "$LATEST_DB_BACKUP" ]; then
    fail "no database backup found in ${BACKUP_DIR}"
else
    if gzip -t "$LATEST_DB_BACKUP"; then
        pass "latest database backup archive is valid: ${LATEST_DB_BACKUP}"
    else
        fail "latest database backup archive is corrupt: ${LATEST_DB_BACKUP}"
    fi

    NOW_TS="$(date +%s)"
    BACKUP_TS="$(stat -c '%Y' "$LATEST_DB_BACKUP")"
    AGE_HOURS=$(( (NOW_TS - BACKUP_TS) / 3600 ))
    if [ "$AGE_HOURS" -le "$BACKUP_MAX_AGE_HOURS" ]; then
        pass "latest database backup age is ${AGE_HOURS}h"
    else
        fail "latest database backup is stale: ${AGE_HOURS}h old"
    fi
fi

LATEST_UPLOADS_BACKUP="$(ls -1t "${BACKUP_DIR}"/uploads_*.tar.gz 2>/dev/null | head -n 1 || true)"
if [ -n "$LATEST_UPLOADS_BACKUP" ]; then
    if tar -tzf "$LATEST_UPLOADS_BACKUP" >/dev/null; then
        pass "latest uploads backup archive is valid: ${LATEST_UPLOADS_BACKUP}"
    else
        fail "latest uploads backup archive is corrupt: ${LATEST_UPLOADS_BACKUP}"
    fi
else
    warn "no uploads backup found; OK only if uploads directory is empty"
fi

section 5 "Disk usage"
if [ -d "$APP_DIR" ]; then
    DISK_PERCENT="$(df -P "$APP_DIR" | awk 'NR==2 {gsub("%", "", $5); print $5}')"
    if [ -n "$DISK_PERCENT" ] && [ "$DISK_PERCENT" -lt "$DISK_WARN_PERCENT" ]; then
        pass "disk usage ${DISK_PERCENT}% is below ${DISK_WARN_PERCENT}%"
    else
        fail "disk usage ${DISK_PERCENT}% is at or above ${DISK_WARN_PERCENT}%"
    fi
else
    fail "app directory not found: ${APP_DIR}"
fi

section 6 "IqroKu storage footprint"
UPLOADS_DIR="${APP_DIR}/uploads"
UPLOADS_MB="$(dir_size_mb "$UPLOADS_DIR")"
BACKUPS_MB="$(dir_size_mb "$BACKUP_DIR")"
AUDIO_COUNT="0"
if [ -d "${UPLOADS_DIR}/audio" ]; then
    AUDIO_COUNT="$(find "${UPLOADS_DIR}/audio" -type f 2>/dev/null | wc -l | tr -d '[:space:]')"
fi

echo "  uploads: ${UPLOADS_MB} MB (${UPLOADS_DIR})"
echo "  backups: ${BACKUPS_MB} MB (${BACKUP_DIR})"
echo "  audio files: ${AUDIO_COUNT}"

if [ "$UPLOADS_MB" -le "$UPLOADS_WARN_MB" ]; then
    pass "uploads size is below ${UPLOADS_WARN_MB} MB"
else
    warn "uploads size ${UPLOADS_MB} MB is above ${UPLOADS_WARN_MB} MB"
fi

if [ "$BACKUPS_MB" -le "$BACKUPS_WARN_MB" ]; then
    pass "backups size is below ${BACKUPS_WARN_MB} MB"
else
    warn "backups size ${BACKUPS_MB} MB is above ${BACKUPS_WARN_MB} MB"
fi

if [ "$AUDIO_COUNT" -le "$AUDIO_FILE_WARN_COUNT" ]; then
    pass "audio file count is below ${AUDIO_FILE_WARN_COUNT}"
else
    warn "audio file count ${AUDIO_COUNT} is above ${AUDIO_FILE_WARN_COUNT}"
fi

section 7 "Sensitive file permissions"
ENV_FILE="${APP_DIR}/backend/.env"
if [ -f "$ENV_FILE" ]; then
    ENV_MODE="$(file_mode "$ENV_FILE")"
    if is_mode_private "$ENV_MODE"; then
        pass "${ENV_FILE} permission is ${ENV_MODE}"
    else
        fail "${ENV_FILE} permission is ${ENV_MODE}; expected 600 or stricter"
    fi
else
    fail "env file not found: ${ENV_FILE}"
fi

FIREBASE_PATH=""
if [ -f "$ENV_FILE" ]; then
    FIREBASE_PATH="$(grep -E '^FIREBASE_SERVICE_ACCOUNT_PATH=' "$ENV_FILE" | tail -n 1 | cut -d= -f2- || true)"
fi
if [ -n "$FIREBASE_PATH" ]; then
    if [ -f "$FIREBASE_PATH" ]; then
        FIREBASE_MODE="$(file_mode "$FIREBASE_PATH")"
        if is_mode_private "$FIREBASE_MODE"; then
            pass "${FIREBASE_PATH} permission is ${FIREBASE_MODE}"
        else
            fail "${FIREBASE_PATH} permission is ${FIREBASE_MODE}; expected 600 or stricter"
        fi
    else
        fail "FIREBASE_SERVICE_ACCOUNT_PATH configured but file not found: ${FIREBASE_PATH}"
    fi
else
    warn "FIREBASE_SERVICE_ACCOUNT_PATH is not configured"
fi

section 8 "Nginx upload protection"
if command -v nginx >/dev/null 2>&1; then
    LIVE_NGINX_CONFIG="$(mktemp)"
    if nginx -T > "$LIVE_NGINX_CONFIG" 2>/dev/null \
        || { command -v sudo >/dev/null 2>&1 && sudo -n nginx -T > "$LIVE_NGINX_CONFIG" 2>/dev/null; }; then
        if grep -Eq 'location[[:space:]]+/uploads/' "$LIVE_NGINX_CONFIG" \
            && grep -Eq 'alias[[:space:]]+/opt/iqroku/uploads/' "$LIVE_NGINX_CONFIG"; then
            fail "live nginx serves /uploads/ with alias; this bypasses backend auth"
        else
            pass "live nginx does not expose /uploads/ through public alias"
        fi
    else
        fail "nginx -T failed; run as root or allow limited sudo: <user> ALL=(root) NOPASSWD: /usr/sbin/nginx -T"
    fi
    rm -f "$LIVE_NGINX_CONFIG"
else
    warn "nginx command is not installed"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "Operations check passed."
    exit 0
fi

echo "Operations check failed with ${FAILURES} issue(s)."
exit 1
