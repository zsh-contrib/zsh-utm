#!/usr/bin/env zsh
# lib/applescript.zsh - AppleScript bridge to UTM, for what utmctl cannot do

# Run a script of lib/applescript and print what it prints on success
# Usage: _zsh_utm_applescript <script> [arg...]
_zsh_utm_applescript() {
    local script="${ZSH_UTM_PLUGIN_DIR}/lib/applescript/$1"
    shift

    if ! command -v osascript >/dev/null 2>&1; then
        _zsh_utm_log error "osascript not found (zsh-utm requires macOS)"
        return 1
    fi

    # Keep stderr apart so warnings never end up in the returned value
    local errfile
    errfile=$(mktemp) || return 1

    local output error
    if ! output=$(osascript "$script" "$@" 2>"$errfile"); then
        error=$(<"$errfile")
        rm -f "$errfile"
        _zsh_utm_log error "${error:-osascript failed}"
        return 1
    fi
    rm -f "$errfile"

    [[ -n "$output" ]] && print -r -- "$output"
    return 0
}
