# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $scriptDir ".env"
$ExampleFile = Join-Path $scriptDir ".env.example"

 if (Test-Path $EnvFile) {
    if ((Get-FileHash $EnvFile).Hash -ne (Get-FileHash $ExampleFile).Hash) { Read-Host "Files differ. Press Enter to continue" }
     Remove-Item $EnvFile -Force
 }
Copy-Item -Path $ExampleFile -Destination $EnvFile