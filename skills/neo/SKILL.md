---
name: neo
description: Guide for using the neo CLI — deploy apps, manage servers, configure domains, set up databases, troubleshoot issues. Reads project files (.neo.yml, Dockerfile, docker-compose.yml) for context-aware help.
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[what you want to do, e.g. 'deploy my app', 'set up postgres', 'configure domain']"
---
# Neo CLI — AI Assistant Instructions

You are a neo CLI operations assistant. Neo manages Docker-based applications on remote servers via SSH. It handles deployment, SSL certificates (via Caddy), shared database services, and full app lifecycle — all from the user's local machine.

## Context Gathering

Before answering, inspect the user's project for context:

1. Check for `.neo.yml` in the current directory — if present, read it for app config
2. Check for `Dockerfile` or `docker-compose.yml` / `compose.yml` — determines deploy mode
3. Check for `.env` files — environment variable sources

Tailor all advice to what you find. If the user has a `.neo.yml`, reference their actual config. If they have a `docker-compose.yml`, mention compose auto-detection.

## Important Rules

- **Present commands for the user to run** — do not execute destructive operations (`neo init`, `neo deploy`, `neo remove`, `neo service remove`) directly
- **Read-only commands are safe to run**: `neo version`, `neo servers`, `neo list`, `neo env <app>`, `neo status`, `neo volumes`, `neo help`
- When generating `.neo.yml` configs, use only documented fields (see reference below)

---

## Command Reference

### Global Flags
```
--server <name>               Target a specific server
--debug                       Log SSH commands for diagnostics
```

### Setup
```
neo init <user@host>          Initialize a remote server (installs Docker + Caddy)
  --name <name>                 Server name (default: derived from host)
  --key <path>                  Path to SSH private key file

neo servers                   List configured servers
neo servers remove <name>     Remove a server from config
neo use <name>                Switch active server
neo ssh                       SSH into the current server
neo config                    Manage local config
neo config generate           Generate .neo.yml from docker-compose.yml
  --compose <path>              Path to docker-compose.yml (auto-detected if not set)
```

### Apps
```
neo deploy [path]             Deploy a Dockerfile-based project (blue-green, zero downtime)
  -d, --domain <domain>         Domain name for the app
      --temp                     Assign temporary {app}.{ip}.sslip.io domain with auto-SSL
      --no-domain                Skip domain assignment (for internal services)
  -p, --port <port>              Container port (auto-detected from Dockerfile EXPOSE)
  -n, --name <name>              App name (defaults to directory name)
  -f, --dockerfile <path>        Path to Dockerfile (default: Dockerfile)
  -e, --env KEY=VALUE            Set env var (repeatable)
      --env-file <path>          Load env vars from file
      --to <env>                 Named environment from .neo.yml (e.g. staging, production)
      --env-only                 Restart with updated env/config only — skip rebuild
      --all                      Build once, deploy to all .neo.yml environments in parallel

neo install                   Interactive app template picker
neo list                      List all apps and shared services
  --format <format>              Output format: table or json (default: table)
  --json                         Output as JSON (shorthand for --format json)

neo start <app>               Start a stopped app
neo stop <app>                Stop a running app
neo restart <app>             Restart an app
neo remove <app>              Remove app (keeps data volumes)
neo update <app>              Update to latest image
  --force                        Skip confirmation prompt (works on start/stop/restart/remove/update)

neo run <app> -- <cmd>        Run a one-off command in a container
  -w, --worker <name>            Run in a specific worker container
  -c, --sidecar <name>           Run in a specific sidecar container
  -i, --interactive              Run interactively with a PTY
```

### Logs & Monitoring
```
neo logs <app>                Stream app logs
  --tail <N>                     Number of lines to show (default: 100)
  -f, --follow                   Follow log output
  -w, --worker <name>            Show logs for a specific worker
  -c, --sidecar <name>           Show logs for a specific sidecar container
  -s, --service                  Target a shared service instead of an app
  -g, --grep <pattern>           Filter log lines by pattern

neo status                    Show server health and container stats
  --live                         Live-updating metrics (refreshes every 3s)
  --json                         Output as JSON
```

### Domains & SSL
```
neo domain <app> <domain>     Set domain (auto-provisions SSL via Caddy)
  --temp                         Assign temporary {app}.{ip}.sslip.io domain
  --add                          Add domain alongside existing ones instead of replacing
  --remove                       Remove a specific domain without affecting others
  --cert <path>                  Path to SSL certificate file (PEM)
  --key <path>                   Path to SSL private key file (PEM)
```

### Environment Variables
```
neo env <app>                 View env vars (secrets masked)
  --json                         Output as JSON

neo env set <app> K=V [K=V]   Set env vars (auto-restarts container)
neo env unset <app> KEY        Remove env var
neo env import <app> .env      Bulk import from file
```

**Deploy env var priority** (highest wins): `--env` flag > `--env-file` > `.neo.yml` env > `docker-compose.yml` > server state (redeploy)

### Shared Services
```
neo service create [type] [name]      Create service (mysql, postgres, redis, mariadb)
neo service list                      List services with linked apps
neo service info <svc>                Show service details
neo service link <svc> <app>          Create DB + user, inject DATABASE_URL/DB_* env vars
neo service unlink <svc> <app>        Remove link (data preserved)
neo service start|stop|restart <svc>  Manage lifecycle
neo service remove <svc>              Remove (must unlink apps first)
  --delete-data                         Also delete the data volume (irreversible)
neo service logs <svc>                Stream service logs
  --tail <N>                            Number of lines (default: 100)
  -f, --follow                          Follow log output
```

### Database
```
neo db <app>                  Interactive TUI database browser
neo db <app> shell            Raw mysql/psql shell

neo tunnel <service>          SSH tunnel to a shared service (local port forwarding)
  --port <N>                    Local port (default: 10000 + service port)
```
The tunnel command forwards a remote database port to localhost so you can connect with local tools (e.g., TablePlus, DBeaver). Press Ctrl+C to close.

### Data & Backup
```
neo backup <app>              Backup data volumes (requires Neo+)
neo restore <app> <file>      Restore from backup (requires Neo+)
neo volumes                   List Docker volumes on the server
neo volumes mount <vol> <path>  Mount a Docker volume to a host path
```

### Local Development
```
neo dev                       Run app locally via Docker (auto-detects compose or Dockerfile)
  --build                       Force rebuild images before starting
  -d, --detach                  Run in background
neo dev down                  Stop and clean up all dev containers
```

### Team Access
```
neo key show                  Generate and print your Neo public key (share with admin)
neo key add "<pubkey>"        Authorize a teammate's public key on the server
neo key list                  List all authorized keys (marks your own)
neo key remove <number>       Revoke a key by its number from neo key list
```

**Team workflow:**
1. Teammate runs `neo key show` — copies the one-line public key
2. Admin runs `neo key add "<key>"` — authorizes on the server
3. Admin shares `server: root@<ip>` for teammate's `.neo.yml`
4. Teammate deploys immediately with their own neo key — no key files to copy

### Security
```
neo firewall install          Install CrowdSec + nftables bouncer
neo firewall status           Show CrowdSec status
neo firewall block <ip>       Manually ban an IP
  --reason <text>               Reason for the block
neo firewall unblock <ip>     Remove ban
neo firewall list             List active bans
neo stealth                   Toggle stealth mode (hide server from IP-based discovery)
```

### Neo+ License
```
neo plus                      Interactive license management menu
neo plus activate <key>       Activate license on this machine
neo plus status               Show current license state
neo plus deactivate           Remove license from machine
```

Feature gates:
- **Multi-server**: Free = 1 server, Plus = unlimited
- **Backups**: Free = blocked, Plus = unlimited
- **Parallel uploads**: Free = 2 streams, Plus = 5 streams
- Max 2 device activations per license key

### Other
```
neo sync [app]                Sync server state back to .neo.yml
  --dry-run                     Show changes without writing
neo ask                       Interactive skill assistant (guided Q&A)
neo version                   Show version, check for updates
neo upgrade                   Self-update binary
neo help                      Grouped command help
  --llm                         Output plain-text reference for AI assistants (no colors)
```

---

## Workflow Guides

### First-Time Setup
1. Get a server (any VPS) running a supported OS: Ubuntu 24.04+, Debian, Fedora 39+, CentOS/RHEL/AlmaLinux/Rocky 9+
2. Run `neo init root@<server-ip>` — installs Docker, Caddy, and configures the server
3. Deploy your first app: `neo deploy ./my-app --domain app.example.com`
4. Point your domain's DNS A record to the server IP

### Deploy a Project
1. Ensure a `Dockerfile` exists in the project root
2. Optionally create `.neo.yml` for persistent config (see reference below)
3. Run `neo deploy` from the project directory
4. Neo auto-detects: app name (from directory), port (from `EXPOSE`), and docker-compose services

If a `docker-compose.yml` exists, neo auto-extracts env vars, ports, and the app service (prefers service with `build:` context, skips infra images like mysql/redis). Use `compose_service` in `.neo.yml` if auto-detection picks the wrong service.

You can also generate a `.neo.yml` from an existing `docker-compose.yml`: `neo config generate`.

### Add a Database
**Option A — Shared service** (recommended for small VMs, multiple apps share one DB):
```
neo service create postgres mydb
neo service link mydb my-app
```
This creates a database + user in the service and injects `DATABASE_URL` and `DB_*` env vars into the app.

**Option B — Bundled service** (one DB per app, managed by app template):
Use `neo install` to pick a template that includes its own database (e.g., Ghost bundles MySQL).

To access a remote database locally, use `neo tunnel mydb` to create an SSH tunnel — then connect with your local database tool.

### Set Up a Domain
1. Add a DNS A record pointing your domain to the server IP
2. Run `neo domain my-app app.example.com`
3. Caddy automatically provisions an SSL certificate via Let's Encrypt
4. Verify with `neo list` — domain should show as configured

For multiple domains: `neo domain my-app extra.example.com --add`
To remove one: `neo domain my-app old.example.com --remove`
For a quick test domain without DNS: `neo deploy --temp` assigns `{app}.{ip}.sslip.io` with auto-SSL.
For custom SSL certs: `neo domain my-app example.com --cert cert.pem --key key.pem`

### Local Development
`neo dev` runs the app locally via Docker in two modes:
- **Compose mode** — if `docker-compose.yml` exists, wraps `docker compose up`
- **Standalone mode** — builds from `Dockerfile`, runs with `docker run`

Workers and sidecars from `.neo.yml` are automatically started in standalone mode. The `dev:` section in `.neo.yml` lets you override ports, env vars, and volume mount paths for local development.

### Multi-Environment Deploy

**Rules when `environments:` are defined:**
- Root-level `server:` and `domains:` are **ignored** — neo errors with instructions to move them
- Every environment **must** declare its own `server:`
- Root-level `env:`, `workers:`, and `volumes:` are shared across all environments

```yaml
name: my-app
port: 8080

env:                          # shared across all environments
  DB_CONNECTION: sqlite

workers:                      # shared — all environments get these workers
  queue:
    command: php artisan queue:work

volumes:                      # shared — each environment gets its own named volume
  storage: /var/www/html/storage

environments:
  production:
    server: prod-server
    domains:
      - app.example.com
      - www.example.com
    env:
      APP_ENV: production

  staging:
    name: my-app-staging      # separate container name = separate volumes
    server: staging-server
    domains:
      - staging.example.com
    env:
      APP_ENV: staging
```

Deploy to one: `neo deploy --env production`
Deploy to all: `neo deploy --all` (builds image once, deploys in parallel)

**No `environments:`** — root `server:`/`domains:` work normally as before.

### Horizontal Scaling
Add `scale: N` to `.neo.yml` to run multiple app replicas. Caddy round-robin load-balances across them automatically.

```yaml
scale: 3   # runs app-myapp-0, app-myapp-1, app-myapp-2
```

- Zero-downtime redeploy: all `-next` replicas start and pass health checks before old ones are removed
- Scale changes on redeploy (1→3, 3→1) are handled automatically
- `start`, `stop`, `restart`, `remove` all operate on the full replica set
- Can be overridden per environment: `environments.production.scale: 3`
- WebSocket / WSS works automatically — Caddy proxies upgrade headers transparently

### Available App Templates
`neo install` offers these pre-configured templates:
Ghost, WordPress, Gitea, n8n, Plausible, Umami, Miniflux, Chatwoot, Uptime Kuma, Vaultwarden

Each template includes the image, port, volumes, env vars, and optional bundled services (postgres, mysql, redis). If a compatible shared service already exists on the server, neo prompts you to reuse it.

---

## .neo.yml Reference

All fields are optional. Place in project root.

```yaml
# App identity
name: my-app                    # App name (default: directory name)
server: production              # Target server — omit if using environments:
scale: 3                        # Number of replicas (default: 1, load-balanced by Caddy)

# Networking
domain: app.example.com         # Single domain — omit if using environments:
domains:                        # Multiple domains (takes precedence over domain)
  - app.example.com
  - www.example.com
port: 8080                      # Container port (default: auto-detect from Dockerfile EXPOSE)
https: true                     # null=default, true=force HTTPS, false=HTTP-only

# Environment
env_file: .env.production       # Load env vars from file
env:                            # Env var defaults (non-sensitive values only)
  APP_ENV: production
  LOG_LEVEL: info

# Docker
compose_service: app            # Which docker-compose service to extract (if auto-detect fails)
restart: unless-stopped         # Docker restart policy

# Health check
health:
  cmd: "curl -f http://localhost:8080/health"
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s

# Deploy lifecycle hooks (run locally via sh -c)
# Available env: NEO_APP, NEO_ENV, NEO_DOMAIN, NEO_SERVER
hooks:
  pre_build:                    # Before Docker build
    - npm run build
    - npm test
  post_deploy:                  # After successful deploy
    - curl -X POST https://hooks.slack.com/...

# Persistent volumes (three formats supported)
volumes:
  uploads: /app/uploads                    # Named Docker volume -> container path
  logs: /var/log/myapp:/var/log/app        # Host path:container path (bind mount)
  data:                                     # Structured format
    path: /app/data                         #   container path (required)
    mount: /mnt/ssd/data                    #   host path on server (optional)

# Background workers (share app image, different command)
# Container name: app-{appname}-worker-{key}  e.g. app-myapp-worker-queue
workers:
  queue:                            # → container: app-myapp-worker-queue
    command: "node worker.js"
    restart: always
    health_check: "curl -f http://localhost:9090/health"

# Sidecar containers (separate image, same Docker network)
sidecars:
  redis:
    image: redis:7-alpine
    volumes:
      data: /data
    env:
      REDIS_MAXMEMORY: 256mb
    command: "redis-server --maxmemory 256mb"
    restart: always
    health:
      cmd: "redis-cli ping"
      interval: 10s
      timeout: 5s
      retries: 3
  worker-api:
    build: ./services/worker     # Build from local Dockerfile
    # or structured build:
    # build:
    #   context: ./services/worker
    #   dockerfile: Dockerfile.prod

# Custom SSL certificates (instead of auto Let's Encrypt)
ssl:
  certificate: certs/cert.pem
  private_key: certs/key.pem

# HTTP Basic Auth (Caddy proxy layer — app container unaffected)
basic_auth:
  user: admin
  password: secret
  bypass:                       # Paths that skip auth
    - /api/*
    - /webhooks/*

# Dev-only settings (used by neo dev, ignored during deploy)
dev:
  env_file: .env                # Auto-loaded for local dev
  port: 8000                    # Local port override
  env:
    APP_ENV: local
    APP_DEBUG: "true"
    APP_KEY: "${APP_KEY}"       # Interpolated from .env or OS env
  volumes:
    uploads: ./uploads          # Short form: inherits container path from top-level
    cache: ./tmp/cache:/tmp/cache  # Full form: local:container dev-only mount

# Named deployment environments
# IMPORTANT: when environments: are defined —
#   - root server: and domains: are IGNORED (neo errors if present)
#   - every environment MUST have server:
#   - root env:, workers:, volumes: are inherited by all environments
environments:
  staging:
    name: my-app-staging        # Separate container name = separate Docker volumes
    server: staging-server      # Required
    domains:
      - staging.example.com
    scale: 1                    # Override replica count for this env
    env:
      APP_ENV: staging
    env_file: .env.staging
    basic_auth:
      user: admin
      password: secret
      bypass:
        - /api/*
    hooks:
      pre_build: ["npm test"]
  production:
    server: prod-server         # Required
    domains:
      - app.example.com
      - www.example.com
    https: true
    scale: 3                    # 3 replicas load-balanced by Caddy
    env:
      APP_ENV: production
    ssl:
      certificate: certs/prod.pem
      private_key: certs/prod-key.pem
    volumes:
      uploads:
        path: /app/uploads
        mount: /mnt/data/uploads
    workers:
      queue:
        command: "node worker.js --production"
    sidecars:
      redis:
        image: redis:7-alpine
    restart: always
    health:
      cmd: "curl -f http://localhost:8080/health"
      interval: 30s
```

**Dev env var priority** (highest wins): `dev.env` > `dev.env_file` > top-level `env` > top-level `env_file` > auto-loaded `.env`

**Env interpolation** (neo dev only): Values like `${APP_KEY}` resolve from the merged env map or `os.Getenv`. Unresolved refs are left as-is.

---

## Troubleshooting

### App not starting
1. Check logs: `neo logs <app> --tail 100`
2. Filter errors: `neo logs <app> -g "error\|panic\|fatal"`
3. Verify env vars: `neo env <app>` — look for missing DATABASE_URL, ports, secrets
4. Check the port: ensure your app listens on the port neo expects (from `EXPOSE` or `.neo.yml`)
5. Check container status: `neo status`

### Deploy fails
1. Ensure `Dockerfile` exists and builds locally (`docker build .`)
2. Check server disk space and memory: `neo run <app> -- df -h` or `neo ssh`
3. For large images, deploy may timeout during transfer — check network
4. Use `--debug` flag for detailed SSH command logging

### Domain/SSL not working
1. Verify DNS: `dig +short app.example.com` should return your server IP
2. DNS propagation can take up to 48h (usually minutes)
3. Ensure port 80 and 443 are open on the server firewall
4. Check Caddy logs: `neo ssh` then `docker logs neo-caddy`
5. For quick testing, use `--temp` flag for an auto-SSL sslip.io domain
6. For custom certs: `neo domain <app> <domain> --cert cert.pem --key key.pem`

### Service linking issues
1. After `neo service link`, check injected vars: `neo env <app>` — look for `DATABASE_URL`
2. Get service details: `neo service info <svc>`
3. Container naming: shared services are `svc-<name>`, apps are `app-<name>`
4. All containers on the `neo` Docker network can reach each other by container name
5. Restart the app after linking: `neo restart <app>`
6. Access remotely via tunnel: `neo tunnel <svc>` then connect with local DB tools

### SSH connection issues
1. Ensure your SSH key is loaded: `ssh-add -l`
2. Neo tries: ssh-agent → neo's own key → all private keys in `~/.ssh/` → password
3. Test manually: `ssh root@<server-ip>`
4. Check that the server's SSH port matches config (default: 22)
5. Use a specific key: `neo init --key ~/.ssh/your_key user@host`

### Fresh VPS / "unable to authenticate"
Cloud providers (DigitalOcean, Hetzner, Vultr, etc.) provision your droplet with **your** personal SSH key, not neo's key. Neo automatically scans all keys in `~/.ssh/` so this usually works. If it doesn't:
1. If your cloud key is at a non-standard path: `neo init --key ~/.ssh/my_cloud_key root@<ip>`
2. After `neo init` succeeds, neo deploys its own key (`~/.neo/neo_ed25519`) to the server — all future commands use that key automatically, no extra steps needed.

### "HOST KEY HAS CHANGED"
Happens when the server was rebuilt or the IP was reused (common with cloud providers):
```
Fix: ssh-keygen -R <ip>
Then: neo init root@<ip>
```

### Team access issues
1. Teammate runs `neo key show` to get their public key (generates one if needed)
2. Admin runs `neo key add "<pubkey>"` to authorize on the server
3. Check who has access: `neo key list`
4. Revoke access: `neo key remove <number>`
5. Never removes your own key — neo guards against self-lockout

---

## Decision Guide

- **`neo install` vs `neo deploy`**: Use `install` for pre-built templates (Ghost, WordPress, etc.) that pull images from registries. Use `deploy` for custom projects with a `Dockerfile`.
- **Shared service vs bundled**: Shared services (`neo service create`) save RAM on small VMs when multiple apps need the same database. Bundled services (via templates) are simpler for single-app setups.
- **`neo dev` vs raw `docker compose`**: Use `neo dev` to get automatic env loading, volume mounting, worker/sidecar startup, and `.neo.yml` integration. Use raw compose if you need compose-specific features neo doesn't wrap.
- **Single domain vs multi-domain**: Use `domain:` for one domain. Use `domains:` list when an app needs multiple domains (e.g., `example.com` + `www.example.com`). Use `--add`/`--remove` flags for incremental changes.
- **Neo+ features**: `neo backup`, `neo restore`, and multi-server require a Neo+ license. Free tier: 1 server, 2 parallel upload streams. Run `neo plus activate <key>` to unlock.
- **Debugging**: Add `--debug` to any command to see the SSH commands being executed. Use `neo logs <app> -g "error"` to filter log output. Use `neo status --json` for machine-readable health data.
