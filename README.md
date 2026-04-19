# neo-skill

AI coding assistant instructions for [Neo](https://neo.vxero.dev) — a CLI that deploys apps, manages servers, configures services, and handles the full lifecycle of Docker-based applications over SSH.

Works with **Claude Code, GitHub Copilot, Cursor, Windsurf, Cline, OpenAI Codex**, and any other AI assistant that supports custom instructions.

## Install Neo

```bash
curl -fsSL https://get.vxero.dev/neo/install.sh | sh
```

Installs the latest `neo` binary to `/usr/local/bin`. Supports macOS, Linux, and Windows (Git Bash).

```bash
neo init root@<your-server-ip>    # set up your first server
neo deploy                         # deploy a project with a Dockerfile
neo help                           # grouped command reference
```

## What It Does

Once installed, your AI assistant understands:

- **All 30+ neo commands** — deploy, init, env, service, domain, dev, firewall, backup, tunnel, etc.
- **`.neo.yml` configuration** — every field, volume formats, workers, sidecars, hooks, environments
- **Common workflows** — first-time server setup, deploying projects, adding databases, SSL, multi-env deploys
- **Troubleshooting** — deploy failures, domain/SSL issues, service linking, SSH problems
- **Decision-making** — shared vs bundled services, `neo install` vs `neo deploy`, dev modes

The assistant reads your project files (`.neo.yml`, `Dockerfile`, `docker-compose.yml`) for context-aware guidance tailored to your setup.

## Supported AI Tools

| Tool | Format | File |
|------|--------|------|
| **Claude Code** | Skill + Plugin | `skills/neo/SKILL.md` |
| **GitHub Copilot** | Custom Instructions | `copilot-instructions.md` |
| **Cursor** | Rules | `.cursorrules` |
| **Windsurf** | Rules | `.windsurfrules` |
| **Cline / Roo Code** | Rules | `.clinerules` |
| **OpenAI Codex** | Agent Instructions | `AGENTS.md` |
| **Any other tool** | Markdown | `neo.md` |

## Quick Install

Auto-detect which AI tools are configured and install the right files:

```bash
git clone https://github.com/solutionforestteam/neo-skill.git
cd neo-skill
./install.sh /path/to/your/project
```

## Manual Install

### Claude Code

**Option A — Plugin** (recommended, available across all projects):
```bash
claude plugin add /path/to/neo-skill
```

**Option B — Project-level** (scoped to one project):
```bash
mkdir -p .claude/skills/neo
cp /path/to/neo-skill/skills/neo/SKILL.md .claude/skills/neo/SKILL.md
```

Then invoke with `/neo` in Claude Code:
```
/neo deploy my Laravel app
/neo set up postgres for my app
/neo configure domain with SSL
```

### GitHub Copilot

```bash
mkdir -p .github
cp /path/to/neo-skill/copilot-instructions.md .github/copilot-instructions.md
```

### Cursor

```bash
cp /path/to/neo-skill/.cursorrules .cursorrules
```

### Windsurf

```bash
cp /path/to/neo-skill/.windsurfrules .windsurfrules
```

### Cline / Roo Code

```bash
cp /path/to/neo-skill/.clinerules .clinerules
```

### OpenAI Codex

```bash
cp /path/to/neo-skill/AGENTS.md AGENTS.md
```

### Any Other Tool

Use `neo.md` as your custom instructions — it's the universal source document that all other formats are derived from.

## File Structure

```
neo-skill/
├── neo.md                     # Core instructions (single source of truth)
├── skills/neo/SKILL.md        # Claude Code skill (with YAML frontmatter)
├── .claude-plugin/plugin.json # Claude Code plugin manifest
├── copilot-instructions.md    # GitHub Copilot format
├── .cursorrules               # Cursor format
├── .windsurfrules             # Windsurf format
├── .clinerules                # Cline / Roo Code format
├── AGENTS.md                  # OpenAI Codex format
├── install.sh                 # Auto-detect installer
└── README.md
```

All tool-specific files contain the same content as `neo.md` — just in the format each tool expects. `SKILL.md` adds Claude Code YAML frontmatter on top.

## Updating

Pull the latest and re-run:

```bash
cd neo-skill && git pull
./install.sh /path/to/your/project
```

## License

MIT
