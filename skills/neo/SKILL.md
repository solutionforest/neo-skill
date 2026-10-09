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

- **Present commands for the user to run** — do not execute destructive operations (`neo init`, `neo deploy`, `neo remove`, `neo service remove`, `neo destroy`) directly
- **Read-only commands are safe to run**: `neo version`, `neo servers`, `neo list`, `neo env <app>`, `neo status`, `neo status <app>`, `neo deploys <app>`, `neo volumes`, `neo help`
- When generating `.neo.yml` configs, use only documented fields (see reference below)
- **Message brokers and databases (RabbitMQ, Postgres, MySQL, Redis with persistence) are never sidecars.** Every deploy recreates every sidecar. Give them their own `.neo.yml` with `strategy: recreate`, or use `neo service create`. See "Stateful Apps" below
- **Neo is free but requires a free license.** The first command prompts for an email and issues a key instantly (or run `neo activate`). In CI / no-TTY it prints a "run `neo activate`" message instead. Set `NEO_DEV_PLUS=true` to bypass in local dev.

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

neo attach <user@host>        Register an already-initialized server (no Docker/Caddy
                                install, never overwrites remote state — safe on a live server)
  --name <name>                 Server name (default: derived from host)

neo destroy [server]          Tear down a server (removes everything neo installed)
                                Level 1: remove neo, keep data volumes + Docker
                                Level 2 (full wipe): also prune data, uninstall CrowdSec + Docker
                                Requires typing the host to confirm; removes it from local config

neo servers                   List configured servers
neo servers remove <name>     Remove a server from config
neo use <name>                Switch active server
neo ssh                       SSH into the current server
neo config                    Manage local config
neo config init               Scaffold a commented .neo.yml (no docker-compose.yml needed)
  --yes                         Accept defaults non-interactively
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
      --parallel N               Max concurrent deploys with --all (default: 3; use 1 for small servers)

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

neo status <app>              Full detail for ONE app: which build is deployed, the
                              commit it came from, who deployed it, domains, containers
  --json                         Output as JSON

neo deploys <app>             Deployment history: what shipped, when, from whose machine
  --json                         Output as JSON
```

**Deployment versions.** Every deploy records the git commit it was built from, so
"which code is running?" is answerable. `neo list` gains a VERSION column
(`v1.4.2 (a1b2c3d)`, or `a1b2c3d *` when built from a dirty tree), the image tag
becomes `neo-<app>:<timestamp>-<shortsha>`, and the container gets these variables:

```
NEO_DEPLOYMENT_ID     20260818-045536-a1b2c3d
NEO_GIT_COMMIT        full sha
NEO_GIT_SHORT_COMMIT  a1b2c3d
NEO_GIT_BRANCH        main
NEO_GIT_TAG           v1.4.2      (only when the commit is tagged)
NEO_DEPLOYED_AT       RFC3339
```

They are injected BEFORE `.neo.yml` interpolation, so a project can wire them into
anything without neo knowing the tool: `SENTRY_RELEASE: "${NEO_GIT_COMMIT}"`. An
explicitly set value always wins.

Every deploy that builds an image writes the commit it just built (since v0.26.12).
`neo deploy --env-only` keeps the previous values, because it restarts the same image.
Before v0.26.12 a redeploy kept the first deploy's values, and the workaround was
`neo env unset <app> NEO_GIT_COMMIT NEO_GIT_SHORT_COMMIT NEO_GIT_BRANCH NEO_GIT_TAG
NEO_DEPLOYMENT_ID NEO_DEPLOYED_AT`. Don't suggest it on v0.26.12+: `neo upgrade` and
redeploy instead.

Git is not required — a scaffolded project shows no version, and CI shallow checkouts
fall back to `NEO_GIT_COMMIT` / `GITHUB_SHA` / `CI_COMMIT_SHA`. History is stored
server-side (`/etc/neo/deploys/<app>.jsonl`), so it is shared by every machine that
deploys and survives a fresh clone; entries whose image has been pruned are marked and
cannot be restored from the image alone.

### Domains & SSL
```
neo domain <app> <domain>     Set domain (auto-provisions SSL via Caddy)
  --temp                         Assign temporary {app}.{ip}.sslip.io domain
  --add                          Add domain alongside existing ones instead of replacing
  --remove                       Remove a specific domain without affecting others
  --cert <path>                  Path to SSL certificate file (PEM)
  --key <path>                   Path to SSL private key file (PEM)
  --https                        Switch the existing route to HTTPS at the origin
  --http-only                    Switch the existing route to HTTP only at the origin
  --cloudflare-flexible          HTTP origin for Cloudflare Flexible SSL; forwards the
                                   HTTPS scheme to the app (X-Forwarded-Proto: https)

neo caddy update               Pull the latest caddy:2-alpine and recreate neo-caddy
neo caddy routes               Show the routes Caddy is actually serving (incl. auth state)
neo caddy reload               Rebuild every route from server state (drift repair)
  --app <name>                   Rebuild one app's route only
                                 (routes + TLS certs preserved; rebuilds a custom DNS
                                 build from its stored Dockerfile with a fresh base layer)

neo caddy dns <domain>         Wildcard HTTPS via ACME DNS-01 (free wildcard cert)
  --provider <name>              DNS provider (default: cloudflare)
  --token-env <var>              Local env var holding the DNS API token
                                   (default: provider-specific, e.g. CLOUDFLARE_API_TOKEN)
  --app <app>                    Bind the wildcard *.domain to an app after setup

neo caddy ondemand <domain>    Guarded on-demand wildcard TLS for dynamic subdomains
  --app <app>                    App to bind the wildcard to (auto-derives the ask URL)
  --ask-url <url>                URL Caddy calls to allow/deny cert issuance (required if no --app)
  --replace-domains              Replace the app's extra domains with the wildcard

neo redirect add <from> <to>   Redirect a domain to another URL (auto-SSL on source domain)
  --temporary                    Use 302 redirect (default: 301 permanent)
neo redirect list               Show all configured redirects
neo redirect remove <domain>    Remove a redirect
```

### Environment Variables
```
neo env <app>                 View env vars (secrets masked)
  --json                         Output as JSON

neo env set <app> K=V [K=V]   Set env vars (auto-restarts container)
neo env unset <app> KEY        Remove env var
neo env import <app> .env      Bulk import from file

neo env encrypt [file]         Encrypt .env -> .env.encrypted (commit it; key printed once)
  --key <key>                    Use an existing key instead of generating one
  --force                        Overwrite an existing encrypted file
  --prune                        Delete the plaintext file after encrypting

neo env decrypt [file]         Decrypt an encrypted env file
  --stdout                       Print instead of writing a file

neo env key set <app> [key]    Save the encryption key for an app
neo env key list               List saved keys (masked)
neo env key forget <app>       Remove a saved key
```

**Deploy env var priority** (highest wins): `--env` flag > `--env-file` > `.neo.yml` env > `.neo.yml` env_file > `.neo.yml` env_encrypted > `docker-compose.yml` > server state (redeploy)

**Encrypted env files are Laravel's format.** A file from `php artisan env:encrypt` works
as-is; `neo env encrypt` output is readable by `php artisan env:decrypt`. Point
`env_encrypted:` at it in `.neo.yml` and deploy decrypts it in memory. Key lookup order:
`--env-key` > `NEO_ENV_KEY` > `LARAVEL_ENV_ENCRYPTION_KEY` > `~/.neo/keys.json` > prompt.
This protects the repo and the laptop — decrypted values still reach the server as
container env vars and are stored in `/etc/neo/state.json`.

### Shared Services
```
neo service create [type] [name]      Create service (mysql, postgres, redis, mariadb)
neo service list                      List services with linked apps
neo service info <svc>                Show connection details: host, port, user, password, database, URL (retrievable anytime)
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
neo backup <app>              Backup data volumes
neo restore <app> <file>      Restore from backup
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

### Maintenance
```
neo prune                     Remove old Docker images from server to free disk space
  --keep N                      Images to keep per app (default: 2)
  --dry-run                     Preview what would be deleted without making changes
  --force                       Skip confirmation prompt
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
neo firewall update           Upgrade CrowdSec + bouncer (apt/dnf), refresh hub content
                                (cscli hub update && upgrade), restart services
neo firewall status           Show CrowdSec status
neo firewall block <ip>       Manually ban an IP
  --reason <text>               Reason for the block
neo firewall unblock <ip>     Remove ban
neo firewall list             List active bans
neo stealth                   Toggle stealth mode (hide server from IP-based discovery)
```

### License (free, required)
```
neo activate                  Register a free license by email (prompts, POST /register)
neo activate <key>            Activate an existing key on this machine
neo license                   Interactive license management menu (plus = hidden alias)
neo license status            Show current license state
neo license deactivate        Remove license from this machine
```

Neo is **free for everyone** — there is no paid tier, and every feature is unlocked for any
valid license. You must activate once before running commands:
- No feature gates: **multi-server, backups, and device activations are all unlimited.**
  Parallel image-upload streams are fixed at 3 for everyone.
- One key works on **unlimited servers and unlimited devices**.
- First activation needs network; after that a **3-day offline cache grace** applies.
- Existing paid `plus`/`team` keys are **grandfathered** — they still validate and keep working.
- `NEO_DEV_PLUS=true` (or build flag `DevLicenseBypass=true`) skips the gate for local dev.

**Self-hosters:** the CMS `/api/license/register` endpoint must be live before rolling out the
CLI, otherwise clients cannot activate.

### Other
```
neo sync [app]                Sync server state back to .neo.yml (domain, port, https)
  --to <environment>             Which environment block to write into
  --dry-run                      Show the diff without writing
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
1. Activate the free license: `neo activate` — prompts for your email, issues a key instantly (the first command does this automatically if you skip it)
2. Get a server (any VPS) running a supported OS: Ubuntu 24.04+, Debian, Fedora 39+, CentOS/RHEL/AlmaLinux/Rocky 9+
3. Run `neo init root@<server-ip>` — installs Docker, Caddy, and configures the server
4. Deploy your first app: `neo deploy ./my-app --domain app.example.com`
5. Point your domain's DNS A record to the server IP

To join a server a teammate already set up, use `neo attach root@<ip>` instead of `neo init` — it registers the live server locally without reinstalling anything.

### Deploy a Project
1. Ensure a `Dockerfile` exists in the project root
2. Optionally create `.neo.yml` for persistent config — scaffold one with `neo config init` (or `neo config generate` from a `docker-compose.yml`); see reference below
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

### Wildcard HTTPS

For `*.example.com` (one cert covering every subdomain), pick one of two approaches:

**Option A — ACME DNS-01 (recommended for known/internal wildcards).** Gets a real Let's Encrypt wildcard cert up front. Requires a DNS provider API token (currently Cloudflare). The token is read from a local env var and copied to the server as a root-only file — never typed interactively.
```
CLOUDFLARE_API_TOKEN=... neo --server prod caddy dns example.com --app my-app
```

**Option B — Guarded on-demand TLS (for dynamic tenant subdomains).** Caddy issues a real cert for each subdomain on first request, gated by an ask URL your app controls (returns 200 only for allowed hosts). No need to pre-list hostnames.
```
neo --server prod caddy ondemand example.com --app my-app --replace-domains
```

Both are **idempotent** and **merge** into Caddy's TLS config — independent wildcard trees coexist on one server (e.g. `*.example.com` for prod and `*.staging.example.com` for staging, each its own cert). Re-run once per tree. Once configured, `neo domain my-app "*.example.com" --add` binds a wildcard to an app. Plain `neo domain` with a `*.` hostname is guarded — it requires DNS-01 or on-demand TLS to be set up first.

### Behind Cloudflare (Flexible SSL)

If the app sits behind Cloudflare in **Flexible SSL** mode (HTTPS at Cloudflare's edge, HTTP to the origin), serve the origin over HTTP only while still telling the app it's on HTTPS:
```
neo domain my-app --cloudflare-flexible
```
This sets an HTTP-only origin route and injects `X-Forwarded-Proto: https`, `X-Forwarded-Ssl: on`, and `X-Forwarded-Port: 443` so the app generates correct `https://` URLs. Equivalent `.neo.yml` field: `edge_https: true`. To flip an existing app's origin scheme without changing its domain: `neo domain my-app --https` or `neo domain my-app --http-only`.

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
Deploy to all: `neo deploy --all` (builds image once, deploys to all environments; `--parallel N` caps concurrent deploys, default 3 — use 1 for small servers)

**No `environments:`** — root `server:`/`domains:` work normally as before.

### Laravel Deploy (encrypted secrets + migrations)
The full shape for a framework app whose secrets live in git and whose deploys run
migrations:

```bash
# 1. Encrypt .env once. The key is printed once — store it in a password manager.
php artisan env:encrypt          # or: neo env encrypt   (no PHP needed)

# 2. Commit .env.encrypted. Keep .env gitignored.
```

```yaml
# .neo.yml
name: my-app
port: 8080
dockerfile: ./docker/Dockerfile
env_encrypted: .env.encrypted    # decrypted in memory at deploy

release:                         # run in the new container, before traffic switches
  - php artisan migrate --force
  - php artisan storage:link
  - php artisan config:cache

workers:
  queue:
    command: php artisan queue:work --tries=3

environments:
  production:
    server: prod-box
    domain: app.example.com
```

```bash
# 3. Deploy. Prompts once for the key, offers to save it for next time.
neo deploy --to production

# CI: no prompt
NEO_ENV_KEY=base64:xxxxx neo deploy --to production
```

If `migrate` fails, the new container is removed and the old one keeps serving — the
deploy aborts rather than putting a half-migrated app live. Release commands must exit;
`queue:work` belongs in `workers:`, not `release:`.

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

### WebSockets and Long-Lived Connections
Every route change (any app's deploy, `neo domain`, `neo caddy reload`, redirects) makes
Caddy load a whole new config. By default Caddy closes every open WebSocket on the
server when that happens. Since v0.26.13 neo sets `stream_close_delay: 24h` on every
route, so open connections keep running and are only closed 24h after a change.

- Routes get the setting when rewritten: after `neo upgrade`, run `neo caddy reload`
  once at a quiet time (that one run still drops current connections).
- Redeploying the app that holds the connection still disconnects its clients — that
  container is replaced.
- Traffic that doesn't pass through neo-caddy (AMQP between containers, a database
  connection) is never affected by Caddy. If such a connection drops on deploy, look at
  what the deploy recreated (sidecars!), not at Caddy.

### Stateful Apps (message brokers, databases)
Redeploys are blue-green by default: `app-<name>-next` starts beside the old container
on the same volumes, then the old one is `rm -f`'d. For a broker or database that means
two processes on one data directory, an unclean kill, and a new random hostname each
time. RabbitMQ keeps data per node name (`rabbit@<hostname>`), so every redeploy came up
as an empty node and vhosts, users and queues seemed to vanish.

```yaml
# .neo.yml — RabbitMQ as its own app
name: e-hub-rabbitmq
port: 15672
strategy: recreate      # stop old (up to 60s clean shutdown), then start new
# hostname: rabbitmq    # optional — defaults to the app name under recreate
volumes:
  data: /var/lib/rabbitmq
```

- Trade-off: a short outage while the new container starts, and nothing to fall back
  to if it fails. Neo then exits non-zero, says the app is down, and keeps the failed
  container for `neo logs <app>`.
- The hostname is saved in state and kept by `--env-only`, `neo env set/unset/import`,
  `neo update` and `neo volumes mount`.
- `strategy: recreate` can't be combined with `scale:`. Both keys work per environment.
- Switching an existing RabbitMQ app: the first recreate deploy changes the node name
  once (to `rabbit@<app-name>`), so it starts empty. Tell the user to run
  `rabbitmqctl export_definitions` first, or check `neo env <app>` for
  `RABBITMQ_NODENAME` (if set, nothing changes).
- Requires neo v0.26.14+.

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
edge_https: true                # HTTP origin behind an HTTPS edge (Cloudflare Flexible SSL)

# Environment
env_file: .env.production       # Load env vars from file
env_encrypted: .env.encrypted   # Committed encrypted env file (Laravel env:encrypt format)
env:                            # Env var defaults (non-sensitive values only)
  APP_ENV: production
  LOG_LEVEL: info

# Docker
dockerfile: ./docker/Dockerfile # Dockerfile path, relative to project root (default: ./Dockerfile)
                                #   build context is ALWAYS the project root, wherever this points
command: php artisan octane:start  # Override the image CMD. String or list form:
                                #   command: ["sh", "-lc", "php artisan octane:start"]
                                #   MUST be a long-running process — see command: vs release: below
compose_service: app            # Which docker-compose service to extract (if auto-detect fails)
restart: unless-stopped         # Docker restart policy
strategy: recreate              # blue-green (default) | recreate — for brokers/databases (v0.26.14+)
hostname: rabbitmq              # Fixed container hostname (default: app name under recreate)

# Health check
health:
  cmd: "curl -f http://localhost:8080/health"
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s

# command: vs release: — the two are not interchangeable.
#   command:  replaces the container's MAIN PROCESS. It has to keep running.
#             Use for: Octane/server flags per environment, a different entrypoint
#             from a shared image. Setting it to a one-off task (storage:link, a
#             migration) makes the container exit immediately and the deploy roll
#             back; neo names command: as the cause when that happens.
#   release:  one-off tasks that exit, run in the container before traffic switches.
#
# Release commands — run INSIDE the new container on the server, after its health
# check and BEFORE Caddy switches traffic. A failure removes the new container and
# aborts, so the old version keeps serving. Each command must exit (not a server).
# Scaled apps run the list once, in the first new replica.
release:
  - php artisan migrate --force
  - php artisan config:cache

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
# Recreated on EVERY deploy — fine for caches, wrong for brokers/databases.
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
# user/password/bypass support ${VAR} and ${VAR:-default}, resolved at deploy from
# env/env_file/OS env — keep the secret in a gitignored env_file. Persisted to
# server state, so neo domain / neo caddy update keep auth applied (don't strip it).
basic_auth:
  user: ${NEO_BASIC_AUTH_USER:-admin}
  password: ${NEO_BASIC_AUTH_PASSWORD}
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
#   - env_file:, env_encrypted:, dockerfile:, command:, release:, hooks: REPLACE the root value
#   - deploy --all builds one image, so environments must agree on dockerfile:
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
    env_encrypted: .env.staging.encrypted   # per-environment secrets
    dockerfile: ./docker/Dockerfile.staging # per-environment build file
    command: php artisan octane:start --workers=1  # per-environment process override
    release:                                # replaces the root release: list
      - php artisan migrate --force
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
    edge_https: true            # set when this env sits behind Cloudflare Flexible SSL
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

  # Server groups: deploy one environment to multiple servers simultaneously
  web:
    servers: [web-1, web-2, web-3]   # all servers get the deploy; --server targets one
    domains:
      - app.example.com
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
5. For disk space issues: `neo prune --dry-run` to preview, `neo prune` to clean up old images

### Domain/SSL not working
1. Verify DNS: `dig +short app.example.com` should return your server IP
2. DNS propagation can take up to 48h (usually minutes)
3. Ensure port 80 and 443 are open on the server firewall
4. Check Caddy logs: `neo ssh` then `docker logs neo-caddy`
5. For quick testing, use `--temp` flag for an auto-SSL sslip.io domain
6. For custom certs: `neo domain <app> <domain> --cert cert.pem --key key.pem`
7. Wildcard (`*.example.com`) needs DNS-01 or on-demand TLS first — set up with `neo caddy dns` or `neo caddy ondemand`, else Caddy can't issue the cert
8. Redirect loop / "too many redirects" behind Cloudflare: you're on Flexible SSL but the origin expects HTTPS — switch the origin to HTTP with `neo domain <app> --cloudflare-flexible` (or `edge_https: true`)

### Which version is deployed? / did my deploy land?
1. `neo list` — VERSION column shows tag + short commit for every app.
2. `neo status <app>` — the full record: commit, branch, image, who deployed it, when.
3. `neo deploys <app>` — the history, newest first.
4. From the box itself: `neo run <app> -- printenv | grep NEO_GIT`.
5. In CI: `neo status <app> --json | jq -r .deployment.commit` and compare to the sha you built.

A `*` after the version, or "dirty" in the history, means the build contained uncommitted
changes — the recorded commit describes only part of what shipped. Apps deployed before
0.26.0 show no version; that record does not exist retroactively.

### Basic auth not being enforced
Caddy applies config through its admin API, so there is no reload step in a healthy
setup — a deploy takes effect immediately. If the browser still isn't asking for
credentials:
1. `neo caddy routes` — the AUTH column shows what the proxy is really serving. `none`
   means the live route has no auth handler, whatever `.neo.yml` says.
2. `neo caddy reload --app <app>` rebuilds the route from server state. No redeploy needed.
3. `neo caddy update` is NOT this — it updates the Caddy image, not the routes.
4. Check the password resolved: an unset `${VAR}` leaves the literal text as the
   credential and every login fails. Deploy warns when this happens.

### Container exits immediately / "failed health check" right after adding command:
A container's command IS its main process. `command: php artisan storage:link` runs for
~50ms, exits, and takes the container down — health check fails, deploy rolls back. Neo
names command: as the likely cause when the container exited on its own.
Move one-off tasks to `release:`, and keep `command:` for something that stays running
(a server, a worker loop). Background jobs belong in `workers:`.

### neo list says "No apps installed" but containers are running
Server state (`/etc/neo/state.json`) and the server disagree — a lost state write, or a
container removed with plain `docker rm`.
1. `neo list` reports the drift directly: apps running but untracked, tracked but with no
   container, or present but stopped. The dashboard shows `⚠ N untracked`.
2. Untracked apps: redeploy them (`neo deploy --to <environment>`) to restore the record.
3. Tracked but missing: redeploy, or drop the record with `neo remove <app>`.
4. `neo list --json` exposes the same under a `drift` key for scripts.

### Deploy fails right after neo sync
Older Neo versions wrote `domain:` at the ROOT of `.neo.yml` even when `environments:`
were defined — the one combination deploy rejects ("root-level domain:/domains: is
ignored when environments: are defined"). Delete the root `domain:` line; the
per-environment one is the real one. Fixed in 0.24.4, which writes into the environment
block and no longer rewrites comments or formatting.

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
1. Teammate's key not working: verify they ran `neo key show` — it generates the key if missing
2. Confirm the key was added: `neo key list` — check the server shows their key
3. "Permission denied" after adding: ensure teammate's `.neo.yml` has `server: root@<ip>` (their own neo key is used for auth)
4. Revoke access: `neo key list` (find the number), then `neo key remove <number>`
5. A fresh install means a new key — teammate must run `neo key show` again and you must `neo key add` again

---

## Decision Guide

- **`neo install` vs `neo deploy`**: Use `install` for pre-built templates (Ghost, WordPress, etc.) that pull images from registries. Use `deploy` for custom projects with a `Dockerfile`.
- **Shared service vs bundled**: Shared services (`neo service create`) save RAM on small VMs when multiple apps need the same database. Bundled services (via templates) are simpler for single-app setups.
- **`neo dev` vs raw `docker compose`**: Use `neo dev` to get automatic env loading, volume mounting, worker/sidecar startup, and `.neo.yml` integration. Use raw compose if you need compose-specific features neo doesn't wrap.
- **Single domain vs multi-domain**: Use `domain:` for one domain. Use `domains:` list when an app needs multiple domains (e.g., `example.com` + `www.example.com`). Use `--add`/`--remove` flags for incremental changes.
- **Wildcard: DNS-01 vs on-demand**: Use `neo caddy dns` (ACME DNS-01) when you know the wildcard up front and have a DNS provider token — one real wildcard cert, works for internal subdomains too. Use `neo caddy ondemand` for unbounded/dynamic tenant subdomains where you can't pre-list hostnames — Caddy issues per-host certs on demand, gated by your app's ask URL.
- **Cloudflare Flexible SSL**: If Cloudflare terminates TLS at its edge and talks HTTP to your origin, use `--cloudflare-flexible` / `edge_https: true` — origin serves HTTP but the app still sees `https` via forwarded headers. Without it you get redirect loops.
- **Licensing**: Neo is free but every user must activate once (`neo activate`). There's no paid tier and no feature gates — `neo backup`, `neo restore`, and unlimited multi-server all work for everyone. Old paid `plus`/`team` keys are grandfathered.
- **`neo init` vs `neo attach`**: Use `init` on a fresh VPS to install Docker + Caddy. Use `attach` to register a server a teammate already initialized — it never reinstalls or overwrites remote state.
- **Debugging**: Add `--debug` to any command to see the SSH commands being executed. Use `neo logs <app> -g "error"` to filter log output. Use `neo status --json` for machine-readable health data.
