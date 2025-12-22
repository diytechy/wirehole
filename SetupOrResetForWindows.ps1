# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashScriptPath = $scriptDir + "\InitOrResetRoot.sh"

function Convert-WindowsPathToWSL {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Normalize slashes
    $p = $Path -replace '\\','/'

    # Trim trailing slash unless it's root-like
    if ($p -ne '/' -and $p -match '.+/$') {
        $p = $p.TrimEnd('/')
    }

    # Handle UNC paths: \\server\share\folder → /mnt/unc/server/share/folder
    if ($p -match '^//([^/]+)/([^/]+)(/.*)?$') {
        $server = $matches[1]
        $share  = $matches[2]
        $rest   = $matches[3]
        return "/mnt/unc/$server/$share$rest"
    }

    # Handle drive-letter paths: C:/Users/... → /mnt/c/Users/...
    if ($p -match '^([A-Za-z]):(/.*)?$') {
        $drive = $matches[1].ToLower()
        $rest  = $matches[2]
        return "/mnt/$drive$rest"
    }

    # Handle relative paths: foo/bar → foo/bar (WSL treats as relative)
    if ($p -notmatch '^/') {
        return $p
    }

    # Already looks like a Linux path
    return $p
}

function Set-NetworkDNS {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$IPv4,

        [string]$IPv6,

        [string]$AdapterName
    )

    # Validate IPv4
    if (-not [System.Net.IPAddress]::TryParse($IPv4, [ref]$null)) {
        throw "Invalid IPv4 address: $IPv4"
    }

    # Validate IPv6 if provided
    if ($IPv6 -and -not [System.Net.IPAddress]::TryParse($IPv6, [ref]$null)) {
        throw "Invalid IPv6 address: $IPv6"
    }

    # Determine which adapters to modify
    if ($AdapterName) {
        $adapters = Get-NetAdapter -Name $AdapterName -ErrorAction Stop
    }
    else {
        # Ethernet + Wi-Fi only
        $adapters = Get-NetAdapter |
            Where-Object { $_.Status -eq 'Up' -and $_.Name -match 'Ethernet|Wi-Fi|Wireless' }
            #Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -match 'Ethernet|Wi-Fi|Wireless' }
    }

    foreach ($adapter in $adapters) {
        Write-Verbose "Updating DNS for adapter: $($adapter.Name)"

        # IPv4 DNS
        Set-DnsClientServerAddress `
            -InterfaceIndex $adapter.ifIndex `
            -ServerAddresses $IPv4 `
            -AddressFamily IPv4 `
            -ErrorAction Stop

        # IPv6 DNS (optional)
        if ($IPv6) {
            Set-DnsClientServerAddress `
                -InterfaceIndex $adapter.ifIndex `
                -ServerAddresses $IPv6 `
                -AddressFamily IPv6 `
                -ErrorAction Stop
        }
    }

    Write-Output "DNS updated successfully."
}

$FullwslPath = Convert-WindowsPathToWSL $bashScriptPath

try {
    Write-Host "Attempting to run $FullwslPath"
    wsl sudo bash "$FullwslPath"
} catch {
    Write-Error "Failed to run bash script via WSL: $_"
}