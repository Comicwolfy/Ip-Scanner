# PowerShell script to scan the local network for active devices

function Get-LocalSubnet {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Dhcp" -or $_.PrefixOrigin -eq "Manual" }).IPAddress
    if ($ip -match "(\d+\.\d+\.\d+)\.\d+") {
        return "$($matches[1])."
    }
    return $null
}

function Ping-Subnet {
    param ($Subnet)
    
    Write-Host "[*] Scanning network: ${Subnet}x ..."
    
    $jobs = @()
    for ($i=1; $i -le 254; $i++) {
        $ip = "$Subnet$i"
        $jobs += Start-Job -ScriptBlock { param ($ip) Test-Connection -ComputerName $ip -Count 1 -Quiet } -ArgumentList $ip
    }

    $results = @()
    foreach ($job in $jobs) {
        $job | Wait-Job | Out-Null
        $data = Receive-Job -Job $job
        if ($data) {
            $results += $job.ChildJobs[0].Arguments[0]
        }
        Remove-Job -Job $job
    }
    
    return $results
}

function Get-MacAddresses {
    Write-Host "[*] Getting MAC addresses..."
    arp -a | ForEach-Object {
        if ($_ -match "(\d+\.\d+\.\d+\.\d+)\s+([a-fA-F0-9:-]{17})") {
            [PSCustomObject]@{
                IP  = $matches[1]
                MAC = $matches[2]
            }
        }
    }
}

# Main Execution
$Subnet = Get-LocalSubnet
if (-not $Subnet) {
    Write-Host "[!] Could not determine subnet. Exiting..."
    exit
}

$activeIPs = Ping-Subnet -Subnet $Subnet
$macTable = Get-MacAddresses

Write-Host "`nActive Devices:"
Write-Host "----------------------------"
Write-Host "IP Address`tMAC Address"
Write-Host "----------------------------"

foreach ($ip in $activeIPs) {
    $macEntry = $macTable | Where-Object { $_.IP -eq $ip }
    $mac = if ($macEntry) { $macEntry.MAC } else { "N/A" }
    Write-Host "$ip`t$mac"
}
