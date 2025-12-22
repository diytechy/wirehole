# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$separator = [System.IO.Path]::DirectorySeparatorChar
$ResetContent = "Example"+$separator+"*"
$ResetPath = Join-Path $scriptDir $ResetContent
$OverlayPath = $null
#$OverlayPath = Join-Path $scriptDir (".."+$separator+"Personal"+$separator+"Wirehole Config"+$separator+"*")

$CaddyfilePath = ".\Caddyfile"
$PHTOMLfilePath = ".\pihole.toml"

# List of folders to reset
$folders = @(
    "wg_config",
    "caddy_config",
    "caddy_data",
    "db",
    "etc-pihole",
    "unbound",
    "ublogging",
    ("var"+$separator+"www")
)

#List of files to forcably remove, in order to copy-over or regenerate if not available.
$files2forceImport = @(
    $CaddyfilePath,
    $PHTOMLfilePath
)


# LoadEnv funciton.
# Safely loads key=value pairs from a .env file into the current session's environment variables
function Get-EnvFileDictionary {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = ".\.env"
    )

    # Ensure the file exists
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Environment file not found at path: $Path"
    }

    $envTable = @{}

    foreach ($line in Get-Content -LiteralPath $Path) {

        # Trim whitespace
        $trimmed = $line.Trim()

        # Skip blank lines and comments
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }

        # Must contain '=' to be valid
        if ($trimmed -notmatch "=") {
            continue
        }

        # Split only on the FIRST '='
        $key, $value = $trimmed.Split("=", 2)

        # Clean key/value
        $key   = $key.Trim()
        $value = $value.Trim()

        # Skip invalid keys
        if ([string]::IsNullOrWhiteSpace($key)) {
            continue
        }

        # Strip surrounding single or double quotes
        if (
            ($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))
        ) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        # Add or overwrite
        $envTable[$key] = $value
    }

    return $envTable
}

function Expand-AtVariables {
    [CmdletBinding()]                                                                                                             
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [hashtable]$Map
    )

    # Build a regex pattern of all keys, escaped for safety
    $escapedKeys = $Map.Keys | ForEach-Object { [Regex]::Escape($_) }
    $pattern = "@(" + ($escapedKeys -join "|") + ")"

    # Perform replacement
    $result = [Regex]::Replace($Text, $pattern, {
        param($match)
        $key = $match.Groups[1].Value
        return $Map[$key]
    })

    return $result
}


$PiHoleTOML_Template = '[webserver]
  headers = [
    "X-Frame-Options: ALLOW"
  ]
  
[dns]
# Array of custom CNAME records each one in CNAME form: "ALIAS TARGET"
cnameRecords = [
    "@PublictAddress,host-gateway",
    "@LocalNetworkHostName,host-gateway"
]'

$CaddyFileTemplate = '
# Caddyfile
(auth_snippet) {
   basic_auth {
   @CaddyUserLogin @CaddyPasswordHash
   }
}

(wg_snippet) {
   import auth_snippet
   encode zstd gzip
   reverse_proxy wireguard:5000
}

(pihole_snippet) {
   import auth_snippet
   encode zstd gzip
	redir / /admin{uri}
   reverse_proxy pihole:80
}

wg.localhost {
   handle {
      import wg_snippet
   }
}

pihole.localhost {
   handle {
      import pihole_snippet
   }
}

:80 {
    # Reverse proxy to your application''s service name and port
    # reverse_proxy my-app:8000
    # Optional: Enable file serving from a specific directory if needed
    # root * /var/www/html
    # file_server
    respond "Hello world!"
}'

#Clean folders
foreach ($folder in $folders) {
    $path = Join-Path $scriptDir $folder

    # Remove the folder if it exists
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
    }

    # Create the folder
    New-Item -Path $path -ItemType Directory | Out-Null
}

#Clean applicable files
foreach ($file in $files2forceImport) {
    $path = Join-Path $scriptDir $file

    # Remove the folder if it exists
    if (Test-Path $path) {
        Remove-Item -Path $path -Force
    }
}


#Copy example path, before overlaying.
Copy-Item -Path $ResetPath -Destination $scriptDir -Recurse -Force

if (($null -ne $OverlayPath) -and (Test-Path $OverlayPath)) {
   Write-Host "Overlay folder defined, copying over."
   Copy-Item -Path $OverlayPath -Destination $scriptDir -Recurse -Force
 }

 $EnvVars = Get-EnvFileDictionary;

 if (-not(Test-Path $CaddyfilePath)) {
   Write-Host "Caddyfile does not exist, creating from build-in template..."
   Set-Content -Path $CaddyfilePath -Value (Expand-AtVariables $CaddyFileTemplate $EnvVars) -Encoding UTF8 -NoNewline
 }
 
 if (-not(Test-Path $PHTOMLfilePath)) {
   Write-Host "Pi Hole TOML file does not exist, creating from build-in template..."
   Set-Content -Path $PHTOMLfilePath -Value (Expand-AtVariables $PiHoleTOML_Template $EnvVars) -Encoding UTF8 -NoNewline
 }