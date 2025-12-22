#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------
# Resolve script directory
# ----------------------------------------
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
separator="/"

ResetContent="Example${separator}*"
ResetPath="${scriptDir}/${ResetContent}"

# Optional overlay path (disabled by default)
OverlayPath="" 
# OverlayPath="${scriptDir}/../Personal/Wirehole Config/*"

CaddyfilePath="${scriptDir}/Caddyfile"
PHTOMLfilePath="${scriptDir}/pihole.toml"

# ----------------------------------------
# Folders to reset
# ----------------------------------------
folders=(
    "wg_config"
    "caddy_config"
    "caddy_data"
    "db"
    "etc-pihole"
    "unbound"
    "ublogging"
    "var/www"
)

# Files to forcibly remove
files2forceImport=(
    "$CaddyfilePath"
    "$PHTOMLfilePath"
)

# ----------------------------------------
# Load .env into a Bash map-like structure
# ----------------------------------------
declare -A EnvVars

GetEnvFileDictionary() {
    local envfile="${1:-${scriptDir}/.env}"

    if [[ ! -f "$envfile" ]]; then
        echo "Environment file not found: $envfile" >&2
        exit 1
    fi

    while IFS= read -r line; do
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        # Skip blank or comment lines
        [[ -z "$line" || "$line" == \#* ]] && continue

        # Must contain '='
        [[ "$line" != *"="* ]] && continue

        key="${line%%=*}"
        value="${line#*=}"

        key="$(echo "$key" | xargs)"
        value="$(echo "$value" | xargs)"

        [[ -z "$key" ]] && continue

        # Strip surrounding single or double quotes
        if [[ ( "$value" == \"*\" && "$value" == *\" ) || ( "$value" == \'*\' && "$value" == *\' ) ]]; then
            value="${value:1:${#value}-2}"
        fi

        EnvVars["$key"]="$value"
    done < "$envfile"
}

# ----------------------------------------
# Expand @Variables inside templates
# ----------------------------------------
ExpandAtVariables() {
    local text="$1"

    for key in "${!EnvVars[@]}"; do
        value="${EnvVars[$key]}"

        # Escape sed special chars
        safe_value=$(printf '%s\n' "$value" | sed 's/[&/\]/\\&/g')

        text=$(echo "$text" | sed "s/@${key}/${safe_value}/g")
    done

    printf "%s" "$text"
}

# ----------------------------------------
# Templates
# ----------------------------------------
PiHoleTOML_Template='[webserver]
  headers = [
    "X-Frame-Options: ALLOW"
  ]
  
[dns]
# Array of custom CNAME records each one in CNAME form: "ALIAS TARGET"
cnameRecords = [
    "@PublictAddress,host-gateway",
    "@LocalNetworkHostName,host-gateway"
]'

CaddyFileTemplate='
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
   import wg_snippet
}

pihole.localhost {
   import pihole_snippet
}

wg.@PublictAddress {
   import wg_snippet
}

pihole.@PublictAddress {
   import pihole_snippet
}

wg.@LocalNetworkHostName {
   import wg_snippet
}

pihole.@LocalNetworkHostName {
   import pihole_snippet
}

localhost {
    import CaddyFileGeneral
}

@PublictAddress {
    import CaddyFileGeneral
}

@LocalNetworkHostName {
    import CaddyFileGeneral
}'

# ----------------------------------------
# Reset folders
# ----------------------------------------
for folder in "${folders[@]}"; do
    path="${scriptDir}/${folder}"

    rm -rf "$path"
    mkdir -p "$path"
done

# ----------------------------------------
# Reset files
# ----------------------------------------
for file in "${files2forceImport[@]}"; do
    rm -f "$file"
done

# ----------------------------------------
# Copy example folder
# ----------------------------------------
cp -r $ResetPath "$scriptDir"

# Optional overlay
if [[ -n "$OverlayPath" && -e $OverlayPath ]]; then
    echo "Overlay folder defined, copying over."
    cp -r $OverlayPath "$scriptDir"
fi

# ----------------------------------------
# Load environment variables
# ----------------------------------------
GetEnvFileDictionary

# ----------------------------------------
# Generate Caddyfile if missing
# ----------------------------------------
if [[ ! -f "$CaddyfilePath" ]]; then
    echo "Caddyfile does not exist, creating from built-in template..."
    ExpandAtVariables "$CaddyFileTemplate" > "$CaddyfilePath"
fi

# ----------------------------------------
# Generate Pi-hole TOML if missing
# ----------------------------------------
if [[ ! -f "$PHTOMLfilePath" ]]; then
    echo "Pi-hole TOML file does not exist, creating from built-in template..."
    ExpandAtVariables "$PiHoleTOML_Template" > "$PHTOMLfilePath"
fi