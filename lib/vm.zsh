#!/usr/bin/env zsh
# lib/vm.zsh - virtual machine operations, done by utmctl

# List virtual machines as "name<TAB>status" lines
# utmctl prints "UUID Status Name" and a name can contain spaces.
# Usage: _zsh_utm_list
_zsh_utm_list() {
    local output
    output=$(_zsh_utm_ctl list) || return 1

    print -r -- "$output" | awk 'NR > 1 {
        status = $2
        match($0, /^[^ ]+ +[^ ]+ +/)
        print substr($0, RLENGTH + 1) "\t" status
    }'
}

# List virtual machine names, one per line
# Usage: _zsh_utm_names
_zsh_utm_names() {
    _zsh_utm_list 2>/dev/null | cut -f1
}

# Print the status of a virtual machine (started, stopped, paused, ...)
# Usage: _zsh_utm_status <vm>
_zsh_utm_status() {
    _zsh_utm_ctl status "$1"
}

# Wait until a virtual machine reaches one of the given statuses
# Usage: _zsh_utm_wait <vm> <timeout-seconds> <status> [status...]
_zsh_utm_wait() {
    local vm="$1"
    local timeout="$2"
    shift 2

    local deadline=$(( SECONDS + timeout ))
    local current

    while (( SECONDS < deadline )); do
        current=$(_zsh_utm_status "$vm") || return 1
        (( ${@[(Ie)$current]} )) && return 0
        sleep 1
    done

    _zsh_utm_log error "Timed out after ${timeout}s waiting for '$vm' (status: $current)"
    return 1
}

# Start a virtual machine
# Usage: _zsh_utm_start <vm> [disposable]
_zsh_utm_start() {
    local vm="$1"
    local disposable="$2"

    if [[ "$disposable" == "true" ]]; then
        _zsh_utm_ctl start "$vm" --disposable
    else
        _zsh_utm_ctl start "$vm"
    fi
}

# Stop a virtual machine
# utmctl stops by force unless told otherwise, so a request is passed explicitly.
# Usage: _zsh_utm_stop <vm> <request|force|kill|suspend>
_zsh_utm_stop() {
    local vm="$1"
    local mode="$2"

    case "$mode" in
    request) _zsh_utm_ctl stop "$vm" --request ;;
    force)   _zsh_utm_ctl stop "$vm" --force ;;
    kill)    _zsh_utm_ctl stop "$vm" --kill ;;
    suspend) _zsh_utm_ctl suspend "$vm" --save-state ;;
    *)
        _zsh_utm_log error "Unknown stop mode: $mode"
        return 1
        ;;
    esac
}
