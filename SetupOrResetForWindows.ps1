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

$FullwslPath = Convert-WindowsPathToWSL $bashScriptPath

try {
    Write-Host "Attempting to run $FullwslPath"
    wsl sudo bash "$FullwslPath"
} catch {
    Write-Error "Failed to run bash script via WSL: $_"
}