# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashScriptPath = $scriptDir + "\InitOrResetRoot.sh"
$wslPath = wsl wslpath "C:\Users\Peter\Projects\file.txt"

try {
    wsl sudo bash "$wslPath"
} catch {
    Write-Error "Failed to run bash script via WSL: $_"
}