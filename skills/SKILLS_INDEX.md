# Network Copilot CLI — Skills Index

> Skills are loaded dynamically based on context. This file maps skill directories to their triggers.

## Available Skills

| Skill | Triggers | Description |
|-------|----------|-------------|
| `network-diagnostics` | connectivity, DNS, ping, traceroute, port, firewall | Troubleshoot network issues |
| `server-health` | health, performance, CPU, memory, disk, slow | Server health checks |
| `active-directory` | AD, user, group, OU, GPO, domain, locked | AD queries and management |
| `remote-management` | remote, WinRM, SSH, Invoke-Command | Remote server execution |

## How Skills Work

1. **Discovery**: Agent reads SKILL.md frontmatter (`name` + `description`) at startup
2. **Activation**: When user query matches a skill's domain, full instructions load
3. **Execution**: Agent follows skill-specific workflows and patterns
4. **Context-efficient**: Only active skill consumes context window

## Skill Structure

```
skills/
├── network-diagnostics/
│   └── SKILL.md          # Frontmatter + instructions
├── server-health/
│   └── SKILL.md
├── active-directory/
│   └── SKILL.md
├── remote-management/
│   └── SKILL.md
└── SKILLS_INDEX.md       # This file
```

## Adding New Skills

1. Create a new directory: `skills/your-skill-name/`
2. Add `SKILL.md` with required frontmatter:
   ```yaml
   ---
   name: your-skill-name
   description: "When to use this skill (keywords, scenarios)"
   license: MIT
   compatibility:
     - copilot-cli
   allowed-tools:
     - windows-command-line
   ---
   ```
3. Add instructions in Markdown body
4. Update this index

## Compatibility

These skills follow the [Agent Skills Standard](https://agentskills.io/specification):
- ✅ GitHub Copilot CLI
- ✅ VS Code Copilot (agent mode)
- ✅ Claude Desktop
- ✅ Any MCP-compatible agent

## Future Skills (Planned)

- [ ] `firewall-management` — Windows Firewall and Azure NSG rules
- [ ] `certificate-management` — SSL/TLS certs, expiry checks
- [ ] `backup-restore` — Windows Server Backup, VSS snapshots
- [ ] `dns-management` — DNS zone/record management
- [ ] `iis-management` — IIS sites, app pools, bindings
