<#
.SYNOPSIS
    Comprehensive server health check
.DESCRIPTION
    Performs health checks on Windows servers including:
    - System resources (CPU, memory, disk)
    - Critical services status
    - Recent error events
    - Network connectivity
.EXAMPLE
    .\server-health-check.ps1 -ComputerName "SERVER01"
.EXAMPLE
    .\server-health-check.ps1 -ComputerName "SERVER01","SERVER02" -ExportHtml
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position=0)]
    [string[]]$ComputerName,
    
    [Parameter()]
    [string[]]$CriticalServices = @("W3SVC", "MSSQLSERVER", "Spooler", "WinRM"),
    
    [Parameter()]
    [int]$DiskThresholdPercent = 20,
    
    [Parameter()]
    [int]$MemoryThresholdPercent = 20,
    
    [Parameter()]
    [int]$EventHours = 24,
    
    [Parameter()]
    [switch]$ExportHtml,
    
    [Parameter()]
    [string]$OutputPath = ".\health-report.html"
)

function Get-ServerHealth {
    param([string]$Server)
    
    $health = [PSCustomObject]@{
        ComputerName = $Server
        Timestamp = Get-Date
        IsReachable = $false
        CPUPercent = $null
        MemoryUsedPercent = $null
        MemoryFreeGB = $null
        DiskStatus = @()
        ServiceStatus = @()
        RecentErrors = @()
        OverallHealth = "Unknown"
        Issues = @()
    }
    
    # Check if reachable
    if (-not (Test-Connection -ComputerName $Server -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        $health.OverallHealth = "Unreachable"
        $health.Issues += "Server is not responding to ping"
        return $health
    }
    $health.IsReachable = $true
    
    try {
        # CPU Usage
        $cpu = Get-CimInstance -ClassName Win32_Processor -ComputerName $Server -ErrorAction Stop |
            Measure-Object -Property LoadPercentage -Average
        $health.CPUPercent = [math]::Round($cpu.Average, 1)
        
        # Memory
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $Server -ErrorAction Stop
        $totalMem = $os.TotalVisibleMemorySize / 1MB
        $freeMem = $os.FreePhysicalMemory / 1MB
        $health.MemoryFreeGB = [math]::Round($freeMem, 2)
        $health.MemoryUsedPercent = [math]::Round((($totalMem - $freeMem) / $totalMem) * 100, 1)
        
        if ((100 - $health.MemoryUsedPercent) -lt $MemoryThresholdPercent) {
            $health.Issues += "Low memory: $($health.MemoryFreeGB) GB free"
        }
        
        # Disk Space
        $disks = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $Server -Filter "DriveType=3" -ErrorAction Stop
        foreach ($disk in $disks) {
            $freePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
            $diskInfo = [PSCustomObject]@{
                Drive = $disk.DeviceID
                SizeGB = [math]::Round($disk.Size / 1GB, 1)
                FreeGB = [math]::Round($disk.FreeSpace / 1GB, 1)
                FreePercent = $freePercent
                Status = if ($freePercent -lt $DiskThresholdPercent) { "Warning" } else { "OK" }
            }
            $health.DiskStatus += $diskInfo
            
            if ($freePercent -lt $DiskThresholdPercent) {
                $health.Issues += "Low disk space on $($disk.DeviceID): $($diskInfo.FreeGB) GB free ($freePercent%)"
            }
        }
        
        # Services
        foreach ($svcName in $CriticalServices) {
            try {
                $svc = Get-Service -ComputerName $Server -Name $svcName -ErrorAction Stop
                $svcInfo = [PSCustomObject]@{
                    Name = $svc.Name
                    DisplayName = $svc.DisplayName
                    Status = $svc.Status.ToString()
                    StartType = $svc.StartType.ToString()
                }
                $health.ServiceStatus += $svcInfo
                
                if ($svc.Status -ne "Running" -and $svc.StartType -eq "Automatic") {
                    $health.Issues += "Service not running: $($svc.DisplayName)"
                }
            } catch {
                # Service doesn't exist on this server - skip
            }
        }
        
        # Recent Errors
        try {
            $startTime = (Get-Date).AddHours(-$EventHours)
            $errors = Invoke-Command -ComputerName $Server -ScriptBlock {
                param($start)
                Get-WinEvent -FilterHashtable @{LogName='System','Application'; Level=2; StartTime=$start} -MaxEvents 10 -ErrorAction SilentlyContinue |
                    Select-Object TimeCreated, LogName, Id, @{N='Message';E={$_.Message.Split("`n")[0].Substring(0, [Math]::Min(100, $_.Message.Length))}}
            } -ArgumentList $startTime -ErrorAction Stop
            
            $health.RecentErrors = $errors
            
            if ($errors.Count -gt 5) {
                $health.Issues += "$($errors.Count) error events in last $EventHours hours"
            }
        } catch {
            # Could not retrieve events
        }
        
        # Determine overall health
        if ($health.Issues.Count -eq 0) {
            $health.OverallHealth = "Healthy"
        } elseif ($health.Issues.Count -le 2) {
            $health.OverallHealth = "Warning"
        } else {
            $health.OverallHealth = "Critical"
        }
        
    } catch {
        $health.OverallHealth = "Error"
        $health.Issues += "Error collecting data: $_"
    }
    
    return $health
}

# Main execution
$allHealth = @()

foreach ($server in $ComputerName) {
    Write-Host "`nChecking $server..." -ForegroundColor Cyan
    $health = Get-ServerHealth -Server $server
    $allHealth += $health
    
    # Display results
    $color = switch ($health.OverallHealth) {
        "Healthy" { "Green" }
        "Warning" { "Yellow" }
        "Critical" { "Red" }
        default { "Gray" }
    }
    
    Write-Host "  Status: $($health.OverallHealth)" -ForegroundColor $color
    
    if ($health.CPUPercent) {
        Write-Host "  CPU: $($health.CPUPercent)%" -ForegroundColor Gray
    }
    if ($health.MemoryUsedPercent) {
        Write-Host "  Memory Used: $($health.MemoryUsedPercent)% (Free: $($health.MemoryFreeGB) GB)" -ForegroundColor Gray
    }
    
    foreach ($disk in $health.DiskStatus) {
        $diskColor = if ($disk.Status -eq "Warning") { "Yellow" } else { "Gray" }
        Write-Host "  $($disk.Drive) $($disk.FreePercent)% free ($($disk.FreeGB) GB)" -ForegroundColor $diskColor
    }
    
    foreach ($issue in $health.Issues) {
        Write-Host "  ⚠ $issue" -ForegroundColor Yellow
    }
}

# Summary
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "HEALTH SUMMARY" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

$allHealth | Format-Table ComputerName, OverallHealth, CPUPercent, MemoryUsedPercent, @{N='Issues';E={$_.Issues.Count}} -AutoSize

# Export HTML if requested
if ($ExportHtml) {
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Server Health Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        .healthy { background-color: #d4edda; }
        .warning { background-color: #fff3cd; }
        .critical { background-color: #f8d7da; }
        .unreachable { background-color: #e2e3e5; }
    </style>
</head>
<body>
    <h1>Server Health Report</h1>
    <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    <table>
        <tr>
            <th>Server</th>
            <th>Status</th>
            <th>CPU %</th>
            <th>Memory Used %</th>
            <th>Issues</th>
        </tr>
        $($allHealth | ForEach-Object {
            $class = $_.OverallHealth.ToLower()
            "<tr class='$class'><td>$($_.ComputerName)</td><td>$($_.OverallHealth)</td><td>$($_.CPUPercent)</td><td>$($_.MemoryUsedPercent)</td><td>$($_.Issues -join '<br>')</td></tr>"
        })
    </table>
</body>
</html>
"@
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "`nHTML report saved to: $OutputPath" -ForegroundColor Cyan
}

# Return results
$allHealth
