#!/usr/bin/env zsh
# lib/log.zsh - logging

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
