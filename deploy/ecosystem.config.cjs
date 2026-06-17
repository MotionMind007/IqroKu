// PM2 Ecosystem Config for IqroKu Backend
// Place at: /opt/iqroku/ecosystem.config.cjs

module.exports = {
  apps: [
    {
      name: 'iqroku',
      script: './backend/src/server.mjs',
      cwd: '/opt/iqroku',
      instances: 1,
      exec_mode: 'fork',
      env_file: '/opt/iqroku/backend/.env',
      env: {
        NODE_ENV: 'production',
        PORT: 8787,
      },
      // Logging
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: '/var/log/iqroku/error.log',
      out_file: '/var/log/iqroku/out.log',
      merge_logs: true,
      log_type: 'json',
      // Restart policy
      max_restarts: 10,
      min_uptime: '10s',
      restart_delay: 3000,
      autorestart: true,
      // Memory guard
      max_memory_restart: '512M',
      // Graceful shutdown
      kill_timeout: 5000,
      listen_timeout: 5000,
      shutdown_with_message: true,
    },
  ],
};
