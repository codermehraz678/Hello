# NetworkOptimizer-AutoRestart.ps1
# Optimizes network connection and auto-restarts the computer

param(
    [int]$RestartDelay = 30,        # Seconds to wait before restart
    [switch]$Force,                 # Force restart without prompts
    [switch]$LogToFile,
    [string]$LogFile = "$env:USERPROFILE\Desktop\NetworkOptimize.log"
)

# Check Admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Run as Administrator!" -ForegroundColor Red
    exit 1
}

#region Logging
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "INFO"    { Write-Host $logEntry -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
    }
    
    if ($LogToFile) {
        Add-Content -Path $LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
}
#endregion

#region Network Diagnostics
function Test-NetworkHealth {
    Write-Log "Running network diagnostics..."
    
    $health = @{
        Latency = 0
        PacketLoss = 0
        DnsResolution = $false
        InternetAccess = $false
        Issues = @()
    }
    
    # Test latency and packet loss
    $pingResults = Test-Connection -ComputerName "8.8.8.8" -Count 4 -ErrorAction SilentlyContinue
    if ($pingResults) {
        $health.Latency = ($pingResults | Measure-Object -Property ResponseTime -Average).Average
        $health.PacketLoss = ((4 - $pingResults.Count) / 4) * 100
    } else {
        $health.PacketLoss = 100
        $health.Issues += "No ping response"
    }
    
    # Test DNS resolution
    try {
        $dnsTest = Resolve-DnsName "google.com" -ErrorAction Stop
        $health.DnsResolution = $true
    } catch {
        $health.DnsResolution = $false
        $health.Issues += "DNS resolution failed"
    }
    
    # Test internet access
    try {
        $webTest = Invoke-WebRequest -Uri "https://www.google.com" -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        $health.InternetAccess = $true
    } catch {
        $health.InternetAccess = $false
        $health.Issues += "No internet access"
    }
    
    return $health
}
#endregion

#region Network Optimization Functions
function Clear-NetworkCaches {
    Write-Log "Clearing network caches..."
    
    ipconfig /flushdns | Out-Null
    Write-Log "  ✓ DNS cache cleared" -Level "SUCCESS"
    
    netsh interface ip delete arpcache | Out-Null
    Write-Log "  ✓ ARP cache cleared" -Level "SUCCESS"
    
    nbtstat -R | Out-Null
    Write-Log "  ✓ NetBIOS cache cleared" -Level "SUCCESS"
    
    route -f | Out-Null
    Write-Log "  ✓ Routing table cleared" -Level "SUCCESS"
}

function Reset-NetworkStack {
    Write-Log "Resetting network stack..."
    
    netsh winsock reset | Out-Null
    Write-Log "  ✓ Winsock reset" -Level "SUCCESS"
    
    netsh int ip reset | Out-Null
    Write-Log "  ✓ TCP/IP stack reset" -Level "SUCCESS"
    
    netsh int ipv6 reset | Out-Null
    Write-Log "  ✓ IPv6 stack reset" -Level "SUCCESS"
}

function Restart-NetworkAdapters {
    Write-Log "Restarting network adapters..."
    
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    
    foreach ($adapter in $adapters) {
        Write-Log "  Restarting: $($adapter.Name)"
        Restart-NetAdapter -Name $adapter.Name -Confirm:$false
        Start-Sleep -Seconds 3
    }
    
    Write-Log "  ✓ All adapters restarted" -Level "SUCCESS"
}

function Set-OptimalDNS {
    Write-Log "Setting optimal DNS servers..."
    
    $dnsServers = @("1.1.1.1", "1.0.0.1")  # Cloudflare DNS (fastest)
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    
    foreach ($adapter in $adapters) {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $dnsServers
        Write-Log "  Set DNS for $($adapter.Name): $($dnsServers -join ', ')" -Level "SUCCESS"
    }
    
    ipconfig /flushdns | Out-Null
}

function Optimize-TCPSettings {
    Write-Log "Optimizing TCP/IP settings..."
    
    netsh int tcp set global autotuninglevel=normal | Out-Null
    Write-Log "  ✓ TCP auto-tuning enabled" -Level "SUCCESS"
    
    netsh int tcp set global ecncapability=enabled | Out-Null
    Write-Log "  ✓ ECN enabled" -Level "SUCCESS"
    
    netsh int tcp set supplemental template=internet congestionprovider=cubic | Out-Null
    Write-Log "  ✓ TCP congestion provider optimized" -Level "SUCCESS"
    
    netsh int tcp set global rss=enabled | Out-Null
    Write-Log "  ✓ RSS enabled" -Level "SUCCESS"
}

function Renew-IPAddress {
    Write-Log "Renewing IP address..."
    
    ipconfig /release | Out-Null
    Start-Sleep -Seconds 2
    ipconfig /renew | Out-Null
    Start-Sleep -Seconds 3
    
    Write-Log "  ✓ IP address renewed" -Level "SUCCESS"
}

function Clear-WindowsUpdateCache {
    Write-Log "Clearing Windows Update cache..."
    
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    
    Write-Log "  ✓ Windows Update cache cleared" -Level "SUCCESS"
}
#endregion

#region Main Optimization
function Invoke-NetworkOptimization {
    Write-Log "========================================" -Level "INFO"
    Write-Log "   NETWORK OPTIMIZATION STARTED" -Level "INFO"
    Write-Log "========================================" -Level "INFO"
    
    $startTime = Get-Date
    
    # Run all optimizations
    Clear-NetworkCaches
    Reset-NetworkStack
    Set-OptimalDNS
    Optimize-TCPSettings
    Renew-IPAddress
    Clear-WindowsUpdateCache
    Restart-NetworkAdapters
    
    # Wait for network to stabilize
    Write-Log "Waiting for network stabilization..."
    Start-Sleep -Seconds 10
    
    # Post-optimization check
    $health = Test-NetworkHealth
    
    # Summary
    $duration = ((Get-Date) - $startTime).TotalSeconds
    
    Write-Log "========================================" -Level "INFO"
    Write-Log "   OPTIMIZATION COMPLETE" -Level "SUCCESS"
    Write-Log "========================================" -Level "INFO"
    Write-Log "Duration: $([math]::Round($duration, 2)) seconds" -Level "INFO"
    Write-Log "Latency: $([math]::Round($health.Latency, 2))ms" -Level "INFO"
    Write-Log "Packet Loss: $($health.PacketLoss)%" -Level "INFO"
    Write-Log "Internet: $(if($health.InternetAccess){'OK'}else{'ISSUES DETECTED'})" -Level "INFO"
    Write-Log "DNS: $(if($health.DnsResolution){'OK'}else{'ISSUES DETECTED'})" -Level "INFO"
    
    return $health.InternetAccess
}
#endregion

#region Auto Restart Function
function Invoke-AutoRestart {
    param([int]$Delay = 30, [switch]$ForceRestart)
    
    Write-Log "========================================" -Level "WARNING"
    Write-Log "   SYSTEM RESTART INITIATED" -Level "WARNING"
    Write-Log "========================================" -Level "WARNING"
    
    if ($ForceRestart) {
        Write-Log "Restarting in $Delay seconds (Force mode)..." -Level "WARNING"
        
        # Create a countdown
        for ($i = $Delay; $i -gt 0; $i--) {
            Write-Host "`rRestarting in $i seconds...     " -NoNewline -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
        Write-Host ""
        
        # Force restart immediately
        shutdown /r /t 0 /f
    }
    else {
        Write-Log "Restarting in $Delay seconds..." -Level "WARNING"
        Write-Log "Press Ctrl+C to cancel" -Level "WARNING"
        
        # Create a countdown with option to cancel
        for ($i = $Delay; $i -gt 0; $i--) {
            Write-Host "`rRestarting in $i seconds... (Ctrl+C to cancel)     " -NoNewline -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
        Write-Host ""
        
        # Schedule restart
        shutdown /r /t 0 /f
    }
}
#endregion

#region Main Execution
# Run optimization
$success = Invoke-NetworkOptimization

Write-Log ""
Write-Log "Network optimization finished!" -Level "SUCCESS"

if ($success) {
    Write-Log "Network is healthy - proceeding with restart" -Level "SUCCESS"
} else {
    Write-Log "Network issues detected - restart recommended" -Level "WARNING"
}

Write-Log ""

# Auto restart
Invoke-AutoRestart -Delay $RestartDelay -ForceRestart:$Force
