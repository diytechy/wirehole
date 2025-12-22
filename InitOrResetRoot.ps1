# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashScriptPath = $scriptDir + "\InitOrResetRoot.sh"

try {
    wsl bash -c "bash '$(wslpath -a -u $bashScriptPath)'"
} catch {
    Write-Error "Failed to run bash script via WSL: $_"
}