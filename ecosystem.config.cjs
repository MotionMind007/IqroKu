// PM2 Ecosystem Config for IqroKu Backend
// Secrets are NOT stored here. They are loaded from backend/.env (git-ignored).
// On the VPS, place the real values in /opt/iqroku/backend/.env

module.exports = {
  apps: [
    {
      name: 'iqroku',
      script: './backend/src/server.mjs',
      cwd: '/opt/iqroku',
      instances: 1,
      exec_mode: 'fork',
      // All secrets (DATABASE_URL, IQROKU_ADMIN_TOKEN, SESSION_SECRET,
      // MIMO_API_KEY, rate limits, etc.) live in this file:
      env_file: '/opt/iqroku/backend/.env',
      env: {
        NODE_ENV: 'production',
        PORT: 8787,
      },
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: '/var/log/iqroku/error.log',
      out_file: '/var/log/iqroku/out.log',
      merge_logs: true,
      max_restarts: 10,
      min_uptime: '10s',
      restart_delay: 3000,
      autorestart: true,
      max_memory_restart: '512M',
      kill_timeout: 5000,
      listen_timeout: 5000,
    },
  ],
};
