<#
.SYNOPSIS
    Quick server connectivity and health check
.DESCRIPTION
    Tests connectivity to one or more servers, checking ICMP, DNS, common ports,
    and optionally retrieving basic system information.
.EXAMPLE
    .\test-connectivity.ps1 -Servers "SERVER01","SERVER02" -IncludeSystemInfo
.EXAMPLE
    .\test-connectivity.ps1 -Servers (Get-Content servers.txt)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position=0)]
    [string[]]$Servers,
    
    [Parameter()]
    [int[]]$Ports = @(3389, 5985, 445),
    
    [Parameter()]
    [switch]$IncludeSystemInfo,
    
    [Parameter()]
    [switch]$ExportCsv,
    
    [Parameter()]
    [string]$OutputPath = ".\connectivity-report.csv"
)

$results = @()

foreach ($server in $Servers) {
    Write-Host "`nChecking $server..." -ForegroundColor Cyan
    
    $result = [PSCustomObject]@{
        Server = $server
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ICMP = $false
        DNS = $null
        RDP_3389 = $false
        WinRM_5985 = $false
        SMB_445 = $false
        OSVersion = $null
        LastBoot = $null
        Status = "Unknown"
    }
    
    # ICMP Test
    $result.ICMP = Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($result.ICMP) {
        Write-Host "  ✓ ICMP: Reachable" -ForegroundColor Green
    } else {
        Write-Host "  ✗ ICMP: Unreachable" -ForegroundColor Red
    }
    
    # DNS Resolution
    try {
        $dns = Resolve-DnsName -Name $server -ErrorAction Stop
        $result.DNS = $dns[0].IPAddress
        Write-Host "  ✓ DNS: $($result.DNS)" -ForegroundColor Green
    } catch {
        $result.DNS = "FAILED"
        Write-Host "  ✗ DNS: Resolution failed" -ForegroundColor Red
    }
    
    # Port Tests
    foreach ($port in $Ports) {
        $portTest = Test-NetConnection -ComputerName $server -Port $port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        $portOpen = $portTest.TcpTestSucceeded
        
        switch ($port) {
            3389 { $result.RDP_3389 = $portOpen }
            5985 { $result.WinRM_5985 = $portOpen }
            445  { $result.SMB_445 = $portOpen }
        }
        
        if ($portOpen) {
            Write-Host "  ✓ Port $port : Open" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Port $port : Closed" -ForegroundColor Yellow
        }
    }
    
    # System Info (if requested and WinRM available)
    if ($IncludeSystemInfo -and $result.WinRM_5985) {
        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $server -ErrorAction Stop
            $result.OSVersion = $os.Caption
            $result.LastBoot = $os.LastBootUpTime
            Write-Host "  ✓ OS: $($result.OSVersion)" -ForegroundColor Green
            Write-Host "  ✓ Last Boot: $($result.LastBoot)" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠ Could not retrieve system info" -ForegroundColor Yellow
        }
    }
    
    # Determine overall status
    if ($result.ICMP -and $result.WinRM_5985) {
        $result.Status = "Healthy"
    } elseif ($result.ICMP) {
        $result.Status = "Reachable (Limited)"
    } else {
        $result.Status = "Unreachable"
    }
    
    $results += $result
}

# Summary
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

$healthy = ($results | Where-Object Status -eq "Healthy").Count
$limited = ($results | Where-Object Status -eq "Reachable (Limited)").Count
$unreachable = ($results | Where-Object Status -eq "Unreachable").Count

Write-Host "  Healthy:     $healthy" -ForegroundColor Green
Write-Host "  Limited:     $limited" -ForegroundColor Yellow
Write-Host "  Unreachable: $unreachable" -ForegroundColor Red
Write-Host ""

# Export if requested
if ($ExportCsv) {
    $results | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Host "Results exported to: $OutputPath" -ForegroundColor Cyan
}

# Return results for pipeline
$results
