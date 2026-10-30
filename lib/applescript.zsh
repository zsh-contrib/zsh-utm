#!/usr/bin/env zsh
# lib/applescript.zsh - AppleScript bridge to UTM

# Log a message through gum, falling back to stderr when gum is missing
# Usage: _zsh_utm_log <level> <message>
_zsh_utm_log() {
    local level="$1"
    shift

    if command -v gum >/dev/null 2>&1; then
        gum log --level "$level" "$*"
        return 0
    fi

    # Without gum, only show debug output when asked for
    [[ "$level" == "debug" && -z "$DEBUG" ]] && return 0
    echo "${(U)level}: $*" >&2
}

# Check that the tools the plugin needs are installed
# Usage: _zsh_utm_check_dependencies
_zsh_utm_check_dependencies() {
    if ! command -v osascript >/dev/null 2>&1; then
        _zsh_utm_log error "osascript not found (zsh-utm requires macOS)"
        return 1
    fi

    return 0
}

# Run an AppleScript, passing values as argv instead of interpolating them
# Usage: _zsh_utm_osascript <script> [arg...]
_zsh_utm_osascript() {
    local script="$1"
    shift

    _zsh_utm_check_dependencies || return 1

    # Keep stderr apart so warnings never end up in the returned value
    local errfile
    errfile=$(mktemp) || return 1

    local output error
    if ! output=$(osascript -e "$script" -- "$@" 2>"$errfile"); then
        error=$(<"$errfile")
        rm -f "$errfile"
        _zsh_utm_log error "${error:-osascript failed}"
        return 1
    fi
    rm -f "$errfile"

    [[ -n "$output" ]] && print -r -- "$output"
    return 0
}

# Run a snippet against a single virtual machine
# The snippet runs inside `tell application "UTM"` with the machine bound to
# `vm`. Extra arguments are available to it as `item 3 of argv` and up.
# Usage: _zsh_utm_vm_run <vm> <snippet> [arg...]
_zsh_utm_vm_run() {
    local vm="$1"
    local snippet="$2"
    shift 2

    # A UUID selects by id, anything else selects by name
    local kind="name"
    [[ "$vm" =~ '^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$' ]] && kind="id"

    local script="on run argv
    set kind to item 1 of argv
    set ident to item 2 of argv
    tell application \"UTM\"
        if kind is \"id\" then
            set vm to virtual machine id ident
        else
            set vm to virtual machine named ident
        end if
        ${snippet}
    end tell
end run"

    _zsh_utm_osascript "$script" "$kind" "$vm" "$@"
}
