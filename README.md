# Network Copilot CLI 🖥️🌐

> A portable GitHub Copilot CLI environment optimized for Windows Server administration and network operations.

[![PowerShell](https://img.shields.io/badge/PowerShell-7+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![GitHub Copilot](https://img.shields.io/badge/GitHub_Copilot-CLI-purple.svg)](https://github.com/features/copilot)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io/)
[![GitHub](https://img.shields.io/github/stars/djcyphers/network-copilot-cli?style=social)](https://github.com/djcyphers/network-copilot-cli)

**Repository:** [github.com/djcyphers/network-copilot-cli](https://github.com/djcyphers/network-copilot-cli)

---

## 🎯 What Is This?

A ready-to-use Copilot CLI configuration for **network administrators** and **Windows Server operators**. Instead of general-purpose AI assistance, this setup is tuned for:

- ✅ Network diagnostics (ping, traceroute, DNS, port scanning)
- ✅ Windows Server management (services, events, processes)
- ✅ Active Directory queries
- ✅ Firewall and security operations
- ✅ DHCP/DNS infrastructure management
- ✅ PowerShell 7 best practices

---

## 📦 What's Included

| File | Purpose |
|------|---------|
| `install.ps1` | **Run once** - sets everything up automatically |
| `AGENTS.md` | AI instructions - automatically loaded by Copilot CLI |
| `SETUP.md` | Detailed installation guide |
| `PROMPTS.md` | 50+ ready-to-use network admin prompts |
| `mcp-config.json` | Curated MCP servers for network/sysadmin work |
| `profile-loader.ps1` | PowerShell profile integration with helper functions |
| `.env.example` | Environment variable template |
| `scripts/` | Helper PowerShell scripts |
| `skills/` | **Agent Skills** - modular expertise loaded on-demand |

---

## 🧠 Agent Skills System (1000 IQ Feature)

Inspired by the [Agent Skills Standard](https://agentskills.io), this setup uses **progressive disclosure** to save context window:

```
copcli/skills/
├── network-diagnostics/SKILL.md   # DNS, ping, ports, firewall
├── server-health/SKILL.md         # CPU, memory, disk, services
├── active-directory/SKILL.md      # Users, groups, OUs, GPOs
├── remote-management/SKILL.md     # WinRM, SSH, PSRemoting
└── SKILLS_INDEX.md                # Master index
```

### How It Works
1. **At startup**: Agent reads only skill `name` + `description` (~100 tokens each)
2. **On demand**: When your query matches a skill's domain, full instructions load
3. **Result**: 4 skills = ~400 tokens baseline vs ~8000 tokens if all loaded upfront

### Example
```
You: "Why can't Server01 reach the database?"
→ Agent loads: skills/network-diagnostics/SKILL.md
→ Follows: Diagnostic Workflow in that skill
→ Reports: Structured findings
```

### Adding Custom Skills
Create `skills/your-skill/SKILL.md` with YAML frontmatter:
```yaml
---
name: your-skill-name
description: "When to use this skill"
allowed-tools:
  - windows-command-line
---
# Your instructions here
```

---

## 🚀 Quick Start (5 Minutes)

### 1. Install Copilot CLI

```powershell
npm install -g @github/copilot@prerelease
copilot
# Inside Copilot CLI, type: /login
# Follow the browser OAuth flow to authenticate
```

### 2. Copy This Folder Anywhere & Run Installer

```powershell
# Copy to your preferred location
Copy-Item -Path ".\copcli" -Destination "C:\Tools\copcli" -Recurse

# Run the installer (one time only)
cd C:\Tools\copcli
.\install.ps1

# Optional: also install MCP servers
.\install.ps1 -InstallMCP
```

That's it. The installer:
- Auto-detects its location
- Adds one line to your `$PROFILE`  
- Creates `.env` from template
- Verifies Copilot CLI is installed

### 3. Open New PowerShell & Start Using

```powershell
# Verify installation
Show-CopCLIStatus

# Start Copilot CLI
ncop

# Or with a prompt
copilot "Check if server DC01 is reachable and show its uptime"
```

> **Moving later?** Copy the folder to new location, run `install.ps1` again. It's idempotent.

---

## ⚠️ Important: MCP Config Location

**Copilot CLI does NOT read `mcp-config.json` from your copcli folder!**

It reads from a **fixed location**: `~/.copilot/mcp-config.json` (i.e., `C:\Users\YourName\.copilot\mcp-config.json`)

| Location | Purpose |
|----------|--------|
| `D:\copcli\mcp-config.json` | Your portable **template/backup** |
| `~/.copilot/mcp-config.json` | What Copilot CLI **actually reads** |

### What This Means

1. **install.ps1** copies your config to `~/.copilot/` once during setup
2. **After install**: editing `D:\copcli\mcp-config.json` does nothing until you sync it
3. **To sync changes**: Run `Copy-Item "$env:COPCLI_HOME\mcp-config.json" "$HOME\.copilot\mcp-config.json" -Force`
4. **Or edit directly**: `notepad "$HOME\.copilot\mcp-config.json"`
5. **Or use Copilot's built-in**: Type `/mcp add` inside Copilot CLI

---

## 🔧 MCP Servers (Curated List)

This setup includes only **network/sysadmin relevant** MCP servers:

| Server | Description | Status |
|--------|-------------|--------|
| `sequential-thinking` | Multi-step problem solving | ✅ Enabled |
| `memory` | Persistent knowledge graph | ✅ Enabled |
| `github` | Repository operations | ✅ Enabled |
| `filesystem` | Safe file access | ✅ Enabled |
| `tavily` | Web search for docs | ✅ Enabled |
| `windows-command-line` | Secure command execution | ✅ Enabled |
| `windows-mcp` | Windows UI automation | ⏸️ Disabled |
| `mongodb` | Database operations | ⏸️ Disabled |
| `ssh` | Remote host management | ⏸️ Disabled |

**Excluded** (not relevant for network ops): Chrome DevTools, Playwright, Puppeteer, Excel, Slack, Notion, Figma, Stripe, etc.

---

## 📝 Example Prompts

### Network Diagnostics
```
Check if server 192.168.1.100 is reachable, then test ports 80, 443, and 3389.
```

### Windows Server
```
Show the top 10 processes by memory on SERVER01 and list any error events from the last hour.
```

### Active Directory
```
Find all user accounts that haven't logged in for 90 days and show their department.
```

### Troubleshooting
```
Using sequential thinking, diagnose why WEBSERVER01 can't connect to the database on SQLSERVER01.
```

See [PROMPTS.md](PROMPTS.md) for 50+ more examples.

---

## 🔐 Security Notes

1. **Credentials**: Use `Save-ServerCredential` to store creds securely (encrypted per-user/per-machine)
2. **API Keys**: Never commit `.env` files - use `.env.example` as template
3. **Commands**: The MCP config can restrict allowed/denied commands
4. **Scope**: AGENTS.md includes guardrails against destructive operations

---

## 🔌 Integration with Other Tools

### VS Code
Copy `mcp-config.json` to your VS Code Copilot MCP settings.

### Windows Terminal
Add a Copilot-enabled profile (adjust path to your location):
```json
{
    "name": "Network Copilot",
    "commandline": "pwsh -NoExit -Command \". 'C:\\Tools\\copcli\\profile-loader.ps1'; Show-CopCLIStatus\"",
    "icon": "🤖"
}
```

### Oh My Posh
Add a Copilot segment to your prompt showing usage stats.

---

## 🔍 Lesser-Known Tools Discovered

During research, these potentially useful but less popular tools were identified:

| Tool | Description | Link |
|------|-------------|------|
| **mdflow** | Execute .md files as agent commands | [github.com/johnlindquist/mdflow](https://github.com/johnlindquist/mdflow) |
| **spec-kit** | Project scaffolding with AGENTS.md | [github.com/github/spec-kit](https://github.com/github/spec-kit) |
| **gga** | Pre-commit AI code review using AGENTS.md | [github.com/Gentleman-Programming/gga](https://github.com/Gentleman-Programming/gentleman-guardian-angel) |
| **stakpak** | DevOps agent with rulebooks | [github.com/stakpak/agent](https://github.com/stakpak/agent) |
| **vibe** | Minimal CLI coding agent (Mistral) | [github.com/mistralai/mistral-vibe](https://github.com/mistralai/mistral-vibe) |
| **ContextForge** | MCP Gateway/Registry | [github.com/IBM/mcp-context-forge](https://github.com/IBM/mcp-context-forge) |
| **console-automation-mcp** | 40 tools for terminal automation | [github.com/ooples/mcp-console-automation](https://github.com/ooples/mcp-console-automation) |

---

## 📚 Resources

- [GitHub Copilot CLI Docs](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line)
- [Agent Skills Standard](https://agentskills.io/) — Open standard for portable AI skills
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [MCP Server Directory](https://github.com/modelcontextprotocol/servers)
- [Awesome MCP Servers](https://github.com/hireblackout/awesome-mcp-servers)
- [PowerShell 7 Docs](https://docs.microsoft.com/en-us/powershell/)

---

## 📄 License

MIT - Use freely for personal and commercial purposes.

---

*Created: December 2025 | Version: 1.0.0*
