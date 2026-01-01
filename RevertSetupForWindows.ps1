function Restore-NetworkDNS {
    [CmdletBinding()]
    param(
        [string]$AdapterName
    )

    # Determine which adapters to modify
    if ($AdapterName) {
        $adapters = Get-NetAdapter -Name $AdapterName -ErrorAction Stop
    }
    else {
        # Ethernet + Wi-Fi only
        $adapters = Get-NetAdapter |
            Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -match 'Ethernet|Wi-Fi|Wireless' }
    }

    foreach ($adapter in $adapters) {
        Write-Verbose "Restoring automatic DNS for adapter: $($adapter.Name)"

        # Restore IPv4 DNS to automatic
        Set-DnsClientServerAddress `
            -InterfaceIndex $adapter.ifIndex `
            -ResetServerAddresses `
            -AddressFamily IPv4 `
            -ErrorAction Stop

        # Restore IPv6 DNS to automatic
        Set-DnsClientServerAddress `
            -InterfaceIndex $adapter.ifIndex `
            -ResetServerAddresses `
            -AddressFamily IPv6 `
            -ErrorAction Stop
    }

    Write-Output "DNS restored to automatic configuration."
}