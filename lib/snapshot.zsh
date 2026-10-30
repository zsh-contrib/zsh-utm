#!/usr/bin/env zsh
# lib/snapshot.zsh - snapshot operations (QEMU virtual machines only)

# List snapshot names of a virtual machine, newest first
# Usage: _zsh_utm_snapshot_list <vm>
_zsh_utm_snapshot_list() {
    _zsh_utm_vm_run "$1" 'set names to name of every snapshot of vm
        set AppleScript'"'"'s text item delimiters to linefeed
        return names as text'
}

# Save the current state of a virtual machine as a new snapshot
# Usage: _zsh_utm_snapshot_create <vm> <name>
_zsh_utm_snapshot_create() {
    _zsh_utm_vm_run "$1" 'create snapshot vm named (item 3 of argv)
        return' "$2"
}

# Replace the state of a virtual machine with a snapshot (newest match wins)
# Usage: _zsh_utm_snapshot_restore <vm> <name>
_zsh_utm_snapshot_restore() {
    _zsh_utm_vm_run "$1" 'restore (first snapshot of vm whose name is (item 3 of argv))
        return' "$2"
}
