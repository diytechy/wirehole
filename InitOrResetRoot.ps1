# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$separator = [System.IO.Path]::DirectorySeparatorChar
$ResetContent = "Reset"+$separator+"*"
$ResetPath = Join-Path $scriptDir $ResetContent

# List of folders to reset
$folders = @(
    "wg_config",
    "caddy_config",
    "caddy_data",
    "db",
    "etc-dnsmasq.d",
    "etc-pihole",
    "unbound"
)

foreach ($folder in $folders) {
    $path = Join-Path $scriptDir $folder

    # Remove the folder if it exists
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
    }

    # Create the folder
    New-Item -Path $path -ItemType Directory | Out-Null
}
Copy-Item -Path $ResetPath -Destination $scriptDir -Recurse -Force