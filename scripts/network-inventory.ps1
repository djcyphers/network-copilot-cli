<#
.SYNOPSIS
    Generate network infrastructure inventory
.DESCRIPTION
    Collects inventory information from:
    - Active Directory computer accounts
    - DHCP leases
    - DNS records
    Exports to CSV for documentation/auditing.
.EXAMPLE
    .\network-inventory.ps1 -ADFilter "Name -like 'SRV*'"
.EXAMPLE
    .\network-inventory.ps1 -DHCPServer "DHCP01" -DNSServer "DC01" -Zone "contoso.com"
#>

[CmdletBinding(DefaultParameterSetName='AD')]
param(
    [Parameter(ParameterSetName='AD')]
    [string]$ADFilter = "*",
    
    [Parameter(ParameterSetName='DHCP')]
    [string]$DHCPServer,
    
    [Parameter(ParameterSetName='DHCP')]
    [string]$ScopeId,
    
    [Parameter(ParameterSetName='DNS')]
    [string]$DNSServer,
    
    [Parameter(ParameterSetName='DNS')]
    [string]$Zone,
    
    [Parameter()]
    [switch]$TestConnectivity,
    
    [Parameter()]
    [string]$ExportPath = ".\network-inventory.csv"
)

$inventory = @()

# Active Directory Computer Inventory
if ($PSCmdlet.ParameterSetName -eq 'AD' -or (-not $DHCPServer -and -not $DNSServer)) {
    Write-Host "`nCollecting Active Directory computer inventory..." -ForegroundColor Cyan
    
    try {
        $adParams = @{
            Filter = $ADFilter
            Properties = @('IPv4Address', 'OperatingSystem', 'OperatingSystemVersion', 'LastLogonDate', 'Created', 'Description')
        }
        
        $computers = Get-ADComputer @adParams -ErrorAction Stop
        
        foreach ($computer in $computers) {
            $item = [PSCustomObject]@{
                Source = "ActiveDirectory"
                Name = $computer.Name
                DNSHostName = $computer.DNSHostName
                IPv4Address = $computer.IPv4Address
                OS = $computer.OperatingSystem
                OSVersion = $computer.OperatingSystemVersion
                LastLogon = $computer.LastLogonDate
                Created = $computer.Created
                Enabled = $computer.Enabled
                Description = $computer.Description
                OU = ($computer.DistinguishedName -split ',', 2)[1]
                IsReachable = $null
            }
            
            if ($TestConnectivity -and $computer.IPv4Address) {
                $item.IsReachable = Test-Connection -ComputerName $computer.IPv4Address -Count 1 -Quiet -ErrorAction SilentlyContinue
                $status = if ($item.IsReachable) { "✓" } else { "✗" }
                Write-Host "  $status $($computer.Name) - $($computer.IPv4Address)" -ForegroundColor $(if ($item.IsReachable) { "Green" } else { "Red" })
            } else {
                Write-Host "  $($computer.Name) - $($computer.IPv4Address)" -ForegroundColor Gray
            }
            
            $inventory += $item
        }
        
        Write-Host "  Found $($computers.Count) computers in AD" -ForegroundColor Green
        
    } catch {
        Write-Warning "Failed to query Active Directory: $_"
    }
}

# DHCP Lease Inventory
if ($DHCPServer) {
    Write-Host "`nCollecting DHCP lease inventory from $DHCPServer..." -ForegroundColor Cyan
    
    try {
        $scopeParams = @{
            ComputerName = $DHCPServer
        }
        if ($ScopeId) {
            $scopeParams.ScopeId = $ScopeId
        }
        
        $leases = Get-DhcpServerv4Lease @scopeParams -ErrorAction Stop
        
        foreach ($lease in $leases) {
            $item = [PSCustomObject]@{
                Source = "DHCP"
                Name = $lease.HostName
                DNSHostName = $lease.HostName
                IPv4Address = $lease.IPAddress.ToString()
                MACAddress = $lease.ClientId
                ScopeId = $lease.ScopeId.ToString()
                LeaseExpiry = $lease.LeaseExpiryTime
                AddressState = $lease.AddressState
                ServerHost = $DHCPServer
                IsReachable = $null
            }
            
            if ($TestConnectivity) {
                $item.IsReachable = Test-Connection -ComputerName $lease.IPAddress -Count 1 -Quiet -ErrorAction SilentlyContinue
            }
            
            Write-Host "  $($lease.HostName) - $($lease.IPAddress)" -ForegroundColor Gray
            $inventory += $item
        }
        
        Write-Host "  Found $($leases.Count) DHCP leases" -ForegroundColor Green
        
    } catch {
        Write-Warning "Failed to query DHCP server: $_"
    }
}

# DNS Record Inventory
if ($DNSServer -and $Zone) {
    Write-Host "`nCollecting DNS records from $DNSServer for zone $Zone..." -ForegroundColor Cyan
    
    try {
        $records = Get-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $Zone -RRType A -ErrorAction Stop
        
        foreach ($record in $records) {
            $item = [PSCustomObject]@{
                Source = "DNS"
                Name = $record.HostName
                DNSHostName = "$($record.HostName).$Zone"
                IPv4Address = $record.RecordData.IPv4Address.ToString()
                RecordType = $record.RecordType
                TTL = $record.TimeToLive.ToString()
                Zone = $Zone
                ServerHost = $DNSServer
                IsReachable = $null
            }
            
            if ($TestConnectivity) {
                $item.IsReachable = Test-Connection -ComputerName $record.RecordData.IPv4Address -Count 1 -Quiet -ErrorAction SilentlyContinue
            }
            
            Write-Host "  $($record.HostName) - $($record.RecordData.IPv4Address)" -ForegroundColor Gray
            $inventory += $item
        }
        
        Write-Host "  Found $($records.Count) A records" -ForegroundColor Green
        
    } catch {
        Write-Warning "Failed to query DNS server: $_"
    }
}

# Summary
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "INVENTORY SUMMARY" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

$summary = $inventory | Group-Object Source
foreach ($group in $summary) {
    Write-Host "  $($group.Name): $($group.Count) records" -ForegroundColor Green
}

if ($TestConnectivity) {
    $reachable = ($inventory | Where-Object IsReachable -eq $true).Count
    $unreachable = ($inventory | Where-Object IsReachable -eq $false).Count
    Write-Host "  Reachable: $reachable" -ForegroundColor Green
    Write-Host "  Unreachable: $unreachable" -ForegroundColor Red
}

# Export
if ($ExportPath) {
    $inventory | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "`nInventory exported to: $ExportPath" -ForegroundColor Cyan
}

# Return results
$inventory
