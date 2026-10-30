#!/usr/bin/env zsh
# lib/snapshot.zsh - snapshot operations, done by utmctl (QEMU virtual machines only)

# List snapshot names of a virtual machine, newest first
# utmctl prints "name<TAB>created<TAB>based on<TAB>kind".
# Usage: _zsh_utm_snapshot_list <vm>
_zsh_utm_snapshot_list() {
    local output
    output=$(_zsh_utm_ctl snapshot list "$1") || return 1

    [[ -n "$output" ]] && print -r -- "$output" | cut -f1
    return 0
}

# Save the current state of a virtual machine as a new snapshot
# Usage: _zsh_utm_snapshot_create <vm> <name>
_zsh_utm_snapshot_create() {
    _zsh_utm_ctl snapshot create "$1" --name "$2" >/dev/null
}

# Replace the state of a virtual machine with a snapshot
# Usage: _zsh_utm_snapshot_restore <vm> <name>
_zsh_utm_snapshot_restore() {
    _zsh_utm_ctl snapshot restore "$1" --snapshot "$2" >/dev/null
}

# Replace what a snapshot holds with the current state of the virtual machine
# Usage: _zsh_utm_snapshot_overwrite <vm> <name>
_zsh_utm_snapshot_overwrite() {
    _zsh_utm_ctl snapshot overwrite "$1" --snapshot "$2" >/dev/null
}

# Delete a snapshot
# Usage: _zsh_utm_snapshot_delete <vm> <name>
_zsh_utm_snapshot_delete() {
    _zsh_utm_ctl snapshot delete "$1" --snapshot "$2" >/dev/null
}

# Rename a snapshot
# Usage: _zsh_utm_snapshot_rename <vm> <name> <new-name>
_zsh_utm_snapshot_rename() {
    _zsh_utm_ctl snapshot rename "$1" --snapshot "$2" --to "$3" >/dev/null
}
