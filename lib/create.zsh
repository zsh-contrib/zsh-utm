#!/usr/bin/env zsh
# lib/create.zsh - create a virtual machine from a TOML spec
#
# utmctl cannot create a virtual machine and the scripting interface of UTM can only set part of
# one, so a VM is created through AppleScript and the rest of its config.plist is patched with
# plutil.

# Read a value of the spec as plain text, with a default for a missing key
# The default is a yq expression, so a string default needs quotes.
# Usage: _zsh_utm_spec <spec> <path> <default>
_zsh_utm_spec() {
    yq -p toml -o yaml "${2} // ${3}" "$1"
}

# Resolve a path of the spec: ~ is the home directory and a relative path starts at the spec
# Usage: _zsh_utm_spec_path <spec> <value>
_zsh_utm_spec_path() {
    local value="${2/#\~/$HOME}"

    [[ -z "$value" ]] && return 0
    [[ "$value" == /* ]] || value="${1:A:h}/$value"
    print -r -- "${value:A}"
}

# Set a key path of a plist to a JSON value, plutil needs the dictionaries on the way to exist
# Usage: _zsh_utm_plist_set <plist> <key-path> <json>
_zsh_utm_plist_set() {
    local plist="$1"
    local key="$2"
    local value="$3"

    local -a parts=(${(s:.:)key})
    local prefix part

    for part in ${parts[1,-2]}; do
        prefix="${prefix:+$prefix.}$part"
        if ! plutil -type "$prefix" "$plist" >/dev/null 2>&1; then
            plutil -insert "$prefix" -dictionary "$plist" || return 1
        fi
    done

    plutil -replace "$key" -json "$value" "$plist"
}

# Write what the scripting interface cannot set into the config.plist of the new virtual machine
# It reads the variables of _zsh_utm_create, zsh scopes them dynamically.
# Usage: _zsh_utm_create_patch
_zsh_utm_create_patch() {
    local plist="$bundle/config.plist"

    # UTM is sandboxed and cannot read the ISO where it is, so keep a copy in the bundle, which is a
    # clone on APFS
    if [[ -n "$iso" ]]; then
        local copy="$bundle/Data/installer.iso"

        cp -c "$iso" "$copy" 2>/dev/null || cp "$iso" "$copy" || return 1
        plutil -replace Drive.0.ImageName -string installer.iso "$plist" || return 1
    fi

    if [[ -n "$display" ]]; then
        local screen="[{\"Hardware\":\"$display\",\"DynamicResolution\":true,"
        screen+='"NativeResolution":false,"UpscalingFilter":"Linear","DownscalingFilter":"Linear"}]'

        plutil -replace Display -json "$screen" "$plist" || return 1
    fi

    plutil -replace Network.0.Mode -string "$mode" "$plist" || return 1

    if [[ "$forward" != "[]" ]]; then
        plutil -replace Network.0.PortForward -json "$forward" "$plist" || return 1
    fi

    if [[ "$clipboard" != null ]]; then
        plutil -replace Sharing.ClipboardSharing -bool "$clipboard" "$plist" || return 1
    fi

    if [[ "$icon" != null ]]; then
        plutil -replace Information.Icon -string "$icon" "$plist" || return 1
    fi

    # Anything else, a key path of the plist and its value
    local key value
    for key in ${(f)"$(yq -p toml -o yaml '(.plist // {}) | keys | .[]' "$spec")"}; do
        value=$(yq -p toml -o json -I0 ".plist[\"$key\"]" "$spec") || return 1
        _zsh_utm_plist_set "$plist" "$key" "$value" || return 1
    done

    _zsh_utm_applescript apply.applescript "$name" "$share" >/dev/null
}

# Create a virtual machine from a spec
# Usage: _zsh_utm_create <spec> [force]
_zsh_utm_create() {
    local spec="$1"
    local force="$2"

    if [[ ! -f "$spec" ]]; then
        _zsh_utm_log error "Spec not found: $spec"
        return 1
    fi

    local tool
    for tool in yq plutil; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            _zsh_utm_log error "$tool not found (utm create needs it)"
            return 1
        fi
    done

    local name backend memory cpus disk iso share display clipboard icon mode forward
    if ! name=$(_zsh_utm_spec "$spec" .name '""'); then
        _zsh_utm_log error "Cannot read $spec as TOML"
        return 1
    fi

    backend=$(_zsh_utm_spec "$spec" .backend '"qemu"')
    memory=$(_zsh_utm_spec "$spec" .memory 8192)
    cpus=$(_zsh_utm_spec "$spec" .cpus 0)
    disk=$(_zsh_utm_spec "$spec" .disk 81920)
    iso=$(_zsh_utm_spec_path "$spec" "$(_zsh_utm_spec "$spec" .iso '""')")
    share=$(_zsh_utm_spec_path "$spec" "$(_zsh_utm_spec "$spec" .share '""')")
    display=$(_zsh_utm_spec "$spec" .display '"virtio-gpu-pci"')
    clipboard=$(_zsh_utm_spec "$spec" .clipboard null)
    icon=$(_zsh_utm_spec "$spec" .icon null)
    mode=$(_zsh_utm_spec "$spec" .network.mode '"shared"')

    # Each forward becomes an entry of the PortForward list of the network
    local expr='[(.network.forward // [])[] | {'
    expr+='"Protocol": ((.protocol // "tcp") | upcase), "GuestAddress": "", "GuestPort": .guest, '
    expr+='"HostAddress": (.address // "127.0.0.1"), "HostPort": .host}]'
    forward=$(yq -p toml -o json -I0 "$expr" "$spec")

    if [[ -z "$name" ]]; then
        _zsh_utm_log error "The spec needs a name"
        return 1
    fi

    if [[ "$backend" != qemu ]]; then
        _zsh_utm_log error "Unsupported backend: $backend (only qemu is supported)"
        return 1
    fi

    case "$mode" in
    shared) mode="Shared" ;;
    emulated) mode="Emulated" ;;
    *)
        _zsh_utm_log error "Unsupported network mode: $mode (use shared or emulated)"
        return 1
        ;;
    esac

    if [[ -n "$iso" && ! -f "$iso" ]]; then
        _zsh_utm_log error "ISO not found: $iso"
        return 1
    fi

    if [[ -n "$share" && ! -d "$share" ]]; then
        _zsh_utm_log error "Shared directory not found: $share"
        return 1
    fi

    if _zsh_utm_names | grep -Fxq -- "$name"; then
        if [[ "$force" != "true" ]]; then
            _zsh_utm_log error "Virtual machine already exists: $name (use --force to replace it)"
            return 1
        fi

        _zsh_utm_ctl delete "$name" >/dev/null || return 1
    fi

    _zsh_utm_applescript create.applescript \
        "$name" "$iso" "$cpus" "$memory" "$disk" "${share:+true}" >/dev/null || return 1

    local bundle="${ZSH_UTM_DOCUMENTS}/${name}.utm"
    if [[ ! -d "$bundle" ]] || ! _zsh_utm_create_patch; then
        _zsh_utm_log error "Could not finish '$name', removing it"
        _zsh_utm_ctl delete "$name" >/dev/null 2>&1
        return 1
    fi

    _zsh_utm_log info "Created '$name'"
}
