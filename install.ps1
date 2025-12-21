<#
.SYNOPSIS
    One-time installer for Network Copilot CLI
.DESCRIPTION
    Run this script ONCE from wherever you want the copcli folder to live.
    It will:
    1. Auto-detect the current location
    2. Add the loader to your PowerShell profile (idempotent - safe to re-run)
    3. Optionally install required npm packages
    
    After running, just open a new PowerShell window and you're ready.
.EXAMPLE
    # From the copcli folder:
    .\install.ps1
    
    # Full install (Copilot CLI + MCP servers):
    .\install.ps1 -Full
    
    # Just Copilot CLI (prerelease):
    .\install.ps1 -InstallCopilot
    
    # Just MCP servers:
    .\install.ps1 -InstallMCP
    
    # Uninstall:
    .\install.ps1 -Uninstall
#>

[CmdletBinding()]
param(
    [switch]$InstallMCP,
    [switch]$InstallCopilot,
    [switch]$Full,          # Alias for -InstallCopilot -InstallMCP
    [switch]$Uninstall,
    [switch]$Force,
    [switch]$SkipChecks     # Skip prerequisite checks (for debugging)
)

# ============================================
# CONFIGURATION
# ============================================
$MIN_PS_VERSION = [Version]"5.1"
$MIN_NODE_VERSION = [Version]"18.0.0"
$NPM_TIMEOUT_SECONDS = 120

# ============================================
# HELPER FUNCTIONS
# ============================================
function Write-Step {
    param([string]$Message, [string]$Status = "...")
    Write-Host "  " -NoNewline
    switch ($Status) {
        "OK"    { Write-Host "[OK]" -ForegroundColor Green -NoNewline }
        "SKIP"  { Write-Host "[--]" -ForegroundColor Yellow -NoNewline }
        "FAIL"  { Write-Host "[X]" -ForegroundColor Red -NoNewline }
        "WARN"  { Write-Host "[!]" -ForegroundColor Yellow -NoNewline }
        "INFO"  { Write-Host "[i]" -ForegroundColor Cyan -NoNewline }
        default { Write-Host "[>]" -ForegroundColor Cyan -NoNewline }
    }
    Write-Host " $Message"
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-InternetConnection {
    try {
        $null = Test-Connection -ComputerName "registry.npmjs.org" -Count 1 -Quiet -ErrorAction Stop
        return $true
    } catch {
        # Fallback: try a simple TCP connection
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.ConnectAsync("registry.npmjs.org", 443).Wait(3000) | Out-Null
            $result = $tcp.Connected
            $tcp.Close()
            return $result
        } catch {
            return $false
        }
    }
}

function Get-NodeVersion {
    try {
        $versionStr = (node --version 2>$null) -replace '^v', ''
        return [Version]$versionStr
    } catch {
        return $null
    }
}

function Install-NpmPackageWithTimeout {
    param(
        [string]$Package,
        [int]$TimeoutSeconds = 120
    )
    
    $job = Start-Job -ScriptBlock {
        param($pkg)
        npm install -g $pkg 2>&1
    } -ArgumentList $Package
    
    $completed = Wait-Job $job -Timeout $TimeoutSeconds
    
    if ($completed) {
        $output = Receive-Job $job
        Remove-Job $job -Force
        return @{ Success = $true; Output = $output }
    } else {
        Stop-Job $job -ErrorAction SilentlyContinue
        Remove-Job $job -Force
        return @{ Success = $false; Output = "Timeout after ${TimeoutSeconds}s" }
    }
}

function Test-ProfileWritable {
    param([string]$ProfilePath)
    
    try {
        # Ensure parent directory exists
        $parentDir = Split-Path -Parent $ProfilePath
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        
        # Test write access
        if (Test-Path $ProfilePath) {
            $testFile = $ProfilePath
        } else {
            $testFile = Join-Path $parentDir ".write-test-$(Get-Random).tmp"
        }
        
        [IO.File]::OpenWrite($testFile).Close()
        if ($testFile -ne $ProfilePath) {
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        }
        return $true
    } catch {
        return $false
    }
}

# ============================================
# INITIALIZATION
# ============================================
$ErrorActionPreference = "Stop"

# -Full is shorthand for everything
if ($Full) {
    $InstallCopilot = $true
    $InstallMCP = $true
}

# Detect where this script lives
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) {
    $ScriptDir = $PWD.Path
}
$ProfileLoader = Join-Path $ScriptDir "profile-loader.ps1"

# The line we'll add to $PROFILE
$ProfileLine = ". `"$ProfileLoader`""

# Track overall success
$installSuccess = $true
$warnings = @()

# ============================================
# PREREQUISITE CHECKS
# ============================================
function Test-Prerequisites {
    $checks = @()
    
    # PowerShell version
    Write-Step "PowerShell version: $($PSVersionTable.PSVersion)"
    if ($PSVersionTable.PSVersion -lt $MIN_PS_VERSION) {
        $checks += @{ Pass = $false; Message = "PowerShell $MIN_PS_VERSION+ required (found $($PSVersionTable.PSVersion))" }
    } else {
        $checks += @{ Pass = $true; Message = "PowerShell version OK" }
    }
    
    # Execution policy
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -eq "Restricted") {
        Write-Step "Execution policy is Restricted - scripts may not run" "WARN"
        $checks += @{ Pass = $false; Message = "Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" }
    } else {
        Write-Step "Execution policy: $policy" "OK"
        $checks += @{ Pass = $true; Message = "Execution policy OK" }
    }
    
    # Profile writable
    if (-not (Test-ProfileWritable $PROFILE)) {
        $checks += @{ Pass = $false; Message = "Cannot write to profile: $PROFILE" }
        Write-Step "Profile not writable: $PROFILE" "FAIL"
    } else {
        $checks += @{ Pass = $true; Message = "Profile writable" }
    }
    
    # Node.js (only required for -InstallCopilot or -InstallMCP)
    if ($InstallCopilot -or $InstallMCP) {
        $nodeVersion = Get-NodeVersion
        if (-not $nodeVersion) {
            Write-Step "Node.js not found" "FAIL"
            Write-Host "      Download: https://nodejs.org/" -ForegroundColor Gray
            $checks += @{ Pass = $false; Message = "Node.js not installed" }
        } elseif ($nodeVersion -lt $MIN_NODE_VERSION) {
            Write-Step "Node.js $nodeVersion found, but $MIN_NODE_VERSION+ required" "FAIL"
            $checks += @{ Pass = $false; Message = "Node.js too old" }
        } else {
            Write-Step "Node.js: v$nodeVersion" "OK"
            $checks += @{ Pass = $true; Message = "Node.js OK" }
        }
        
        # npm
        $npmInstalled = Get-Command npm -ErrorAction SilentlyContinue
        if (-not $npmInstalled) {
            Write-Step "npm not found in PATH" "FAIL"
            $checks += @{ Pass = $false; Message = "npm not in PATH" }
        } else {
            $npmVersion = (npm --version 2>$null)
            Write-Step "npm: v$npmVersion" "OK"
            $checks += @{ Pass = $true; Message = "npm OK" }
        }
        
        # Internet connection
        Write-Step "Checking internet connection..."
        if (-not (Test-InternetConnection)) {
            Write-Step "Cannot reach npm registry - check internet connection" "FAIL"
            $checks += @{ Pass = $false; Message = "No internet connection" }
        } else {
            Write-Step "Internet connection OK" "OK"
            $checks += @{ Pass = $true; Message = "Internet OK" }
        }
    }
    
    # Return overall result
    $failed = $checks | Where-Object { -not $_.Pass }
    return @{
        AllPassed = ($failed.Count -eq 0)
        Failed = $failed
        Checks = $checks
    }
}

# ============================================
# UNINSTALL
# ============================================
if ($Uninstall) {
    Write-Host "`n=====================================================================" -ForegroundColor Red
    Write-Host "           Uninstalling Network Copilot CLI                          " -ForegroundColor Red
    Write-Host "=====================================================================`n" -ForegroundColor Red
    
    if (Test-Path $PROFILE) {
        try {
            $content = Get-Content $PROFILE -Raw -ErrorAction Stop
            if ($content -match [regex]::Escape($ProfileLoader)) {
                # Remove the entire block including markers
                $pattern = "(?s)# >>> Network Copilot CLI.*?# <<< Network Copilot CLI <<<\r?\n?"
                $newContent = $content -replace $pattern, ""
                # Fallback: remove just the line
                if ($newContent -match [regex]::Escape($ProfileLoader)) {
                    $newContent = ($content -split "`n" | Where-Object { $_ -notmatch [regex]::Escape($ProfileLoader) }) -join "`n"
                }
                $newContent | Set-Content $PROFILE -ErrorAction Stop
                Write-Step "Removed from PowerShell profile" "OK"
            } else {
                Write-Step "Not found in PowerShell profile" "SKIP"
            }
        } catch {
            Write-Step "Failed to modify profile: $_" "FAIL"
        }
    } else {
        Write-Step "No profile file found" "SKIP"
    }
    
    Write-Host "`nUninstall complete. The copcli folder remains - delete it manually if desired." -ForegroundColor Yellow
    Write-Host "Folder: $ScriptDir`n" -ForegroundColor Gray
    return
}

# ============================================
# INSTALL
# ============================================
Write-Host "`n=====================================================================" -ForegroundColor Cyan
Write-Host "           Installing Network Copilot CLI                            " -ForegroundColor Cyan
Write-Host "=====================================================================`n" -ForegroundColor Cyan

Write-Host "Location: $ScriptDir" -ForegroundColor Gray
Write-Host ""

# ============================================
# STEP 0: Prerequisite Checks
# ============================================
if (-not $SkipChecks) {
    Write-Host "Checking prerequisites..." -ForegroundColor Cyan
    $prereqResult = Test-Prerequisites
    
    if (-not $prereqResult.AllPassed) {
        Write-Host "`n  Some checks failed:" -ForegroundColor Red
        foreach ($fail in $prereqResult.Failed) {
            Write-Host "    - $($fail.Message)" -ForegroundColor Red
        }
        
        if (-not $Force) {
            Write-Host "`n  Use -Force to continue anyway, or fix the issues above." -ForegroundColor Yellow
            Write-Host "  Use -SkipChecks to skip all prerequisite checks.`n" -ForegroundColor Gray
            return
        } else {
            Write-Host "`n  Continuing anyway due to -Force flag..." -ForegroundColor Yellow
        }
    }
    Write-Host ""
}

# Step 1: Verify files exist
Write-Step "Checking required files"
$requiredFiles = @("profile-loader.ps1", "AGENTS.md", "mcp-config.json")
$missing = $requiredFiles | Where-Object { -not (Test-Path (Join-Path $ScriptDir $_)) }
if ($missing) {
    Write-Step "Missing files: $($missing -join ', ')" "FAIL"
    Write-Host "`n  Make sure you're running from the copcli folder." -ForegroundColor Red
    Write-Host "  Expected location: $ScriptDir`n" -ForegroundColor Gray
    return
}
Write-Step "All required files present" "OK"

# Step 2: Create $PROFILE directory and file if needed
Write-Step "Checking PowerShell profile"
try {
    $profileDir = Split-Path -Parent $PROFILE
    if (-not (Test-Path $profileDir)) {
        New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        Write-Step "Created profile directory: $profileDir" "OK"
    }
    
    if (-not (Test-Path $PROFILE)) {
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
        Write-Step "Created new profile: $PROFILE" "OK"
    } else {
        Write-Step "Profile exists: $PROFILE" "OK"
    }
} catch {
    Write-Step "Failed to create profile: $_" "FAIL"
    $installSuccess = $false
    $warnings += "Could not create PowerShell profile"
}

# Step 3: Add loader to profile (idempotent)
Write-Step "Adding loader to profile"
try {
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($profileContent -and $profileContent -match [regex]::Escape($ProfileLoader)) {
        Write-Step "Already in profile (no changes needed)" "SKIP"
    } else {
        # Check if profile is locked
        try {
            $stream = [IO.File]::Open($PROFILE, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::None)
            $stream.Close()
        } catch {
            Write-Step "Profile file is locked by another process" "FAIL"
            Write-Host "      Close other PowerShell windows or editors and try again." -ForegroundColor Gray
            $installSuccess = $false
            $warnings += "Profile file locked"
        }
        
        # Add with a comment marker for easy identification
        $block = @"

# >>> Network Copilot CLI (added by install.ps1) >>>
$ProfileLine
# <<< Network Copilot CLI <<<
"@
        Add-Content -Path $PROFILE -Value $block -ErrorAction Stop
        Write-Step "Added to profile" "OK"
    }
} catch {
    Write-Step "Failed to modify profile: $_" "FAIL"
    $installSuccess = $false
    $warnings += "Could not modify profile"
}

# Step 4: Create .env from example if needed
Write-Step "Checking .env file"
$envFile = Join-Path $ScriptDir ".env"
$envExample = Join-Path $ScriptDir ".env.example"
if (-not (Test-Path $envFile) -and (Test-Path $envExample)) {
    Copy-Item $envExample $envFile
    Write-Step "Created .env from template (edit to add your API keys)" "OK"
} elseif (Test-Path $envFile) {
    Write-Step ".env already exists" "SKIP"
} else {
    Write-Step "No .env.example found" "SKIP"
}

# Step 5: Install or check Copilot CLI
$copilotInstalled = Get-Command copilot -ErrorAction SilentlyContinue

if ($InstallCopilot) {
    Write-Host "`nInstalling GitHub Copilot CLI (prerelease)..." -ForegroundColor Cyan
    
    # Node.js was already checked in prerequisites, but double-check
    $nodeInstalled = Get-Command node -ErrorAction SilentlyContinue
    $npmInstalled = Get-Command npm -ErrorAction SilentlyContinue
    
    if (-not $nodeInstalled -or -not $npmInstalled) {
        Write-Step "Node.js/npm not available - skipping Copilot CLI install" "FAIL"
        $warnings += "Could not install Copilot CLI (Node.js missing)"
    } else {
        Write-Step "Installing @github/copilot@prerelease (timeout: ${NPM_TIMEOUT_SECONDS}s)..."
        $result = Install-NpmPackageWithTimeout -Package "@github/copilot@prerelease" -TimeoutSeconds $NPM_TIMEOUT_SECONDS
        
        if ($result.Success) {
            # Verify it actually installed
            $copilotInstalled = Get-Command copilot -ErrorAction SilentlyContinue
            if ($copilotInstalled) {
                $version = (copilot --version 2>$null) -join ""
                Write-Step "Copilot CLI installed: $version" "OK"
                Write-Host "`n    [!] Remember to authenticate:" -ForegroundColor Yellow
                Write-Host "        copilot auth login" -ForegroundColor Gray
            } else {
                Write-Step "Package installed but 'copilot' command not found - check PATH" "WARN"
                $warnings += "Copilot CLI not in PATH after install"
            }
        } else {
            Write-Step "Failed: $($result.Output)" "FAIL"
            Write-Host "      Try manually: npm install -g @github/copilot@prerelease" -ForegroundColor Gray
            $warnings += "Could not install Copilot CLI"
            $installSuccess = $false
        }
    }
} else {
    Write-Step "Checking Copilot CLI installation"
    if ($copilotInstalled) {
        $version = (copilot --version 2>$null) -join ""
        Write-Step "Copilot CLI installed: $version" "OK"
    } else {
        Write-Step "Copilot CLI not found - run with -InstallCopilot or -Full to install" "SKIP"
    }
}

# Step 6: Deploy mcp-config.json to ~/.copilot/
Write-Step "Deploying MCP configuration to Copilot CLI"
$copilotDir = Join-Path $env:USERPROFILE ".copilot"
$sourceMcpConfig = Join-Path $ScriptDir "mcp-config.json"
$targetMcpConfig = Join-Path $copilotDir "mcp-config.json"

try {
    # Create ~/.copilot if it doesn't exist
    if (-not (Test-Path $copilotDir)) {
        New-Item -Path $copilotDir -ItemType Directory -Force | Out-Null
        Write-Step "Created $copilotDir" "OK"
    }
    
    # Check if target exists and is different
    if (Test-Path $targetMcpConfig) {
        $sourceHash = (Get-FileHash $sourceMcpConfig -Algorithm MD5).Hash
        $targetHash = (Get-FileHash $targetMcpConfig -Algorithm MD5).Hash
        
        if ($sourceHash -eq $targetHash) {
            Write-Step "MCP config already up-to-date" "SKIP"
        } else {
            # Backup existing
            $backupPath = "$targetMcpConfig.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $targetMcpConfig $backupPath -Force
            Write-Step "Backed up existing config to: $backupPath" "INFO"
            
            Copy-Item $sourceMcpConfig $targetMcpConfig -Force
            Write-Step "Updated MCP config at $targetMcpConfig" "OK"
        }
    } else {
        Copy-Item $sourceMcpConfig $targetMcpConfig -Force
        Write-Step "Deployed MCP config to $targetMcpConfig" "OK"
    }
} catch {
    Write-Step "Failed to deploy MCP config: $_" "FAIL"
    $warnings += "Could not deploy mcp-config.json to ~/.copilot/"
}

# Step 7: Optional MCP npm package installation
if ($InstallMCP) {
    Write-Host "`nInstalling MCP servers (npm packages)..." -ForegroundColor Cyan
    Write-Host "  (timeout: ${NPM_TIMEOUT_SECONDS}s per package)" -ForegroundColor Gray
    
    $mcpPackages = @(
        "@modelcontextprotocol/server-sequential-thinking",
        "@modelcontextprotocol/server-memory",
        "@modelcontextprotocol/server-filesystem",
        "@modelcontextprotocol/server-github",
        "@alxspiker/windows-command-line-mcp",
        "console-automation-mcp"
    )
    
    $mcpSuccessCount = 0
    $mcpFailCount = 0
    
    foreach ($pkg in $mcpPackages) {
        Write-Step "Installing $pkg"
        $result = Install-NpmPackageWithTimeout -Package $pkg -TimeoutSeconds $NPM_TIMEOUT_SECONDS
        if ($result.Success) {
            Write-Step "$pkg" "OK"
            $mcpSuccessCount++
        } else {
            Write-Step "$pkg ($($result.Output))" "FAIL"
            $mcpFailCount++
            $warnings += "Failed to install $pkg"
        }
    }
    
    Write-Host "`n  MCP Summary: $mcpSuccessCount succeeded, $mcpFailCount failed" -ForegroundColor $(if ($mcpFailCount -eq 0) { "Green" } else { "Yellow" })
    
    # Windows-MCP requires Python + uv
    Write-Host "`n  Note: Windows-MCP requires Python 3.13+ and uv:" -ForegroundColor Yellow
    Write-Host "    pip install uv && pip install windows-mcp" -ForegroundColor Gray
    
    if ($mcpFailCount -gt 0) {
        $installSuccess = $false
    }
}

# ============================================
# SUMMARY
# ============================================
Write-Host ""
if ($installSuccess -and $warnings.Count -eq 0) {
    Write-Host "=====================================================================" -ForegroundColor Green
    Write-Host "  Installation Complete!                                             " -ForegroundColor Green
    Write-Host "=====================================================================" -ForegroundColor Green
} elseif ($installSuccess) {
    Write-Host "=====================================================================" -ForegroundColor Yellow
    Write-Host "  Installation Complete (with warnings)                              " -ForegroundColor Yellow
    Write-Host "=====================================================================" -ForegroundColor Yellow
} else {
    Write-Host "=====================================================================" -ForegroundColor Red
    Write-Host "  Installation Finished (some steps failed)                          " -ForegroundColor Red
    Write-Host "=====================================================================" -ForegroundColor Red
}

if ($warnings.Count -gt 0) {
    Write-Host "`n  Warnings:" -ForegroundColor Yellow
    foreach ($warn in $warnings) {
        Write-Host "    - $warn" -ForegroundColor Yellow
    }
}

Write-Host "`n  Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open a NEW PowerShell window (or run: . `$PROFILE)"
Write-Host "  2. Run 'Show-CopCLIStatus' to verify installation"
Write-Host "  3. Run 'copilot' then type '/login' inside to authenticate"
Write-Host "  4. (Optional) Edit .env for Tavily/GitHub API keys if using those MCP servers"
Write-Host "  5. Run 'ncop' or 'copilot' to start"

$copilotInstalled = Get-Command copilot -ErrorAction SilentlyContinue
if (-not $copilotInstalled) {
    Write-Host "`n  [!] Copilot CLI not installed. Run again with -Full or -InstallCopilot:" -ForegroundColor Yellow
    Write-Host "      .\install.ps1 -Full" -ForegroundColor Gray
    Write-Host "      Then: copilot auth login" -ForegroundColor Gray
}

Write-Host "`n  Install location: $ScriptDir" -ForegroundColor Gray
Write-Host ""
