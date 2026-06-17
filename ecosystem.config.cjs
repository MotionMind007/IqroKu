module.exports = {
  "apps": [
    {
      "name": "iqroku",
      "script": "./backend/src/server.mjs",
      "cwd": "/opt/iqroku",
      "instances": 1,
      "exec_mode": "fork",
      "env": {
        "NODE_ENV": "production",
        "PORT": 8787,
        "DATABASE_URL": "postgresql://iqroku:713ed9663811c30c94307457de2fa89c@localhost:5432/iqroku_db",
        "IQROKU_ADMIN_TOKEN": "193a19dcb6e650c3b8dd748fa765c084bc177442b802d415e02bf843f295da5b",
        "SESSION_SECRET": "366952b2d5e8f4a1c9b7e3d6f2a8c5b4e1d9f7a3c6b8e2d4f5a7c9b1e3d5f7a",
        "MAX_BODY_SIZE": 5242880,
        "RATE_WINDOW_MS": 60000,
        "RATE_MAX_AUTH": 10,
        "RATE_MAX_GENERAL": 120,
        "MIMO_API_URL": "https://api.xiaomimimo.com/v1",
        "MIMO_API_KEY": "sk-s89n1ks2x2177y0env5zy89jpkochk4uy9bvbpr58x74s08z",
        "MIMO_ASR_MODEL": "mimo-v2.5-asr",
        "MIMO_PRO_MODEL": "mimo-v2.5-pro"
      },
      "log_date_format": "YYYY-MM-DD HH:mm:ss Z",
      "error_file": "/var/log/iqroku/error.log",
      "out_file": "/var/log/iqroku/out.log",
      "merge_logs": true,
      "max_restarts": 10,
      "min_uptime": "10s",
      "restart_delay": 3000,
      "autorestart": true,
      "max_memory_restart": "512M",
      "kill_timeout": 5000,
      "listen_timeout": 5000
    }
  ]
};
