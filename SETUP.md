# Network Copilot CLI — Setup Guide

> Complete setup instructions for a portable GitHub Copilot CLI environment optimized for Windows Server and network administration.

---

## 📋 Prerequisites

### Required Software
- **PowerShell 7+** — [Download](https://github.com/PowerShell/PowerShell/releases)
- **Node.js 18+** — [Download](https://nodejs.org/) (for MCP servers)
- **Git** — [Download](https://git-scm.com/)
- **GitHub Account** with Copilot subscription

### Optional but Recommended
- **Python 3.10+** with `uv` — For Python-based MCP servers
- **Windows Admin Center** — For GUI-based server management
- **Ripgrep** — Fast file search: `winget install BurntSushi.ripgrep.MSVC`

---

## 🚀 Quick Start

### Step 1: Install Copilot CLI

```powershell
# Install Copilot CLI (prerelease)
npm install -g @github/copilot@prerelease

# Verify installation
copilot --version

# Authenticate with GitHub (run copilot, then type /login inside)
copilot
# Inside the CLI, type: /login
# Follow the browser OAuth flow
```

### Step 2: Copy Folder & Run Installer

```powershell
# Copy to your preferred location
$destination = "C:\Tools\copcli"  # or anywhere you want
Copy-Item -Path ".\*" -Destination $destination -Recurse -Force

# Run the one-time installer
cd $destination
.\install.ps1
```

The installer automatically:
- Detects its own location (truly portable)
- Adds the loader to your `$PROFILE` (idempotent - safe to re-run)
- **Copies `mcp-config.json` to `~/.copilot/`** (where Copilot CLI reads it)

> ⚠️ **GOTCHA: MCP Config Location**
>
> Copilot CLI reads its MCP config from `~/.copilot/mcp-config.json` — NOT from your copcli folder!
>
> | Your Folder | Copilot CLI Reads From |
> |-------------|------------------------|
> | `D:\copcli\mcp-config.json` | ❌ Template only |
> | `C:\Users\You\.copilot\mcp-config.json` | ✅ Actual config |
>
> **If you edit your portable `mcp-config.json` after install**, you must sync it:
> ```powershell
> Copy-Item "$env:COPCLI_HOME\mcp-config.json" "$HOME\.copilot\mcp-config.json" -Force
> ```
> Or edit the real file directly: `notepad "$HOME\.copilot\mcp-config.json"`
- Creates `.env` from `.env.example`
- Verifies Copilot CLI is installed

### Step 3: Configure API Keys

Edit the `.env` file created by the installer:

### Step 4: Install MCP Servers

```powershell
# === CORE (Recommended) ===
npm install -g @modelcontextprotocol/server-sequential-thinking
npm install -g @modelcontextprotocol/server-memory
npm install -g @modelcontextprotocol/server-filesystem
npm install -g @modelcontextprotocol/server-github

# === NETWORK/WINDOWS FOCUSED ===
npm install -g @alxspiker/windows-command-line-mcp

# Console Automation (40 tools - terminal sessions, SSH, async jobs)
npm install -g console-automation-mcp

# Windows UI Automation (click, type, app control, screenshots)
# Requires Python 3.13+ and uv package manager
pip install uv
pip install windows-mcp
# Alternative: curl -LsSf https://astral.sh/uv/install.sh | sh

# === OPTIONAL ===
# Web search for docs/troubleshooting
npm install -g @tavily/mcp-server
```

### Step 5: Verify Installation

```powershell
# Open a NEW PowerShell window, then:
Show-CopCLIStatus

# You should see all green checkmarks
```

> **Moving the folder later?** Just copy to the new location and run `.\install.ps1` again. It will update your profile automatically.

---

## ⚙️ Configuration Files

### MCP Configuration

The `mcp-config.json` contains pre-configured MCP servers. To use with Copilot CLI:

```powershell
# Copy to Copilot CLI config location
$copilotConfigDir = "$env:APPDATA\github-copilot"
New-Item -ItemType Directory -Path $copilotConfigDir -Force
Copy-Item "$env:COPCLI_HOME\mcp-config.json" "$copilotConfigDir\mcp.json"
```

### VS Code Integration (Optional)

If using VS Code with Copilot extension, add to `.vscode/mcp.json`:

```json
{
  "servers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    }
  }
}
```

---

## 🔧 MCP Server Details

### Windows Command Line MCP

Secure command execution with allow/deny lists:

```powershell
# Install
npm install -g @alxspiker/windows-command-line-mcp

# Configuration (optional)
# Create config.yaml to restrict commands
@"
allowed_commands:
  - Get-*
  - Test-*
  - Resolve-*
  - ping
  - tracert
  - nslookup
  - ipconfig
  - netstat

denied_commands:
  - Remove-*
  - Delete-*
  - Format-*
  - rm
  - del
"@ | Out-File "$env:COPCLI_HOME\wincmd-config.yaml"
```

### Sequential Thinking MCP

For complex multi-step problem solving:

```powershell
# Install
npm install -g @modelcontextprotocol/server-sequential-thinking

# Use in prompts
# "Using sequential thinking, diagnose why Server01 can't reach the database"
```

### Memory MCP

Persistent knowledge across sessions:

```powershell
# Install
npm install -g @modelcontextprotocol/server-memory

# The memory.json file stores entities and relationships
# Great for storing:
# - Server inventories
# - Network topology facts
# - Troubleshooting patterns
```

### Filesystem MCP

Safe file access with path restrictions:

```powershell
# Install
npm install -g @modelcontextprotocol/server-filesystem

# Configure allowed paths in mcp-config.json
# Example: Only allow access to Scripts and Logs folders
```

---

## 📁 Folder Structure

```
copcli/
├── AGENTS.md           # Agent instructions (auto-loaded)
├── SETUP.md            # This file
├── PROMPTS.md          # Network-specific prompt examples
├── mcp-config.json     # MCP server configuration
├── profile-loader.ps1  # PowerShell profile integration
├── memory.json         # Persistent memory (auto-created)
├── .env.example        # Environment variable template
└── scripts/            # Helper scripts (optional)
    ├── test-connectivity.ps1
    ├── server-health-check.ps1
    └── network-inventory.ps1
```

---

## 🔐 Security Considerations

### Credential Management

```powershell
# Use Windows Credential Manager
cmdkey /add:ServerName /user:Domain\User /pass:Password

# Or PowerShell SecretManagement module
Install-Module Microsoft.PowerShell.SecretManagement
Install-Module Microsoft.PowerShell.SecretStore

# Store secrets securely
Set-Secret -Name "GitHub-Token" -SecureStringSecret (ConvertTo-SecureString $token -AsPlainText -Force)

# Retrieve in scripts
$token = Get-Secret -Name "GitHub-Token" -AsPlainText
```

### API Key Security

Never commit `.env` files with real keys. Use `.env.example` as template:

```bash
# .env.example
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx
TAVILY_API_KEY=tvly_xxxxxxxxxxxxxxxxxxxxxxxxxxxx
MONGODB_URI=mongodb://user:pass@host:27017/db
```

---

## 🔄 Updating

### Update Copilot CLI

```powershell
npm update -g @github/copilot@prerelease
```

### Update MCP Servers

```powershell
# Update all global npm packages
npm update -g

# Or specific packages
npm update -g @modelcontextprotocol/server-sequential-thinking
npm update -g @modelcontextprotocol/server-memory
```

---

## 🐛 Troubleshooting

### Copilot CLI Not Found

```powershell
# Check npm global bin is in PATH
npm config get prefix

# Add to PATH if needed
$npmPrefix = npm config get prefix
$env:PATH += ";$npmPrefix"
```

### MCP Server Connection Failed

```powershell
# Test MCP server manually
npx -y @modelcontextprotocol/server-sequential-thinking

# Check Node.js version
node --version  # Should be 18+

# Clear npm cache
npm cache clean --force
```

### Authentication Issues

```powershell
# Re-authenticate Copilot
copilot auth logout
copilot auth login

# Check GitHub CLI auth (if using gh)
gh auth status
```

---

## 📚 Additional Resources

- [GitHub Copilot CLI Docs](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line)
- [Model Context Protocol Spec](https://modelcontextprotocol.io/)
- [MCP Server Registry](https://github.com/modelcontextprotocol/servers)
- [PowerShell 7 Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Windows Server Administration](https://docs.microsoft.com/en-us/windows-server/)

---

*Setup Guide Version: 1.0.0 — December 2025*
