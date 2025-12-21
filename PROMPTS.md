# Network Copilot CLI — Prompt Examples

> Ready-to-use prompts for common Windows Server and network administration tasks.
> Copy these directly into Copilot CLI or customize for your environment.

---

## 🌐 Network Diagnostics

### Basic Connectivity Check
```
Check if server 192.168.1.100 is reachable, then test if ports 80, 443, and 3389 are open. Summarize the results in a table.
```

### Full Network Path Analysis
```
Using sequential thinking, diagnose the network path from this machine to database-server.contoso.com:
1. Test ICMP connectivity
2. Check DNS resolution
3. Trace the route
4. Test TCP connectivity on port 1433
5. Summarize any issues found
```

### DNS Troubleshooting
```
Troubleshoot DNS resolution for webapp.contoso.com:
- Check forward and reverse DNS
- Query multiple DNS servers (internal and 8.8.8.8)
- Verify the record exists in our DNS zone
- Compare authoritative vs cached responses
```

### MTU Discovery
```
Help me find the correct MTU size for the path to 10.0.0.1. Start at 1472 and work down until we find a size that doesn't fragment.
```

---

## 🖥️ Windows Server Administration

### Service Health Check
```
Check the status of these critical services on SERVER01, SERVER02, and SERVER03:
- SQL Server (MSSQLSERVER)
- IIS (W3SVC)
- Remote Desktop (TermService)
- Windows Firewall (MpsSvc)

Format as a table showing server name, service, status, and startup type.
```

### Event Log Analysis
```
Search the System and Application event logs on this server for:
- Error events in the last 24 hours
- Warning events related to "disk" or "memory"
- Any events with ID 7036 (service start/stop)

Summarize the top 5 most frequent issues.
```

### Disk Space Report
```
Generate a disk space report for all local drives showing:
- Drive letter
- Total size
- Used space
- Free space
- Percent free

Highlight any drives with less than 20% free space.
```

### Process Memory Analysis
```
List the top 10 processes by memory usage on this server. Include:
- Process name
- PID
- Working set (MB)
- Private bytes (MB)
- CPU time

Flag any process using more than 2GB RAM.
```

---

## 🔐 Active Directory

### User Account Investigation
```
Look up the Active Directory user "jsmith" and show:
- Full name and email
- Account status (enabled/locked/expired)
- Last logon time
- Group memberships
- Password last set date
```

### Group Membership Audit
```
List all members of the "Domain Admins" and "Enterprise Admins" groups.
For each member, show:
- Username
- Display name
- Last logon date
- Account enabled status

Flag any service accounts or unexpected members.
```

### Computer Account Search
```
Find all Windows Server computers in AD that:
- Have names starting with "SRV" or "SVR"
- Are enabled
- Have logged in within the last 30 days

Show name, OS, last logon, and IPv4 address.
```

### Stale Account Report
```
Generate a report of user accounts that haven't logged in for 90+ days.
Include:
- Username
- Display name
- Last logon date
- Account status
- OU location

Sort by last logon date (oldest first).
```

---

## 🔥 Firewall Management

### Firewall Rule Audit
```
List all enabled inbound firewall rules on this server that:
- Allow any source address
- Are set to "Allow"
- Apply to the "Domain" or "Private" profile

Flag any rules that seem overly permissive.
```

### Port Accessibility Check
```
Check if these ports are allowed through the Windows Firewall:
- 80 (HTTP)
- 443 (HTTPS)
- 1433 (SQL Server)
- 3389 (RDP)
- 5985 (WinRM)

For each, show if there's an inbound rule allowing it.
```

### Firewall Rule Search
```
Find all firewall rules (inbound and outbound) that reference:
- Port 8080
- The program "sqlservr.exe"
- The service "MSSQLSERVER"

Show rule name, direction, action, and status.
```

---

## 📡 Network Infrastructure

### DHCP Scope Analysis
```
Connect to DHCP server DHCP01 and for each IPv4 scope show:
- Scope ID and name
- Address range
- Total addresses
- Addresses in use
- Percent utilization

Flag any scopes above 85% utilization.
```

### DHCP Lease Search
```
On DHCP server DHCP01, find any leases where:
- The hostname contains "TEMP" or "TEST"
- The lease was created in the last 7 days
- The MAC address starts with "00:50:56" (VMware)

List hostname, IP, MAC, and lease expiration.
```

### DNS Zone Record Check
```
Query DNS zone "contoso.com" on server DNS01 and:
- Count total A records
- Count total CNAME records
- Find any records pointing to 192.168.1.x addresses
- Identify any duplicate A records (same name, different IP)
```

---

## 🔧 Troubleshooting Scenarios

### "Server Unreachable" Troubleshooting
```
Use sequential thinking to diagnose why SERVER05 is unreachable:

1. Check if our machine has network connectivity at all
2. Test if we can reach the default gateway
3. Check if DNS is working
4. Try to ping SERVER05 by IP vs hostname
5. Check if SERVER05 is responding to WinRM
6. Check our firewall for any blocks
7. Provide a summary of findings and recommended actions
```

### "Application Slow" Investigation
```
Investigate performance issues for the web application on WEBSERVER01:

1. Check CPU, memory, and disk utilization
2. Review IIS worker process resource usage
3. Check network connectivity to the database server
4. Look for recent error events
5. Test response time from this machine
6. Summarize findings with recommendations
```

### "Cannot Connect to Database" Diagnosis
```
Diagnose database connectivity issue to SQLSERVER01:

1. Verify DNS resolution for SQLSERVER01
2. Test TCP connectivity to port 1433
3. Check if SQL Server Browser (UDP 1434) responds
4. Verify Windows Firewall isn't blocking
5. Test with a simple SQL connection string
6. Check SQL Server error logs if accessible
7. Provide troubleshooting summary
```

### "Intermittent Network Issues" Analysis
```
Set up monitoring to diagnose intermittent network issues to 10.0.0.50:

1. Run continuous ping for 100 packets
2. Capture packet loss percentage and latency stats
3. If loss detected, check for patterns
4. Look at network adapter event logs
5. Check for duplex/speed mismatches
6. Summarize findings
```

---

## 📊 Reporting & Inventory

### Server Inventory Report
```
Create an inventory of all Windows servers we can reach:
- Use AD to get list of server computer accounts
- Test connectivity to each
- Get OS version, last boot time, and IP address
- Export to CSV format

Only include servers that respond to WinRM.
```

### SSL Certificate Audit
```
Check SSL certificates on these servers (port 443):
- web01.contoso.com
- web02.contoso.com
- api.contoso.com

For each, report:
- Subject and issuer
- Expiration date
- Days until expiry
- Whether it's valid

Flag any expiring within 30 days.
```

### Windows Update Status
```
Check Windows Update status on SERVER01, SERVER02, SERVER03:
- Last update installation date
- Number of pending updates
- Any failed updates
- Reboot pending status

Format as a summary table.
```

---

## 💾 Backup & Recovery

### Backup Status Check
```
Check Windows Server Backup status on this server:
- Last successful backup date/time
- Backup target/destination
- Backup size
- Any failed backups in the last week

Alert if last backup is older than 24 hours.
```

### Shadow Copy Inventory
```
List all volume shadow copies (VSS snapshots) on this server:
- Volume
- Shadow copy ID
- Creation time
- Size

Show total space used by shadow copies.
```

---

## 🔄 Maintenance Tasks

### Disk Cleanup Preparation
```
Analyze what can be safely cleaned up on this server:
- Windows Update cleanup potential
- Temp file folders size
- IIS log files older than 30 days
- Old user profiles not used in 90 days

Show potential space savings for each category.
Don't delete anything - just report.
```

### Scheduled Task Audit
```
List all scheduled tasks on this server that:
- Are enabled
- Run as a specific user (not SYSTEM)
- Last ran successfully or failed

Show task name, last run time, last result, and run-as account.
Flag any tasks that failed recently.
```

### Service Account Review
```
Find all services running under specific user accounts (not SYSTEM/NetworkService/LocalService):
- Service name
- Service account
- Status
- Start type

This helps identify service accounts that may need password rotation.
```

---

## 🎯 Quick One-Liners

### Test All Domain Controllers
```
Test connectivity to all domain controllers and report which are reachable.
```

### Find Large Files
```
Find the 10 largest files in C:\Windows\Logs and show size and last modified date.
```

### Check Time Sync
```
Check time synchronization status and show NTP server configuration.
```

### List Open Ports
```
Show all TCP ports currently listening on this server with the associated process name.
```

### Check Memory Pressure
```
Show current memory utilization, page file usage, and available memory. Alert if under 10% free.
```

### Recent Reboots
```
Show the last 5 system reboots with date/time and whether they were planned or unexpected.
```

### Failed Logins
```
Show the last 20 failed login attempts from the Security event log with username, source IP, and failure reason.
```

### Hotfix History
```
List the last 10 Windows updates installed with date and KB number.
```

---

## 💡 Pro Tips

### Using Sequential Thinking
Prefix complex diagnostics with "Using sequential thinking" to get step-by-step analysis:
```
Using sequential thinking, diagnose why users in the Sales OU cannot access the file share on FILESERVER01.
```

### Using Memory for Context
Store frequently-used information in memory:
```
Remember that our production SQL server is SQLPROD01.contoso.com on port 1433, and our DHCP servers are DHCP01 and DHCP02.
```

### Combining Multiple Checks
Chain multiple operations:
```
First check if WEBSERVER01 is reachable, then get its CPU and memory usage, then list any error events from today, and finally summarize the server health.
```

### Asking for Rollback Plans
Always request rollback information for changes:
```
Show me how to add a firewall rule for port 8080, and also show the command to remove that same rule if needed.
```

---

*Prompt Library Version: 1.0.0 — December 2025*
