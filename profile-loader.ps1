<#
.SYNOPSIS
    PowerShell profile loader for Network Copilot CLI environment
.DESCRIPTION
    Source this file from your PowerShell profile to enable:
    - Environment variables for MCP servers (lazy-loaded)
    - Helpful aliases and functions for network administration
    - Integration with Copilot CLI
    
    PORTABLE: This script auto-detects its location. Just copy the copcli 
    folder anywhere and source this file - no path configuration needed.
.PARAMETER Quiet
    Suppresses all output during profile loading
.PARAMETER VerboseLoad
    Shows detailed loading information for debugging
.EXAMPLE
    # Silent mode (default) - minimal output
    . "C:\Tools\copcli\profile-loader.ps1"
.EXAMPLE
    # Completely quiet - no output at all
    . "C:\Tools\copcli\profile-loader.ps1" -Quiet
.EXAMPLE
    # Verbose mode - for debugging
    . "C:\Tools\copcli\profile-loader.ps1" -VerboseLoad
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Quiet,
    
    [Parameter()]
    [switch]$VerboseLoad
)

#region Environment Setup

# Auto-detect location - this makes the folder truly portable
# Works whether sourced directly or from $PROFILE
$script:ScriptPath = if ($MyInvocation.MyCommand.Path) {
    $MyInvocation.MyCommand.Path
} elseif ($PSCommandPath) {
    $PSCommandPath
} else {
    # Fallback for edge cases
    $null
}

# Store COPCLI_HOME in script scope and optionally in environment
if ($script:ScriptPath) {
    $script:COPCLI_HOME = Split-Path -Parent $script:ScriptPath
} elseif ($env:COPCLI_HOME) {
    $script:COPCLI_HOME = $env:COPCLI_HOME
} else {
    Write-Warning "Could not auto-detect COPCLI_HOME. Set it manually: `$env:COPCLI_HOME = 'path\to\copcli'"
    return
}

# Verify the directory exists
if (-not (Test-Path $script:COPCLI_HOME)) {
    Write-Warning "COPCLI_HOME directory not found: $script:COPCLI_HOME"
    return
}

# Set environment variable only if not already set (non-interfering)
if (-not $env:COPCLI_HOME) {
    $env:COPCLI_HOME = $script:COPCLI_HOME
}

# Initialize environment loaded flag
$global:COPCLI_ENV_LOADED = $false

# Lazy-loading function for environment variables
function script:Initialize-CopCLIEnvironment {
    <#
    .SYNOPSIS
        Lazy-loads environment variables from .env file
    .DESCRIPTION
        This function loads environment variables on-demand when they're needed,
        preventing duplicate loads and only setting variables that don't already exist.
        Uses a global flag to track loading state.
    .PARAMETER Force
        Forces reload of environment variables even if already loaded
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force
    )
    
    # Prevent duplicate loads unless forced
    if ($global:COPCLI_ENV_LOADED -and -not $Force) {
        if ($script:VerboseLoad) {
            Write-Host "  [Verbose] Environment already loaded, skipping" -ForegroundColor DarkGray
        }
        return
    }
    
    # Load .env file if it exists
    $envFile = Join-Path $script:COPCLI_HOME ".env"
    if (Test-Path $envFile) {
        $loadedCount = 0
        $skippedCount = 0
        
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim().Trim('"').Trim("'")
                
                # Only set if variable doesn't already exist (non-interfering)
                if (-not (Test-Path "env:$name")) {
                    [Environment]::SetEnvironmentVariable($name, $value, "Process")
                    $loadedCount++
                    if ($script:VerboseLoad) {
                        Write-Host "  [Verbose] Set: $name" -ForegroundColor DarkGray
                    }
                } else {
                    $skippedCount++
                    if ($script:VerboseLoad) {
                        Write-Host "  [Verbose] Skipped (already set): $name" -ForegroundColor DarkGray
                    }
                }
            }
        }
        
        if ($script:VerboseLoad) {
            Write-Host "  [Verbose] Loaded $loadedCount variable(s), skipped $skippedCount existing" -ForegroundColor DarkGray
        }
    } elseif ($script:VerboseLoad) {
        Write-Host "  [Verbose] No .env file found at: $envFile" -ForegroundColor DarkGray
    }
    
    # Mark as loaded
    $global:COPCLI_ENV_LOADED = $true
}

#endregion

#region Copilot CLI Helpers

# Quick alias for Copilot CLI
Set-Alias -Name cop -Value copilot -ErrorAction SilentlyContinue
Set-Alias -Name ai -Value copilot -ErrorAction SilentlyContinue

# Function to start Copilot CLI with AGENTS.md context
function Start-NetworkCopilot {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromRemainingArguments)]
        [string[]]$Prompt
    )
    
    # Lazy-load environment variables when needed
    Initialize-CopCLIEnvironment
    
    $agentFile = Join-Path $env:COPCLI_HOME "AGENTS.md"
    
    if ($Prompt) {
        # Direct prompt mode
        copilot $Prompt
    } else {
        # Interactive mode
        Write-Host "Starting Network Copilot CLI..." -ForegroundColor Cyan
        Write-Host "AGENTS.md: $agentFile" -ForegroundColor DarkGray
        Write-Host "Type 'exit' or Ctrl+C to quit" -ForegroundColor DarkGray
        Write-Host ""
        copilot
    }
}
Set-Alias -Name ncop -Value Start-NetworkCopilot

#endregion

#region Network Diagnostic Functions

function Test-ServerConnectivity {
    <#
    .SYNOPSIS
        Quick connectivity check for a server
    .EXAMPLE
        Test-ServerConnectivity -ComputerName "SERVER01" -Ports 80,443,3389
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$ComputerName,
        
        [Parameter(Position=1)]
        [int[]]$Ports = @(80, 443, 3389, 5985),
        
        [switch]$Quick
    )
    
    Write-Host "`n=== Connectivity Check: $ComputerName ===" -ForegroundColor Cyan
    
    # ICMP Check
    $ping = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($ping) {
        Write-Host "✓ ICMP: Reachable" -ForegroundColor Green
    } else {
        Write-Host "✗ ICMP: Unreachable" -ForegroundColor Red
    }
    
    # DNS Check
    try {
        $dns = Resolve-DnsName -Name $ComputerName -ErrorAction Stop
        Write-Host "✓ DNS: $($dns[0].IPAddress)" -ForegroundColor Green
    } catch {
        Write-Host "✗ DNS: Resolution failed" -ForegroundColor Red
    }
    
    if (-not $Quick) {
        # Port checks
        Write-Host "`nPort Status:" -ForegroundColor Yellow
        foreach ($port in $Ports) {
            $result = Test-NetConnection -ComputerName $ComputerName -Port $port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            if ($result.TcpTestSucceeded) {
                Write-Host "  ✓ Port $port : Open" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Port $port : Closed/Filtered" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
}
Set-Alias -Name tsc -Value Test-ServerConnectivity

function Get-QuickSystemInfo {
    <#
    .SYNOPSIS
        Quick system overview for local or remote computer
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$ComputerName = $env:COMPUTERNAME
    )
    
    $isRemote = $ComputerName -ne $env:COMPUTERNAME
    
    try {
        if ($isRemote) {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $ComputerName -ErrorAction Stop
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop
        } else {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
        }
        
        [PSCustomObject]@{
            ComputerName = $cs.Name
            Domain = $cs.Domain
            OS = $os.Caption
            Version = $os.Version
            LastBoot = $os.LastBootUpTime
            Uptime = (Get-Date) - $os.LastBootUpTime
            TotalRAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
            FreeRAM_GB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
            CPUs = $cs.NumberOfProcessors
            LogicalProcs = $cs.NumberOfLogicalProcessors
        }
    } catch {
        Write-Error "Failed to get system info from $ComputerName : $_"
    }
}
Set-Alias -Name sysinfo -Value Get-QuickSystemInfo

function Get-TopProcesses {
    <#
    .SYNOPSIS
        Get top processes by memory or CPU
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [ValidateSet("Memory", "CPU")]
        [string]$SortBy = "Memory",
        
        [Parameter(Position=1)]
        [int]$Top = 10,
        
        [string]$ComputerName
    )
    
    $params = @{}
    if ($ComputerName) { $params.ComputerName = $ComputerName }
    
    $processes = Get-Process @params | 
        Select-Object Name, Id, 
            @{N='Memory_MB'; E={[math]::Round($_.WorkingSet64/1MB,2)}}, 
            @{N='CPU_Sec'; E={[math]::Round($_.CPU,2)}}
    
    if ($SortBy -eq "Memory") {
        $processes | Sort-Object Memory_MB -Descending | Select-Object -First $Top
    } else {
        $processes | Sort-Object CPU_Sec -Descending | Select-Object -First $Top
    }
}
Set-Alias -Name topproc -Value Get-TopProcesses

function Get-ListeningPorts {
    <#
    .SYNOPSIS
        Show all listening TCP ports with process names
    #>
    [CmdletBinding()]
    param(
        [int]$Port
    )
    
    $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Select-Object LocalPort, 
            @{N='Process'; E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}},
            OwningProcess
    
    if ($Port) {
        $connections | Where-Object LocalPort -eq $Port
    } else {
        $connections | Sort-Object LocalPort
    }
}
Set-Alias -Name ports -Value Get-ListeningPorts

function Search-EventLog {
    <#
    .SYNOPSIS
        Quick event log search
    .EXAMPLE
        Search-EventLog -LogName System -Level Error -Hours 24
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$LogName = "System",
        
        [ValidateSet("Error", "Warning", "Information")]
        [string]$Level = "Error",
        
        [int]$Hours = 24,
        
        [int]$MaxEvents = 50
    )
    
    $levelMap = @{
        "Error" = 2
        "Warning" = 3
        "Information" = 4
    }
    
    $startTime = (Get-Date).AddHours(-$Hours)
    
    Get-WinEvent -FilterHashtable @{
        LogName = $LogName
        Level = $levelMap[$Level]
        StartTime = $startTime
    } -MaxEvents $MaxEvents -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, 
            @{N='Message'; E={$_.Message.Split("`n")[0].Substring(0, [Math]::Min(100, $_.Message.Length))}}
}
Set-Alias -Name evtlog -Value Search-EventLog

#endregion

#region Credential Helpers

function Save-ServerCredential {
    <#
    .SYNOPSIS
        Securely save credentials for a server
    .EXAMPLE
        Save-ServerCredential -Name "SQLAdmin"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Name
    )
    
    $credPath = Join-Path $env:COPCLI_HOME ".creds"
    if (-not (Test-Path $credPath)) {
        New-Item -ItemType Directory -Path $credPath -Force | Out-Null
    }
    
    $cred = Get-Credential -Message "Enter credentials for '$Name'"
    $credFile = Join-Path $credPath "$Name.xml"
    $cred | Export-Clixml -Path $credFile
    
    Write-Host "✓ Credentials saved to $credFile" -ForegroundColor Green
    Write-Host "  Note: These can only be read by your user account on this machine" -ForegroundColor DarkGray
}

function Get-ServerCredential {
    <#
    .SYNOPSIS
        Retrieve saved credentials
    .EXAMPLE
        $cred = Get-ServerCredential -Name "SQLAdmin"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Name
    )
    
    $credFile = Join-Path $env:COPCLI_HOME ".creds\$Name.xml"
    
    if (Test-Path $credFile) {
        Import-Clixml -Path $credFile
    } else {
        Write-Warning "No saved credential found for '$Name'"
        Write-Host "Use Save-ServerCredential -Name '$Name' to create one" -ForegroundColor Yellow
    }
}

#endregion

#region Quick Access Functions

function Edit-Agents {
    <# Open AGENTS.md in default editor #>
    $agentFile = Join-Path $env:COPCLI_HOME "AGENTS.md"
    if (Get-Command code -ErrorAction SilentlyContinue) {
        code $agentFile
    } else {
        notepad $agentFile
    }
}

function Edit-MCPConfig {
    <# Open mcp-config.json in default editor #>
    $mcpFile = Join-Path $env:COPCLI_HOME "mcp-config.json"
    if (Get-Command code -ErrorAction SilentlyContinue) {
        code $mcpFile
    } else {
        notepad $mcpFile
    }
}

function Show-Prompts {
    <# Display prompt examples #>
    $promptFile = Join-Path $env:COPCLI_HOME "PROMPTS.md"
    if (Test-Path $promptFile) {
        Get-Content $promptFile | Out-Host -Paging
    }
}

#endregion

#region Status Display

function Show-CopCLIStatus {
    <# Show status of Copilot CLI environment #>
    
    # Lazy-load environment variables when status is requested
    Initialize-CopCLIEnvironment
    
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           Network Copilot CLI Environment                    ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Check Copilot CLI
    $copilotInstalled = Get-Command copilot -ErrorAction SilentlyContinue
    if ($copilotInstalled) {
        $version = (copilot --version 2>$null) -join ""
        Write-Host "  Copilot CLI: " -NoNewline; Write-Host "✓ Installed ($version)" -ForegroundColor Green
    } else {
        Write-Host "  Copilot CLI: " -NoNewline; Write-Host "✗ Not found" -ForegroundColor Red
    }
    
    # Check environment variables
    Write-Host "  COPCLI_HOME: " -NoNewline
    if ($env:COPCLI_HOME) {
        Write-Host $env:COPCLI_HOME -ForegroundColor Green
    } else {
        Write-Host "Not set" -ForegroundColor Yellow
    }
    
    Write-Host "  GITHUB_TOKEN: " -NoNewline
    if ($env:GITHUB_TOKEN) {
        Write-Host "✓ Set" -ForegroundColor Green
    } else {
        Write-Host "✗ Not set" -ForegroundColor Yellow
    }
    
    Write-Host "  TAVILY_API_KEY: " -NoNewline
    if ($env:TAVILY_API_KEY) {
        Write-Host "✓ Set" -ForegroundColor Green
    } else {
        Write-Host "✗ Not set (web search disabled)" -ForegroundColor Yellow
    }
    
    # Check Node.js for MCP servers
    $nodeInstalled = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeInstalled) {
        $nodeVersion = node --version
        Write-Host "  Node.js: " -NoNewline; Write-Host "✓ $nodeVersion" -ForegroundColor Green
    } else {
        Write-Host "  Node.js: " -NoNewline; Write-Host "✗ Not found (MCP servers require Node.js)" -ForegroundColor Red
    }
    
    # Check key files
    $agentsExists = Test-Path (Join-Path $env:COPCLI_HOME "AGENTS.md")
    $mcpExists = Test-Path (Join-Path $env:COPCLI_HOME "mcp-config.json")
    
    Write-Host "`n  Config Files:"
    Write-Host "    AGENTS.md: " -NoNewline
    if ($agentsExists) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "✗" -ForegroundColor Red }
    Write-Host "    mcp-config.json: " -NoNewline
    if ($mcpExists) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "✗" -ForegroundColor Red }
    
    Write-Host "`n  Quick Commands:"
    Write-Host "    ncop / ai      - Start Copilot CLI"
    Write-Host "    tsc <host>     - Test server connectivity"
    Write-Host "    sysinfo        - Quick system info"
    Write-Host "    topproc        - Top processes by memory"
    Write-Host "    ports          - Show listening ports"
    Write-Host "    evtlog         - Search event logs"
    Write-Host ""
}

#endregion

# Show loading status based on parameters
if (-not $Quiet) {
    if ($VerboseLoad) {
        Write-Host "✓ Network Copilot CLI loaded (verbose mode)" -ForegroundColor Green
        Write-Host "  Environment variables will be lazy-loaded when needed" -ForegroundColor DarkGray
        Write-Host "  Type 'Show-CopCLIStatus' for full environment info" -ForegroundColor DarkGray
    } else {
        # Minimal output in default mode
        Write-Host "✓ Network Copilot CLI ready" -ForegroundColor DarkGray
    }
}
